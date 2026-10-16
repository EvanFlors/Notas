# ADR — Contrato de telemetría de la plataforma (Nimbora Finance)

## 1. Estado

accepted

## 2. Fecha

2026-10-16

## 3. Autores

- Observability Guild Lead, Platform
- SRE Principal, Infrastructure
- Engineering Director (sponsor)

## 4. Contexto

Nimbora Finance opera ~60 microservicios en Python/Go/Node sobre dos clusters K8s (EU-WEST, EU-NORTH) con picos de 2k RPS. Hoy conviven cuatro soluciones de observabilidad: Datadog (adoptado por producto hace 2 años, factura 4x el presupuesto inicial), Prometheus self-hosted (SRE), Jaeger (deployment huérfano), y Splunk (compliance de logs de auditoría). Los dashboards están fragmentados en tres UIs distintas, nadie correlaciona traces con métricas, y recientemente una métrica con `user_id` como label hizo colapsar un ingester de Prometheus durante 40 minutos. La dirección pide "un plan para no depender de Datadog" sin romper lo que ya funciona.

Durante dos semanas, el equipo de Platform ha hecho discovery: inventario de dashboards (138, de los cuales 42 vendor-exclusivos en Datadog), inventario de alertas (~200, 60% en Datadog), y inventario de atributos propietarios en código (`dd.service` encontrado en 18 servicios). La situación no es "listo para migrar"; es "listo para empezar a reducir lock-in".

Este ADR define el **contrato de telemetría de la plataforma**: la norma vinculante que gobernará toda la emisión y transporte de observabilidad en Nimbora de aquí en adelante.

## 5. Riesgos del status quo

- **Lock-in Datadog**: 18 servicios tienen atributos `dd.*` en código. Migración futura = refactor de meses.
- **Fragmentación**: tres UIs, cero correlación cross-signal. Un incidente requiere 3 tabs y copy-paste de IDs.
- **Cardinalidad descontrolada**: no hay freno en el camino SDK → Datadog. Un cambio inocente ("añadir user_id a esta métrica para debugging") puede multiplicar la factura al mes siguiente.
- **Costo opaco**: nadie puede atribuir el 4x crecimiento de factura a un servicio específico porque no hay rate-limiting por `service.name`.
- **Compliance en riesgo**: los logs de auditoría viven sólo en Splunk; si Splunk cae, se pierde evidencia regulatoria.

## 6. Decisión

**Decisión:** adoptar el patrón "equipos emiten OTLP, plataforma decide backend" con el OTel Collector como única frontera entre app y backends, pin de SemConv a `v1.27.0`, y prohibición explícita de atributos vendor-prefixed en código.

### 6.1 MUST (obligaciones de los equipos)

- Emitir vía OTLP (gRPC 4317 / HTTP 4318) al agent Collector local del namespace.
- Poblar Resource con `service.name`, `service.namespace`, `service.version`, `deployment.environment`.
- Propagar `traceparent` + `tracestate` en todo call saliente (HTTP, gRPC, Kafka).
- Adjuntar el logging bridge OTel para que logs lleven `trace_id`/`span_id`.
- Usar la View preset de histogramas publicada por el paquete `nimbora-otel-config`.

### 6.2 MUST NOT (prohibiciones)

Prohibidos en código de aplicación los atributos con prefijo:

- `dd.*`
- `datadog.*`
- `newrelic.*`
- `nr.*`
- `splunk.*`
- `sfx.*`
- `honeycomb.*`

Prohibido también: hardcodear bucket boundaries, exportar directo a backend desde el SDK, usar `user.id`/`request.id`/`order.id` como labels de métrica, exceder 50 combinaciones de labels por métrica.

### 6.3 SLOs de la plataforma

| SLI | Target |
| --- | --- |
| OTLP gateway availability (mensual) | 99.9% |
| p99 ingest-to-queryable (traces) | < 60s |
| p99 ingest-to-queryable (metrics) | < 30s |
| p99 ingest-to-queryable (logs) | < 90s |
| Drop rate end-to-end | < 0.1% |
| Exemplar coverage (histogramas) | > 80% |

### 6.4 Proceso de deprecación de SemConv

El pin de SemConv se revisa trimestralmente. Cuando upstream deprecia una key, el Collector hace **dual-emit** durante 8 semanas (ambos nombres copian el mismo valor vía OTTL `transform`). Se anuncia la fecha de **cutover** en `#observability-announce` desde la semana 0. En la fecha de cutover, el Collector deja de rellenar la key vieja; los dashboards no migrados romperán — es intencional. Las deprecaciones vivas se listan en `platform/semconv/DEPRECATIONS.md`.

## 7. Alternativas consideradas

- **Quedarse con Datadog como stack único y renegociar precio.** Pros: cero migración, 1 UI, posible descuento 20-30%. Contras: lock-in se profundiza (más código `dd.*`), palanca comercial se pierde, no se resuelve la cardinalidad.
- **Migración "big bang" a self-hosted (Tempo+Prometheus+Loki) en 3 meses.** Pros: lock-in cero. Contras: alto riesgo operativo, equipos de producto no están entrenados en TraceQL/LogQL, factura mensual de infra sube bruscamente, los 138 dashboards hay que reescribirlos todos a la vez.
- **Multi-cloud híbrido permanente (Datadog para apps críticas, self-hosted para resto).** Pros: compromiso. Contras: dobla operaciones, no reduce factura significativamente, mantiene fragmentación.

## 8. Consecuencias

- A partir de la aprobación del ADR, todo PR con atributos prohibidos se bloquea en CI (linter OTel).
- La factura Datadog deja de crecer en 2 trimestres y empieza a reducirse en el tercero conforme servicios migran dashboards.
- El equipo de Platform asume ownership del Collector gateway como servicio tier-1 (SLO 99.9%).
- Dashboards vendor-exclusivos de Datadog se catalogan y portan a Grafana en orden de criticidad.
- Lock-in reducido pero no cero: la UI de Datadog seguirá usándose en modo "exploración"; la fuente de verdad son los dashboards versionados.
- Costo operativo del self-hosted (~2 FTE adicionales de SRE a tiempo parcial para operar Tempo/Loki/Prometheus) es menor que el ahorro proyectado de Datadog.

## 9. Plan de migración

1. **Semanas 1-2**: desplegar Collector gateway en ambos clusters (agent+gateway, con TLS y queue persistente). Habilitar multi-export (Datadog + Tempo/Loki/Prometheus en paralelo). Cero cambios en apps.
2. **Semanas 3-6**: linter de CI que bloquea nuevos atributos `dd.*`. Migración incremental de los 18 servicios con `dd.*` existente a semconv neutra (PRs por equipo).
3. **Semanas 7-14**: portar dashboards tier-1 (payments, ledger, auth) a Grafana. Alertas correspondientes.
4. **Semanas 15-20**: deprecar export a Datadog para servicios tier-2 y tier-3. Mantener Datadog sólo como backend de "exploración" opcional.
5. **Trimestre 2**: renegociar contrato Datadog en base al uso real reducido, o apagar completo si el ahorro justifica el riesgo.
6. **Trimestre 3**: drill mensual de "cambio de vendor" (swap Collector config a un backend alternativo durante 1h en staging) para validar que la neutralidad sigue viva.
