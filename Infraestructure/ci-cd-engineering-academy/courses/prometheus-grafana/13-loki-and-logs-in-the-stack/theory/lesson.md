# Lección — Loki y logs en el stack

> Nivel avanzado. Duración lectura ≈ 60 min. Asume `obs-08` (Grafana en profundidad) y familiaridad con Prometheus/PromQL.

## 1. Por qué logs después de métricas

Las métricas te dicen **qué pasa** (p99 subió a 1.2 s, errores a 5 %); los logs te dicen **por qué pasa** (stack trace, usuario, request-id). Un stack de observabilidad sin logs te deja viendo el humo sin saber dónde está el fuego. Pero logs **mal diseñados** son el camino más rápido a una factura de observabilidad descontrolada: Elasticsearch tradicional indexa cada palabra, lo que da búsqueda full-text pero cuesta mucho RAM y disco.

**Loki** nace en 2018 con otra tesis: *"index like Prometheus, store like S3"*. Solo indexa un puñado de **labels** por línea; el contenido queda en **chunks** comprimidos en object storage. Resultado: ingesta y storage baratos; el precio es que solo filtra rápido por lo que está en el índice.

## 2. Modelo de datos de Loki

Cada línea de log en Loki es `(labels, timestamp, line)`:

```
{app="api", env="prod", instance="api-7f6"} 2026-10-13T12:00:00Z {"level":"error","msg":"db timeout","request_id":"abc"}
```

- **Labels** → van al índice; filtro barato (`{app="api"}`).
- **Línea** → contenido crudo; filtrar por `|= "ERROR"` requiere **scan** sobre los chunks seleccionados por los labels.

El símil con Prometheus es exacto:

| Prometheus | Loki |
|---|---|
| Métricas con labels | Streams de logs con labels |
| TSDB local → remote object store | Index local → object store (S3/GCS/MinIO) |
| Cardinalidad explosiva por label malo | Igual, pero peor (chunks más grandes) |
| PromQL | LogQL |

**Regla práctica**: labels de Loki = labels de Prometheus. Nunca `request_id`, `user_id` o `trace_id` como label.

## 3. LogQL

LogQL tiene dos modos: **log queries** (devuelven líneas) y **metric queries** (devuelven series de tiempo).

### 3.1 Log queries

```logql
{app="api", env="prod"}                               # stream selector
{app="api"} |= "ERROR"                                # filtro substring
{app="api"} |~ "timeout|unavailable"                  # regex
{app="api"} != "healthcheck"                          # exclusión
{app="api"} | json                                    # parse json → labels derivados
{app="api"} | json | level="error"                    # filtro sobre label derivado
{app="api"} | logfmt | duration > 1s                  # parse logfmt + comparación numérica
{app="api"} | json | line_format "{{.msg}} [{{.request_id}}]"  # reformatear la línea
```

### 3.2 Metric queries

```logql
sum(rate({app="api"} |= "ERROR" [5m]))                        # tasa de errores por segundo
sum by (status) (count_over_time({app="api"} | json [1m]))    # conteo agrupado
quantile_over_time(0.95, {app="api"} | json | unwrap duration [5m])
```

Lo clave: `rate()` sobre un filtro de logs **produce una serie temporal** que Grafana dibuja como cualquier panel de Prometheus.

## 4. Agentes de recolección

El agente lee logs del sistema (archivos, Docker, journald, stdout de pods) y los envía a Loki via HTTP (`/loki/api/v1/push`). Las opciones vivas en 2026:

| Agente | Autor | Fortaleza | Debilidad | Cuándo elegirlo |
|---|---|---|---|---|
| **Grafana Alloy** | Grafana Labs | Sucesor unificado de Promtail + Grafana Agent + OTel distribution; una sola binario para logs/metrics/traces | Más grande que Fluent Bit | Default moderno para stacks "LGTM" |
| **Promtail** | Grafana Labs | Simple, especializado Loki | **Deprecado** (2025), migración a Alloy anunciada | Legacy; migrar |
| **Vector** | Datadog (OSS) | Pipelines ricos (VRL), performance en Rust | Curva de aprendizaje de VRL | Cuando necesitas transformar/enrutar a múltiples destinos |
| **Fluent Bit** | CNCF | Muy ligero (C), nativo en K8s DaemonSet | Config menos ergonómica | Edge/K8s con restricciones de recursos |
| **OpenTelemetry Collector** | CNCF | Estándar neutral, un colector para logs/metrics/traces | Config densa, menos features Loki-específicas | Pipeline OTel unificado, multi-backend |

**Promtail está deprecado** desde 2025: `grafana/alloy` es el camino oficial. Para instalaciones nuevas, elige **Alloy** (si tu stack es Grafana Labs) o **OpenTelemetry Collector** (si quieres neutralidad de vendor).

## 5. Parsing

Los logs rara vez vienen con labels útiles ya separados. El parsing en LogQL ocurre en **query time** (puedes decidir después qué extraer):

```logql
# JSON estructurado
{app="api"} | json
# → crea labels derivados: level, msg, request_id, duration, ...

# Logfmt (key=value)
{app="api"} | logfmt
# → crea labels: level, msg, duration, ...

# Regex con captura
{app="api"} | regexp "^(?P<level>\\w+) (?P<msg>.*)$"
```

El parsing **no es gratis**: cada query parsea de nuevo. Para datos recurrentes conviene **recording rules** (ver §8).

## 6. Labels bajos vs campos derivados

El error más común al adoptar Loki: convertir cada campo del log en un label.

**Regla**: un label debe tener **baja cardinalidad** y ser **estable** en el tiempo.

