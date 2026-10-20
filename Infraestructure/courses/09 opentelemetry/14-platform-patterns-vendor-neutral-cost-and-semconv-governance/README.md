# otel-14 — Platform patterns: vendor-neutral, cost y semconv governance

## Identificación

- **ID:** `otel-14-platform-patterns-vendor-neutral-cost-and-semconv-governance`
- **Nivel:** producción
- **Duración estimada:** 4 h
- **Prerrequisitos:**
  - `otel-11-backends-tempo-jaeger-loki-prometheus-multi`
  - `otel-12-otel-operator-in-k8s`
  - `otel-13-reliability-security-of-the-pipeline`

## Objetivo

Gobernar la observabilidad **vendor-neutral** a escala de plataforma: diseñar el contrato "los equipos emiten OTLP, la plataforma decide el backend", controlar costo en el Collector antes de que llegue al vendor, mantener correlación cross-signal garantizada por semconv, y manejar la governance de convenciones (incluidas deprecations) sin romper dashboards ni alertas.

## Temas y subtemas

1. **Vendor-neutral strategy**
   - Contrato de plataforma: SDK emite OTLP; backend es decisión del equipo de observabilidad.
   - Atributos "propietarios" prohibidos en el código de aplicación (ej. `datadog.*`, `newrelic.*`).
   - Collector como único punto donde se decide "qué signal va a qué backend".
2. **Cost control at the Collector**
   - Tail-based sampling por servicio (quotas por `service.name`).
   - Drop de métricas de alta cardinalidad (atributos `user.id`, `request.id`) antes de llegar al backend.
   - Aggregation processors (`metricstransform`, `cumulativetodelta`, pre-aggregation con intervals más largos para series ruidosas).
   - Compresión (`gzip`/`zstd`) y batching correctos.
3. **Cross-signal correlation garantizada**
   - Exemplars métrica ↔ trace (temporalidad delta + traceId en el histograma).
   - `traceId` y `spanId` en logs vía logging bridge.
   - Resource compartido (`service.name`, `service.namespace`, `deployment.environment`) coherente en los 3 signals.
4. **Semconv governance**
   - Seguir upstream (versión major de SemConv por trimestre).
   - Extensión interna documentada bajo namespace propio (`company.*`), nunca sobrescribir keys de upstream.
   - Deprecations: dual-emit transitorio (emitir viejo + nuevo durante N semanas) + cutover.
5. **IDP integration (Backstage/golden paths)**
   - Cada servicio nuevo scaffolded trae `Instrumentation` CR y annotations listas.
   - `techdocs` incluye matriz de signals por defecto del template.
6. **SLOs de la plataforma de observabilidad**
   - Ingest latency (percentil p99 OTLP → backend).
   - Collector availability (SLI por pipeline).
   - Dashboard "meta-observabilidad".
7. **ADR vendor neutrality**
   - Caso: cambiar de (Tempo/Loki/Prometheus self-hosted) a (Datadog) con cero cambios de código.
   - Trade-offs comerciales vs lock-in técnico.

## Conceptos internos (fundamentos)

- La neutralidad vendor **no es accidente**: es un diseño que requiere disciplina de atributos, de emisión (sólo OTLP) y de topología (el Collector es la frontera).
- Un atributo propietario filtrado en código (`dd.service`) es una **grieta** que convierte la migración futura en refactor.
- El Collector es el único lugar donde el costo se puede recortar sin pedirle nada a los equipos de producto.
- La correlación cross-signal nace del **Resource compartido**, no del backend: si tus 3 signals llevan el mismo `service.name` y el mismo `trace_id`, cualquier backend las unirá.

## Competencias

- **Conceptual:** explicar la diferencia entre "usar OTLP" y "ser vendor-neutral"; identificar grietas de lock-in en una app.
- **Operativa:** configurar un Collector que: hace tail sampling por servicio, dropea atributos de alta cardinalidad, dual-emite semconv deprecadas y enruta por pipeline.
- **Arquitectónica:** redactar un ADR de contrato de telemetría; diseñar un golden path IDP que entrega observabilidad "gratis"; defender la neutralidad bajo presión comercial.

## Ejemplos

- [`examples/01-vendor-neutral-contract/`](examples/01-vendor-neutral-contract/) — contrato escrito (markdown) + Collector mínimo que lo implementa.
- [`examples/02-cost-control-at-collector/`](examples/02-cost-control-at-collector/) — Collector config con drop de alta cardinalidad, tail sampling con quotas por servicio y métricas pre-agregadas.
- [`examples/03-semconv-deprecation-handling/`](examples/03-semconv-deprecation-handling/) — OTTL transform que dual-emite `http.method` + `http.request.method` con fecha de cutover.

## Actividades

- [`activities/01-platform-telemetry-contract-adr/`](activities/01-platform-telemetry-contract-adr/) — **ADR independiente**: redactar el contrato de telemetría de la plataforma. Validador estructural.
- [`activities/02-switch-vendor-exercise/`](activities/02-switch-vendor-exercise/) — **independent**: tomar la configuración (Tempo+Loki+Prometheus) del capstone y cambiar a Datadog modificando sólo YAML del Collector; demostrar que no hay cambios en `src/`. Validador estructural + diff.

## Entregables

1. ADR firmado de contrato de telemetría de plataforma (`activities/01`).
2. Dos configuraciones del Collector (self-hosted y vendor) con un `git diff` que **sólo** toca `collector/`.
3. Catálogo interno de SemConv extendidas con reglas de deprecación (template).

## Criterios de evaluación

| Dimensión | Qué se evalúa |
| --- | --- |
| Diseño | El contrato prohíbe explícitamente atributos propietarios en código. |
| Costo | El Collector tiene al menos 3 mecanismos de control (sampling, drop cardinalidad, aggregation). |
| Correlación | Resource compartido, exemplars configurados, logs con `trace_id`. |
| Governance | Proceso de deprecación documentado con dual-emit y cutover. |
| Reproducibilidad | `bash tests/validate.sh` corre dos veces seguidas con el mismo resultado. |
| Defensa | El estudiante justifica la decisión bajo presión comercial (sección "Preguntas de reflexión"). |

## Recursos

Ver [`resources/links.md`](resources/links.md).
