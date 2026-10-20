# Ejemplo 01 — Remote write a VictoriaMetrics (single)

## Concepto que demuestra

Cómo configurar un **Prometheus** para que haga `remote_write` a un **VictoriaMetrics single-node** y verificar que las muestras llegan al LTS consultando su propia API PromQL-compatible.

Es la opción **más ligera** de las tres (VM, Mimir, Thanos) y la ideal para ejecutar localmente con `docker compose`.

## Contexto

Prometheus guarda local 15 d por default. Queremos que las mismas muestras se persistan en VictoriaMetrics indefinidamente (o con la retention que se le configure), para dashboards históricos y queries de rango largo. Prometheus sigue scrapeando; VM es sólo el "almacén remoto".

## Arquitectura

```
┌──────────────┐  scrape /metrics  ┌──────────────┐
│ node_exporter│◄──────────────────│  Prometheus  │
└──────────────┘                   │  (2h retent) │
                                   └──────┬───────┘
                                          │ remote_write (snappy+protobuf)
                                          ▼
                                   ┌──────────────┐
                                   │ VictoriaMetrics
                                   │   single      │
                                   │ :8428         │
                                   └──────────────┘
```

## Objetivo

Al terminar:
- Levantas Prometheus + VictoriaMetrics + node_exporter con `docker compose`.
- Entiendes la pieza mínima de `remote_write` en `prometheus.yml`.
- Verificas con `curl` que VM devuelve una serie scrapeada por Prometheus.

## Prerrequisitos

- Docker ≥ 20 y Docker Compose plugin.
- Puertos libres: 9090 (Prometheus), 8428 (VM), 9100 (node_exporter).

## Archivos

- `files/docker-compose.yml` — tres servicios en una red default.
- `files/prometheus.yml` — scrape de sí mismo + node_exporter + `remote_write` a VM.

## Ejecución

```bash
cd files
docker compose up -d
docker compose ps
```

Espera ~15 s (dos scrape intervals) y verifica:

```bash
# Prometheus está escribiendo
curl -s http://localhost:9090/api/v1/query?query=up | head -c 200

# VM recibió esas mismas series
curl -s 'http://localhost:8428/api/v1/query?query=up' | head -c 200
```

En Grafana (si lo tuvieras arriba), añadirías un data source Prometheus apuntando a `http://victoriametrics:8428` — VM responde `/api/v1/query*` igual que Prometheus.

## Cómo verificar que `remote_write` está sano

```bash
# Cola de envío a VM (debe estar baja y no crecer)
curl -s 'http://localhost:9090/api/v1/query?query=prometheus_remote_storage_samples_pending' \
  | head -c 300

# Muestras enviadas (debe crecer)
curl -s 'http://localhost:9090/api/v1/query?query=prometheus_remote_storage_samples_total' \
  | head -c 300

# Muestras descartadas (debe quedarse en 0 en régimen normal)
curl -s 'http://localhost:9090/api/v1/query?query=prometheus_remote_storage_samples_dropped_total' \
  | head -c 300
```

## Resultado esperado

- Los tres contenedores en estado `running`.
- Query `up` responde tanto en Prometheus (`:9090`) como en VictoriaMetrics (`:8428`).
- `prometheus_remote_storage_samples_dropped_total` ≈ 0.

## Interpretación

- `remote_write.url` apunta a `/api/v1/write` de VM (endpoint estándar).
- `write_relabel_configs` filtra métricas internas que no aportan valor histórico (`go_*`, `process_*`). Reduce coste.
- `queue_config` controla backpressure: si VM cae, Prometheus encola hasta el techo; después descarta. Alertar sobre `samples_dropped_total > 0`.
- VM es **drop-in compatible con PromQL**: Grafana lo usa como un Prometheus más.

## Errores frecuentes

- **"VM no responde `up`"**: el scrape no llegó aún (espera 15 s más) o el servicio Prometheus no resuelve `victoriametrics` por nombre (verifica `docker compose ps` y que estén en la misma red).
- **"Puerto 8428 ocupado"**: cambia el mapping en `docker-compose.yml` (ej. `18428:8428`).
- **"Veo doble retention"**: correcto — Prometheus retiene 2 h locales, VM retiene lo que le configures (default sin flag = ilimitado hasta llenar disco).

## Limpieza

```bash
docker compose down -v
```
