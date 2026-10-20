# otel-02 — Specification, Semconv and Context Propagation

## Identificación

- **ID:** `otel-02-specification-semconv-and-context-propagation`
- **Curso:** `opentelemetry`
- **Nivel:** fundamentos
- **Duración estimada:** 3 h
- **Prerrequisitos:** `otel-01-what-and-why-signals-and-maturity`.

## Objetivo

Entender las **tres piezas base** sobre las que descansa todo lo demás en OTel:

1. La **especificación** (API, SDK, data model, protocol) y cómo encaja la noción de **Resource**.
2. Las **Semantic Conventions** (nombres estandarizados de atributos) y cómo manejar su **evolución** (migración `http.method` → `http.request.method`).
3. El **context propagation** vía W3C Trace Context (`traceparent`) y **Baggage**, incluyendo cómo se configuran los `propagators`.

Al terminar deberías poder leer un `traceparent`, aplicar Resource y semconv correctos, y decidir con criterio qué va en Baggage y qué **no**.

## Alcance

- Estructura de la spec: **API** (interfaz), **SDK** (implementación), **data model** (traces/metrics/logs), **protocol** (OTLP).
- **Resource**: atributos del productor (`service.*`, `deployment.environment`, `host.*`, `k8s.*`); por qué se adjuntan una sola vez por proceso.
- **Semantic Conventions**: dominios vigentes (http, db, messaging, rpc, k8s, faas, cloud…) y versioning; estrategias de migración (dual-emit).
- **W3C Trace Context**: formato de `traceparent` (`00-<trace-id>-<span-id>-<flags>`) y `tracestate`.
- **Baggage**: cuándo sí (correlación cross-service de un valor estable) y cuándo **no** (alta cardinalidad, PII, atributos de alto cambio).
- **Propagators**: `TextMapPropagator`, defaults (`tracecontext` + `baggage`), composición.

Lo que **no** cubre (va después):
- Instrumentar Python real (`otel-04`).
- Context propagation en profundidad con casos cross-service, Kafka, executors (`otel-07`).
- Collector y sus processors que manipulan atributos (`otel-08`).

## Materiales

- **`theory/lesson.md`** — lección con 12 secciones.
- **`examples/`**:
  - `01-traceparent-walkthrough/` — decodificar un `traceparent` con `python3` stdlib.
  - `02-resource-and-semconv/` — construir un bloque Resource + attributes HTTP semconv v1 válidos.
  - `03-baggage-example/` — encode/decode del header `baggage` y por qué pesa en cada hop.
- **`activities/`**:
  - `01-identify-breaking-semconv-change/` — **independent** (debug): tres "SDKs" emiten atributos HTTP mezclando viejo y nuevo semconv; identificar breaking changes y proponer plan de migración.
  - `02-attribute-review/` — **independent**: revisar un listado de atributos propuestos para un servicio y clasificar cuáles son Resource, cuáles son semconv estándar, cuáles son custom aceptables y cuáles rechazar (PII / cardinalidad).
- **`resources/links.md`** — spec, semconv, W3C Trace Context, Baggage.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la separación API / SDK / data model / protocol. Describir qué es un Resource y por qué no se repite por span. Leer un `traceparent` byte a byte. Argumentar cuándo Baggage es correcto. |
| Operativa | Decodificar un `traceparent` manualmente. Elegir el atributo correcto según semconv vigente (y detectar los deprecados). Configurar propagators compuestos. |
| Arquitectónica | Diseñar un plan de **dual-emit** para migrar entre versiones de semconv sin romper dashboards. Definir el contrato "qué va en Resource, qué va en span attributes, qué va en Baggage" para la plataforma. |

## Criterios de evaluación

- Decodificar un `traceparent` dado y explicar cada campo.
- Identificar atributos deprecados y proponer migración.
- Diagnosticar un trace "roto" porque faltan propagators (ejercicio de evaluación).
- Entregable: **cheatsheet propio de semconv** + ejemplo de `traceparent` descompuesto.

## Secuencia recomendada

1. Lee `theory/lesson.md`.
2. Reproduce `examples/01-traceparent-walkthrough/` (decoder stdlib).
3. Reproduce `examples/02-resource-and-semconv/`.
4. Reproduce `examples/03-baggage-example/`.
5. Haz `activities/01-identify-breaking-semconv-change/` (independent).
6. Haz `activities/02-attribute-review/` (independent).

## Siguiente

→ `otel-03-api-sdk-and-instrumentation-strategies`.
