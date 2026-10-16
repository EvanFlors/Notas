# obs-13 — Loki y logs en el stack

## Identificación

- **ID:** `obs-13-loki-and-logs-in-the-stack`
- **Nivel:** avanzado
- **Duración estimada:** 4 h
- **Prerrequisitos:** `obs-08-grafana-deep`

## Objetivo

Sumar **logs** al stack de observabilidad con **Grafana Loki** sin reinventar: entender su modelo (índice de labels + chunks), escribir **LogQL** con confianza, elegir un **agente** moderno (Alloy, Vector, Fluent Bit, OpenTelemetry Collector), diseñar **log-based metrics** cuando no se puede instrumentar directo, y **correlacionar** logs y métricas en Grafana evitando los antipatrones de cardinalidad y costo.

## Temas y subtemas

1. **Modelo de datos de Loki**
   - Índice de **labels** (como Prometheus) + **chunks** de contenido comprimido.
   - "Prometheus para logs": mismas reglas de cardinalidad.
2. **LogQL**
   - Stream selector `{app="x"}`, filtros `|= "ERROR"`, `|~ "regex"`.
   - Parsers: `| json`, `| logfmt`, `| regexp`.
   - `line_format` y `label_format` para derivar campos.
   - Metric queries: `rate()`, `count_over_time()`, `sum by()`.
3. **Agentes de recolección**
   - **Grafana Alloy** (sucesor unificado de Promtail + Grafana Agent).
   - **Vector** (Rust, muy rápido, pipelines ricos).
   - **Fluent Bit** (ligero, nativo en Kubernetes).
   - **OpenTelemetry Collector** (estándar neutral, un solo colector para logs/metrics/traces).
   - **Promtail**: deprecado, migrar a Alloy.
4. **Parsing**
   - Regex, logfmt, json; derivar labels a partir del contenido.
5. **Labels bajos vs campos derivados**
   - Qué va al índice (bajo cardinalidad) y qué queda en el contenido.
6. **Log-based metrics**
   - Convertir conteos/tasas de logs a series temporales cuando el servicio no se puede instrumentar.
   - `recording rules` de Loki como pre-cálculo.
7. **Correlación logs ↔ métricas**
   - Click-through en Grafana, data link de un panel de métricas a Explore de Loki.
   - Convención de labels compartidos (`app`, `instance`, `env`).
8. **Retención y storage**
   - Object storage (S3, GCS, MinIO local), schemas, compactor.
9. **Antipatrones y costos**
   - Alta cardinalidad en labels (igual que en Prometheus).
   - Logs ingested por GB/día como factor de factura.

## Conceptos internos (fundamentos)

- Loki es **barato** porque **no indexa el contenido**: solo indexa labels. Por eso solo filtra eficientemente por labels.
- LogQL hace **scanning** sobre los chunks seleccionados: si tu filtro label no es selectivo, el scan es lento y caro.
- `log-based metric` es un último recurso: siempre que puedas instrumentar la aplicación directamente (`counter_total`), el costo de la métrica es constante; derivarla de logs cuesta ingesta + scan.
- Una label de alta cardinalidad en Loki es **igual de tóxica** que en Prometheus: no la pongas en `labels`, déjala en el contenido del log.

## Competencias

- **Conceptual:** explicar por qué Loki es más barato que un Elasticsearch; distinguir label vs campo derivado; justificar cuándo instrumentar vs cuándo derivar de logs.
- **Operativa:** desplegar Loki + un agente (Alloy) + Grafana en docker-compose; escribir LogQL para los tres casos típicos (filtrado, parsing, metric query); correlacionar un panel de métricas con un Explore de Loki.
- **Arquitectónica:** elegir agente según contexto (K8s puro, VMs mixtas, pipeline OTel unificado); diseñar la retención y el costo mensual estimado; definir la política de labels del stack.

## Ejemplos

- [`examples/01-loki-plus-alloy-local/`](examples/01-loki-plus-alloy-local/) — docker-compose con Loki + Alloy + Grafana + app que loguea JSON.
- [`examples/02-logql-for-capstone/`](examples/02-logql-for-capstone/) — colección de queries LogQL que resuelven los casos típicos del capstone.
- [`examples/03-correlate-metrics-and-logs/`](examples/03-correlate-metrics-and-logs/) — data link desde un panel de Prometheus a Explore de Loki.

## Actividades

- [`activities/01-add-loki-to-stack/`](activities/01-add-loki-to-stack/) — **guided-lab**: añadir Loki + Alloy al stack del capstone y ver los logs de la app en Grafana Explore.
- [`activities/02-log-based-metric-for-error-rate/`](activities/02-log-based-metric-for-error-rate/) — **independent**: crear un dashboard con una log-based metric `sum(rate({app="api"} |= "ERROR" [5m]))` para medir error rate cuando la app no está instrumentada.

## Entregables

- Loki en el stack del capstone con un agente (Alloy) enviando logs de la app.
- Dashboard de Grafana con un panel de **error rate basado en logs** y un data link de un panel de métricas a Explore de Loki.
- Nota breve justificando qué labels se promovieron al índice y por qué.

## Criterios de evaluación

- **Conceptual:** explicar cuándo usar una log-based metric vs instrumentar la aplicación directamente.
- **Operativa:** levantar el stack con `docker compose up`, ver logs en Explore filtrados por `{app="api"}`, y ver un panel de métricas derivadas de los logs.
- **Arquitectónica:** justificar la elección de agente (Alloy vs OTel Collector vs Vector) para una organización dada y proyectar el costo mensual de ingesta.

## Recursos

- [`resources/links.md`](resources/links.md)
