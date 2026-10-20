# otel-01 — Qué es OTel, señales y madurez

## Identificación

- **ID:** `otel-01-what-and-why-signals-and-maturity`
- **Curso:** `opentelemetry`
- **Nivel:** fundamentos
- **Duración estimada:** 2 h
- **Prerrequisitos:** curso **prometheus-grafana** ≥ Nivel 2 (`obs-02` o superior). Haber instrumentado o al menos leído métricas Prometheus. No se requiere instalar nada en este módulo.

## Objetivo

Interiorizar **qué es OpenTelemetry (OTel)**, **qué problema resuelve** y en **qué estado de madurez** se encuentra por lenguaje y por *signal*. Al terminar deberías poder explicar OTel sin confundirla con "un nuevo Prometheus" ni con "un backend"; y poder decidir, en 3 escenarios distintos (greenfield, migración, multi-backend), si adoptar OTel y con qué alcance.

## Alcance

Este módulo cubre:

- La **historia** de OTel: fusión de **OpenTracing** + **OpenCensus** en 2019 bajo la CNCF, y por qué era inevitable que ambos proyectos se unieran.
- Los **tres signals** actuales — **traces**, **metrics**, **logs** — y el signal en **incubación** (**profiling**).
- Qué significa **"vendor-neutral"** en la práctica (y qué **no** significa).
- El **status page** oficial: cómo leerlo por lenguaje y por signal, por qué logs es el signal más joven y qué consecuencias tiene esto a la hora de adoptar.
- La **relación entre OTel y los backends existentes**: Prometheus, Jaeger, Zipkin, Loki, vendors (Datadog, Honeycomb, New Relic). OTel no los reemplaza — los **unifica como receivers/exporters**.
- La idea clave: OTel es la **capa de generación + transporte + semántica**, no el storage.

Lo que **no** cubre (se verá después):

- Especificación formal, Resource y semconv, W3C Trace Context → `otel-02`.
- API vs SDK vs instrumentation libraries → `otel-03`.
- Instrumentar código Python → `otel-04` en adelante.
- Collector configurable → `otel-08`.

Este módulo es **100 % conceptual**. No se levanta infraestructura. Las dos actividades son análisis escritos; el único "tooling" es `bash` + un editor Markdown.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`** — ejemplos demostrativos (lectura y análisis, no ejecución):
  - `01-signals-diagram/` — diagrama ASCII anotado de los 3 signals + profiling + flujo app → SDK → Collector → backends.
  - `02-status-page-walkthrough/` — recorrido guiado por el status page oficial: cómo leer "Stable / Beta / Alpha / Experimental / Not implemented" por lenguaje × signal.
- **`activities/`** — dos actividades **independientes** (sin dependencia entre sí):
  - `01-landscape-mapping/` — mapear el panorama OTel vs Jaeger / Prometheus / Loki / vendor propietario, decidiendo quién sustituye a quién y quién **convive**.
  - `02-when-not-otel/` — para 4 escenarios dados, decidir si adoptar OTel ya, parcialmente o no, y defender la decisión.
- **`resources/links.md`** — referencias oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Definir OTel en una frase sin recurrir al slogan "los tres pilares". Enumerar los signals y su estado de madurez. Explicar por qué OTel **no es un backend**. |
| Operativa (sin infra) | Dado un stack ("tenemos Prometheus + Jaeger + Fluentbit → Datadog"), identificar qué piezas podrían ser **reemplazadas**, cuáles **reutilizadas** y cuáles quedan **fuera** del alcance de OTel. |
| Arquitectónica | Justificar OTel para 3 escenarios distintos (greenfield, migración desde vendor propietario, multi-backend). Decidir cuándo **no** encaja todavía (p. ej. un lenguaje con SDK alpha, un signal que todavía está en incubación). |

## Criterios de evaluación

- Explica, con palabras propias, por qué fue necesaria la fusión OpenTracing + OpenCensus.
- Nombra los 3 signals + el signal en incubación y sabe decir qué hace cada uno.
- Dado un stack conocido (p. ej. Prometheus + Jaeger), identifica qué queda fuera del scope de OTel.
- Distingue "backend" de "SDK/API" de "wire protocol (OTLP)" de "Collector".
- Entrega las dos actividades con sus validadores estructurales en verde.

## Entregables

- Notas con el **panorama OTel ↔ backends** (sale de la actividad `01-landscape-mapping`).
- Análisis razonado "cuándo OTel sí / no / parcial" (sale de la actividad `02-when-not-otel`).

## Siguiente módulo

→ `otel-02-specification-semconv-and-context-propagation` — las bases formales: Resource, Semantic Conventions, W3C Trace Context.
