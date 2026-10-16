# Ejemplo 02 — Thanos sidecar + querier (walkthrough)

> **Walkthrough-only.** No se ejecuta aquí. Thanos requiere object storage (S3/MinIO/GCS) y 5+ componentes;
> para un ambiente ejecutable prefiere el oficial `thanos-io/thanos` *kube-thanos* o `bitnami/charts/thanos`.
> Esta sección existe para que entiendas la pieza como lectura y referencia.

## Concepto que demuestra

Cómo Thanos extiende un (o varios) Prometheus **sin reemplazarlo**: un *sidecar* convive con cada Prometheus, sube los bloques TSDB a object storage, y un *querier* presenta una vista PromQL federada sobre múltiples sidecars + store gateways.

## Arquitectura mental

```
┌───────────────────────────────┐    ┌───────────────────────────────┐
│ Prometheus A (replica=a)      │    │ Prometheus B (replica=b)      │
│   external_labels: {          │    │   external_labels: {          │
│     cluster: "prod", repl: a} │    │     cluster: "prod", repl: b} │
└──────────────┬────────────────┘    └──────────────┬────────────────┘
               │ shares /data vol                   │
      ┌────────▼────────┐                  ┌────────▼────────┐
      │ thanos sidecar  │                  │ thanos sidecar  │
      │ -store.grpc     │                  │ -store.grpc     │
      │ -shipper        │────── upload ───►│ (same bucket)   │
      └────────┬────────┘                  └────────┬────────┘
               │                                    │
               │     ┌─────────────────────────┐    │
               └────►│   Object Store (S3)     │◄───┘
                     │   closed 2h blocks      │
                     └─────────────┬───────────┘
                                   │
                     ┌─────────────▼───────────┐
                     │   Thanos Store Gateway  │  (lee blocks del bucket)
                     └─────────────┬───────────┘
                                   │ gRPC StoreAPI
                                   │
┌──────────────┐  gRPC StoreAPI    │
│ Thanos       │◄──────────────────┤  (también a los dos sidecars)
│ Querier      │ dedup by replica  │
│ (PromQL HTTP)│                   │
└──────┬───────┘                   │
       │                           │
       ▼
┌──────────────┐                   ┌──────────────────────┐
│   Grafana    │                   │  Thanos Compactor    │
└──────────────┘                   │  (dedup + downsample)│
                                   └──────────────────────┘
```

## Pieza por pieza — para qué sirve

### `thanos sidecar`

- Se despliega **al lado** de cada Prometheus (mismo pod en K8s, mismo volumen `/data`).
- Flags clave: `--prometheus.url`, `--tsdb.path`, `--objstore.config-file`, `--grpc-address`.
- Dos funciones:
  1. **Shipping**: cuando Prometheus cierra un bloque de 2 h, el sidecar lo sube a `s3://bucket/<ulid>/`.
  2. **StoreAPI gRPC**: expone la head (datos aún no en bloque) para que el querier pueda leerla live.
- Requiere `--storage.tsdb.min-block-duration = max-block-duration = 2h` en Prometheus (desactiva compaction local; el compactor remoto se encarga).

### Object store

- S3, GCS, Azure Blob, OpenStack Swift, MinIO (self-hosted). Config vía YAML:

```yaml
type: S3
config:
  bucket: thanos
  endpoint: s3.amazonaws.com
  region: us-east-1
  access_key: ...
  secret_key: ...
```

### `thanos store` (Store Gateway)

- Expone StoreAPI gRPC pero leyendo del bucket.
- Mantiene **index cache** (in-memory o Memcached/Redis) para no leer el index de cada bloque en cada query.
- Un replica típico por región/bucket.

### `thanos query` (Querier)

- Endpoint HTTP compatible con PromQL (`/api/v1/query*`).
- Flag `--store` por cada endpoint StoreAPI (sidecars + store gateways + rulers que exponen StoreAPI).
- `--query.replica-label=replica` activa **deduplicación**: si tus Prometheus HA tienen `external_labels.replica=a|b`, el querier presenta UNA sola serie.
- Puedes stackear: Querier-of-queriers para federar regiones.

### `thanos compact`

- **Singleton por bucket** (dos corriendo = corrupción). Hace:
  - Compaction progresiva (2h → 8h → 2d → 14d).
  - **Downsampling** 5m y 1h (produce bloques adicionales de resolución reducida).
  - Aplica retention (`--retention.resolution-raw`, `--retention.resolution-5m`, `--retention.resolution-1h`).
- Operacionalmente delicado: si falla, los bloques quedan sin compactar; detectarlo con `thanos_compact_halted`.

### `thanos rule` (Ruler)

- Evalúa recording & alerting rules sobre el **querier** (visión global).
- Expone también StoreAPI con sus resultados (que el querier re-expone).

### `thanos receive` (alternativa al sidecar)

- Acepta `remote_write` como endpoint, actúa de ingester y escribe a object storage.
- Útil cuando el push es más conveniente (p. ej. Prometheus en nubes aisladas que no puedes exponer).
- Trade-off: añade estado y hashring que operar.

## Ejemplo de flags (referencia, no ejecutar aquí)

Sidecar:
```
thanos sidecar \
  --tsdb.path=/prometheus \
  --prometheus.url=http://localhost:9090 \
  --objstore.config-file=/etc/thanos/objstore.yml \
  --grpc-address=0.0.0.0:10901 \
  --http-address=0.0.0.0:10902
```

Querier:
```
thanos query \
  --http-address=0.0.0.0:10904 \
  --query.replica-label=replica \
  --store=sidecar-a:10901 \
  --store=sidecar-b:10901 \
  --store=store-gateway:10901
```

## Cuándo elegir Thanos vs alternativas

- Ya tienes muchos Prometheus que no quieres reemplazar.
- Prefieres **object storage** como almacén (barato, duradero).
- Tu equipo está cómodo operando 5-6 componentes y un bucket.
- No necesitas multi-tenancy fuerte (si la necesitas → Mimir).

## Lecturas

- Documentación oficial Thanos. Ver `../../resources/links.md`.