| Candidato | Al índice (label)? | Por qué |
|---|---|---|
| `app`, `service` | Sí | Pocos valores, estables |
| `env` (prod/stg/dev) | Sí | 3-5 valores |
| `instance` / `pod` | Sí | Decenas; relabel si crece |
| `level` (info/warn/error) | Sí (si se filtra mucho) | 4-5 valores |
| `path` HTTP | **No** si es libre; sí si está acotado | `path="/api/v1/orders"` ok; `path="/users/123/orders/456"` NO |
| `user_id`, `request_id`, `trace_id` | **Nunca** | Cardinalidad infinita |
| `status` (200/500) | Opcional | Pocos valores |

Los que **no** van al índice se extraen en query con `| json` o `| logfmt` cuando hagan falta.

## 7. Log-based metrics

Cuando el servicio **no se puede instrumentar** (binario cerrado, legacy, dependencia de terceros), se derivan métricas de los logs:

```logql
sum(rate({app="legacy-batch"} |= "FAILED" [5m]))
```

Esto da una serie que puedes graficar y **alertar** sobre ella desde Grafana (Grafana alerting lee Loki como data source) o desde Loki rules (`loki/rules/*.yml` evaluado por el ruler).

**Trade-offs vs instrumentar directo**:

| Instrumentar (Prometheus) | Log-based metric (Loki) |
|---|---|
| Costo constante por serie | Costo = ingesta + scan cada query |
| Semántica controlada por el código | Depende de que el log no cambie |
| Imposible si no controlas el código | Siempre posible |
| Alerta inmediata (query O(1)) | Alerta más lenta y cara |

**Úsalo cuando no haya alternativa**. Si vas a derivar la misma métrica muchas veces, define una **recording rule** de Loki para pre-calcularla.

## 8. Recording rules de Loki

```yaml
# loki-rules.yaml
groups:
  - name: api-errors
    interval: 1m
    rules:
      - record: api:log_error_rate:sum
        expr: sum(rate({app="api"} |= "ERROR" [5m]))
```

El ruler de Loki evalúa y **escribe** el resultado a un store Prometheus-compatible via `remote_write`. Resultado: tu dashboard consulta `api:log_error_rate:sum` como una métrica normal, sin escanear logs cada carga.

## 9. Correlación logs ↔ métricas

Grafana permite **data links** entre data sources. Flujo típico:

1. Panel de latencia p99 (Prometheus) alerta por una subida.
2. Click en el panel → data link lleva a Explore de Loki con filtros pre-poblados:
   ```
   {app="api", instance="$instance"} |= "ERROR"
   ```
3. El operador ve los logs correlacionados en segundos.

Para que funcione, la **convención de labels** debe ser consistente entre Prometheus y Loki: si el pod se llama `api-7f6` en Prometheus, debe serlo en Loki (mismo `instance`). Esto se consigue con los **mismos labels de scrape/relabel** en ambos agentes.

Grafana también ofrece **derived fields** en el data source de Loki: una línea de log con `request_id=abc` puede exponer un link a un trace en Tempo (correlación logs → traces).

## 10. Retención y storage

Loki escribe en dos componentes:

- **Index** (TSDB-shipper o boltdb-shipper o nuevo TSDB index) — pequeño, local + sync a objeto.
- **Chunks** — grandes, directamente en object storage (S3/GCS/Azure Blob/MinIO).

Retención se define por **schema** y por **compactor**:

```yaml
limits_config:
  retention_period: 744h          # 31 días por tenant
schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb
      object_store: s3
      schema: v13
      index:
        prefix: index_
        period: 24h
compactor:
  retention_enabled: true
  delete_request_store: s3
```

Para labs locales se usa **filesystem** o **MinIO** (API S3 local).

## 11. Antipatrones y costos

**Antipatrones**:

1. **Label de alta cardinalidad** (`request_id`, `user_id`, `path` libre): mismo pecado que en Prometheus, aquí también explota el índice y hace los chunks ineficientes.
2. **Loguear "todo"**: sin niveles ni filtros, se ingiere ruido que nunca se consulta. Loki cobra por **GB ingested**: cada MB inútil es dinero.
3. **Un stream por pod sin `__meta_` relabel**: si en K8s cada réplica efímera genera un stream nuevo, el índice crece sin control. Usar labels **estables** (`app`, `env`), no efímeros.
4. **Query sin stream selector específico**: `{env="prod"} |= "foo"` escanea TODO prod. Siempre acotar por `app` primero.
5. **Promtail nuevo en 2026**: deprecado. Usar Alloy.

**Costos** (modelo mental):

```
Costo mensual ≈ (GB_ingest/día × 30 × precio_ingest) + (GB_stored × precio_storage) + egress
```

Grafana Cloud factura por GB ingested; self-hosted paga storage + compute del cluster. Reducir ingesta = filtrar en el agente (drop healthchecks, debug en prod, blobs binarios).

## 12. Checklist operativa

Antes de dar por "listo" un stack con Loki:

- [ ] Agente moderno (Alloy u OTel Collector), **no Promtail nuevo**.
- [ ] Labels del índice revisados: ninguno con cardinalidad `> 1000`.
- [ ] Convención de labels **igual** en Prometheus y Loki (`app`, `env`, `instance`).
- [ ] Al menos **un data link** de métrica a Explore de Loki configurado.
- [ ] Retención definida por policy, no por default (`744h` ≠ "para siempre").
- [ ] Object storage con lifecycle policy (archivar a Glacier/Nearline tras N días).
- [ ] Alerta de **ingesta anómala** (si duplica el baseline, es un bug de logging).
- [ ] Logs de `healthcheck` droppeados en el agente.
- [ ] Para métricas de alta demanda, **recording rule** de Loki o instrumentación directa.
- [ ] Documentada una **política de labels** y revisada en PR como se revisan los de Prometheus.
