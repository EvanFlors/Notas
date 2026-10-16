# ADR-0001 — Backend de traces: Tempo vs Jaeger (Mesa Logistics)

> **Esta es una referencia**. Hay más de una respuesta defendible. Lo que importa es la calidad del razonamiento y la honestidad sobre consecuencias negativas.

- **Status:** Accepted
- **Date:** 2026-10-16
- **Deciders:** Platform team (3) + 1 staff eng de producto
- **Related:** otel-11, obs-13

## Context

Mesa Logistics opera 30 microservicios en Kubernetes con ~2 000 RPS pico y una proyección de **400 M spans/día** tras aplicar sampling head del 10%. El equipo de platform (3 personas) ya mantiene en producción Prometheus + Grafana y tiene Loki en piloto. Grafana es la UI canónica declarada; introducir otra UI exigiría un ADR separado. La política interna prohíbe SaaS para datos operacionales porque los traces contendrían direcciones de envío y metadata de clientes (PII). El storage disponible es MinIO on-prem (object storage) y 2 nodos dedicados (16 vCPU / 64 GB cada uno). Hasta hoy no hay backend de traces; los incidentes se investigan "mirando logs", lo que ya está rompiendo MTTR en Sev2. Hay que decidir el backend de traces para los próximos 12–18 meses.

## Decision drivers (criteria)

- **TCO a 400 M spans/día con storage self-hosted** — peso 5.
- **Operabilidad con equipo de platform de 3 personas** — peso 5.
- **Correlación nativa trace↔metric (exemplars) y trace↔log** — peso 4.
- **Compatibilidad OTLP nativa sin shims** — peso 3.
- **UX de búsqueda sin salir de Grafana** — peso 4.
- **Camino de evolución a 2–4× tráfico (hasta 1.6 B spans/día)** — peso 3.
- **Madurez upstream y cadencia de releases** — peso 2.

## Options considered

### Option A — Grafana Tempo

- Pros:
  - Index mínimo (solo trace-id) + chunks en MinIO = TCO más bajo a esta escala. Entra holgado en los 2 nodos previstos.
  - Correlación nativa con el stack ya en producción (Prometheus exemplars, Loki). La UI canónica (Grafana) ya es la UI.
  - OTLP nativo de primera clase; sin adaptadores.
  - Camino a 1.6 B spans/día = añadir más buckets MinIO + horizontal scale de ingester, sin re-arquitectura.
- Cons:
  - Búsqueda rica por atributos **sin Grafana** es muy limitada (TraceQL funciona pero no hay "UI standalone" cómoda).
  - TraceQL sobre atributos no indexados puede ser lento en ventanas grandes.
  - Depende de que Grafana esté sana para investigar incidentes.

### Option B — Jaeger

- Pros:
  - UI standalone madura: investigar un incidente **no exige** Grafana arriba.
  - Indexa atributos (servicio, operación, tags) → búsquedas interactivas más expresivas sin TraceQL.
  - Comunidad muy amplia, patrones conocidos en la industria.
- Cons:
  - Backend típico Cassandra o Elasticsearch: operar cualquiera de los dos con 3 personas es un **segundo trabajo**.
  - TCO a 400 M spans/día bastante más alto por los índices (más RAM, más disco, más replicas de ES).
  - Redundante con Grafana ya existente: dos UIs = dos sistemas que entrenar y mantener.

## Decision

**Elegimos Grafana Tempo** como backend de traces de Mesa Logistics para los próximos 12–18 meses.

La decisión descansa en los dos pesos más altos: **TCO** y **operabilidad con equipo de 3**. A 400 M spans/día, Tempo + MinIO entra en el hardware ya aprobado; Jaeger + Elasticsearch exigiría operar un cluster adicional de ES, para el que no hay capacidad humana ni presupuestaria. Además, la UI canónica declarada es Grafana — introducir Jaeger duplicaría UIs, lo que violaría la política interna de "una UI, varias señales".

## Consequences

### Positive

- Infraestructura de traces en producción con las 2 personas-mes que tenemos presupuestadas, sin añadir ES/Cassandra al parque.
- Correlación exemplar métricas→traces y Loki→traces desde el día 1 (todos los datasources ya existen en Grafana).
- Camino de evolución horizontal claro (más réplicas de ingester, más buckets MinIO) sin rediseño.

### Negative

- Si Grafana cae en Sev1 **perdemos capacidad de investigar traces**. Mitigación: Grafana debe entrar en el circuito de HA (ADR separado).
- La búsqueda rica por atributos requiere TraceQL + aprender su mental model. Riesgo de que durante los primeros 2 meses el equipo diga "Jaeger era más intuitivo".
- Si en 12 meses necesitamos integrar un tercero (consultora, auditor) que no vive en Grafana, no tendrán UI standalone — habrá que darles acceso Grafana limitado o exportar.

### Neutral

- OTLP en la app no cambia: cualquier futura migración (incluso a Jaeger o a Honeycomb) se resuelve por YAML del Collector.
- Mantener el `otelcol` como router aporta flexibilidad futura por el mismo costo.

## Review trigger

Reevaluamos este ADR **si cualquiera** de estas condiciones se cumple:

- Spans/día sostenidos > **1 500 M** durante 30 días (Tempo + MinIO empieza a doler).
- Equipo de platform crece a > **6 personas** (podemos operar ES/Cassandra).
- Grafana sufre > **2 incidentes Sev1** en el trimestre (la dependencia de UI única rompe nuestro MTTR).
- Cambia la política de SaaS: si se abre el acceso a vendor cloud, el ADR queda **superseded** por otro que compare Tempo vs vendor.

## References

- `../theory/lesson.md` secciones 3, 4, 7, 10.
- Tempo docs: https://grafana.com/docs/tempo/latest/
- Jaeger docs: https://www.jaegertracing.io/docs/
- `otel-11-01-switch-backend-no-code-change` (demuestra que una futura migración es barata).
