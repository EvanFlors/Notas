# Ejemplo 03 — Grafana Mimir con Helm (walkthrough)

> **Walkthrough-only.** No se ejecuta aquí. Mimir en modo microservicios requiere K8s + MinIO/S3 + Memcached;
> este documento es una lectura guiada del chart y los componentes para preparar el ADR del módulo.
> Para una prueba local real se recomienda el modo **monolithic** del chart `grafana/mimir-distributed` o `mimir -target=all`.

## Concepto que demuestra

Cómo se despliega Grafana Mimir como stack completo con **Helm**, qué microservicios lo componen y cómo Prometheus (o `vmagent`, o Grafana Alloy) le envía métricas vía `remote_write`.

## Chart canónico

```
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm show values grafana/mimir-distributed > values.yaml
```

El chart `grafana/mimir-distributed` incluye:

- Mimir en modo microservicios (ingester, distributor, querier, query-frontend, store-gateway, compactor, ruler, alertmanager).
- MinIO embebido (sólo recomendado para dev).
- Memcached para `chunks-cache`, `index-cache`, `metadata-cache`, `results-cache`.

## Arquitectura mental

```
   Prometheus / vmagent / Alloy
            │  remote_write (POST /api/v1/push)
            │  X-Scope-OrgID: tenant-1
            ▼
   ┌─────────────────────┐
   │    Distributor      │  valida, aplica límites, hashea
   └─────┬───────────────┘
         │ gRPC
         ▼
   ┌─────────────────────┐
   │  Ingester (N copias)│  RAM head (12h); replica factor 3
   │  (StatefulSet)      │
   └─────┬───────────────┘
         │ flush bloques
         ▼
   ┌─────────────────────┐          ┌─────────────────────┐
   │  Object Store (S3)  │◄────────►│   Store Gateway     │
   └─────────┬───────────┘          └─────────┬───────────┘
             │                                │
             │          ┌─────────────────────┘
             │          │
             ▼          ▼
   ┌─────────────────────┐
   │     Compactor       │  compaction + retention
   └─────────────────────┘

   ┌─────────────────────┐    ┌─────────────────────┐
   │  Query Frontend     │◄───│       Querier       │◄── Grafana
   │ (parte y paraleliza)│    │ (StoreAPI gRPC)     │
   └─────────────────────┘    └─────────────────────┘

   ┌─────────────────────┐
   │  Alertmanager +     │
   │  Ruler (per-tenant) │
   └─────────────────────┘
```

## Flujo de datos típico

1. Un agente (`vmagent`, Prometheus, Alloy) envía muestras a `distributor:8080/api/v1/push` con header `X-Scope-OrgID: team-foo`.
2. Distributor valida (limits, series máximas por tenant) y hashea cada serie al ingester correspondiente del hashring.
3. Ingester mantiene la head en RAM (12 h típico), con **replication factor 3** por default — tolera caída de 1 réplica sin perder.
4. Cada 2 h, ingester "ships" un bloque TSDB a S3 (como Thanos sidecar).
5. Store Gateway lee del bucket para queries históricas; Querier combina resultados de ingesters (recientes) + store gateway (viejos).
6. Query Frontend parte queries largas en subqueries, las paraleliza y cachea resultados en Memcached.
7. Compactor hace compaction + retention periódicos.

## Lo que define a Mimir vs Thanos

- **Push only** (no sidecar). Simplifica si parte-is de `remote_write`.
- **Multi-tenancy nativa** (`X-Scope-OrgID`): límites, alertas y storage separados por tenant.
- **Query Frontend** potente (splitting, cache de resultados, retries).
- **Replication factor** en ingesters: resuelve HA sin requerir dos Prometheus "idénticos".
- Chart Helm "listo para producción" si tu equipo opera K8s.

## Valores de Helm que suelen tocarse

```yaml
mimir:
  structuredConfig:
    limits:
      max_global_series_per_user: 1500000
      ingestion_rate: 250000
      max_query_lookback: 90d
      compactor_blocks_retention_period: 1y

ingester:
  replicas: 3
  persistentVolume:
    size: 100Gi

store_gateway:
  replicas: 3

compactor:
  replicas: 1   # per-tenant es seguro paralelizar; globalmente single-flight

minio:
  enabled: false   # usa S3 real en prod

memcached:
  chunks-cache:
    enabled: true
    allocatedMemory: 8192
  index-cache:
    enabled: true
    allocatedMemory: 4096
```

## Config de agente para apuntar a Mimir

En Prometheus:

```yaml
remote_write:
  - url: http://mimir-nginx/api/v1/push
    headers:
      X-Scope-OrgID: team-foo
```

En `vmagent`:

```
-remoteWrite.url=http://mimir-nginx/api/v1/push
-remoteWrite.headers=X-Scope-OrgID:team-foo
```

En Grafana (datasource Prometheus):

```yaml
url: http://mimir-nginx/prometheus
httpHeaderName1: X-Scope-OrgID
httpHeaderValue1: team-foo
```

## Cuándo elegir Mimir

- Necesitas multi-tenancy (SaaS, varias BUs, cost allocation por tenant).
- Volumen > 100 M series y creces.
- Tu equipo ya opera K8s con Helm y tiene SRE para microservicios.
- Posible camino de salida: migración a Grafana Cloud sin reescribir dashboards/alerts.

## Lecturas

- `grafana/mimir-distributed` chart y docs oficiales en `../../resources/links.md`.
