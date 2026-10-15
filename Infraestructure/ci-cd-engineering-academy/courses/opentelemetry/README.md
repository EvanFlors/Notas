# Curso: OpenTelemetry

Roadmap especializado #11. **Capa de instrumentación** vendor-neutral y especificación unificada para los tres pilares (traces, metrics, logs). Complemento directo del curso **Prometheus + Grafana**: aquí se cubre *cómo* los datos llegan a esos backends y *cómo* mantener portabilidad entre backends (Prometheus, Tempo, Loki, Jaeger, Datadog, Honeycomb, Grafana Cloud, etc.).

## 1. Introducción

### Qué es

**OpenTelemetry (OTel)** es un proyecto de la CNCF que estandariza:

1. **API** — cómo las aplicaciones producen señales de telemetría (traces, metrics, logs) en un lenguaje dado, sin acoplarse a un backend específico.
2. **SDK** — implementación de referencia por lenguaje: procesa las señales (sampling, batching, enriching, context propagation) y las exporta.
3. **OTLP** — protocolo wire (`gRPC`/`HTTP`) para transportar señales entre SDK, Collector y backend.
4. **Collector** — componente intermedio (daemon) que recibe telemetría, la transforma y la exporta a uno o varios backends.
5. **Semantic Conventions (semconv)** — nombres y atributos estándar (p. ej. `http.request.method`, `service.name`, `k8s.pod.name`) para que la telemetría de distintos sistemas se agregue coherentemente.

**Idea clave**: *instrumentas una vez con OTel; cambias de backend sin tocar el código*.

### Historia (síntesis)

- **2019** — Fusión de **OpenTracing** (tracing API) y **OpenCensus** (metrics + tracing de Google) → **OpenTelemetry**.
- **2021** — Tracing API/SDK GA en varios lenguajes.
- **2022** — Metrics API/SDK GA.
- **2023** — Logs API/SDK GA (último en madurar).
- **2024+** — Profiling signal en incubación, Semconv HTTP v1.0, mejoras en auto-instrumentation (eBPF, zero-code), OTLP ingest nativo en Prometheus.

**Estado por lenguaje** (varía): .NET, Java, Python, Node.js, Go son los más maduros. Rust y C++ aún estabilizan. Siempre verificar el status page.

### Problemas que resuelve

- **Vendor lock-in** de observabilidad: antes había que elegir "Datadog SDK" o "New Relic SDK" o la combinación propia; cambiar implicaba re-instrumentar.
- **Falta de estandarización** cross-lenguaje: cada ecosistema tenía su propia librería de tracing.
- **Fragmentación de pilares**: tracing, metrics y logs eran mundos separados (OpenTracing + Prometheus client + ad-hoc logging). OTel los unifica bajo un mismo modelo de **context** y **resource**.
- **Correlación weak** entre señales (exemplars metric↔trace, traceId en logs) — OTel es diseñada para que la correlación sea nativa.

### Casos de uso

- Instrumentar servicios en cualquier lenguaje y exportar a Prometheus (métricas), Tempo/Jaeger (traces), Loki/OpenSearch (logs).
- **Collector** como *router de telemetría* para agrupar, filtrar, reducir cardinalidad, redirigir por tenant.
- Migración entre backends (self-hosted ↔ SaaS) sin cambios de código.
- **Auto-instrumentation** (zero-code / eBPF) para visibilidad inicial antes de instrumentar manualmente.
- Standarización corporativa de atributos (semconv) para dashboards y alertas uniformes.

### Arquitectura general

```
┌──────────────────────────────────────────────┐
│ Application (API + SDK OTel por lenguaje)    │
│  - traces (spans), metrics (meters),         │
│    logs (log records); context propagation   │
└──────────────────────────────────────────────┘
             │ OTLP (gRPC / HTTP)
             ▼
┌──────────────────────────────────────────────┐
│ OTel Collector                               │
│   Receivers → Processors → Exporters         │
│   (OTLP, Prometheus, Jaeger, Zipkin, …)      │
│   batching, memory_limiter, sampling, attr   │
└──────────────────────────────────────────────┘
             │
   ┌─────────┼─────────────┐
   ▼         ▼             ▼
┌──────┐  ┌───────┐   ┌─────────┐
│ Prom │  │ Tempo │   │  Loki   │   (o Jaeger, OpenSearch,
│ /    │  │       │   │         │    Datadog, Honeycomb, …)
│ Mimir│  │       │   │         │
└──────┘  └───────┘   └─────────┘
```

El **Collector** es, en la práctica, la pieza más usada: incluso cuando no se instrumenta con OTel, puede recibir Prometheus scrapes y traces Jaeger/Zipkin y traducirlos a OTLP.

### Alternativas

- **Instrumentación nativa por backend** (Datadog APM, New Relic, Dynatrace) — mejor UX inicial, lock-in alto.
- **Zipkin / Jaeger** (tracing only) — maduros pero pre-OTel; integran como receivers del Collector.
- **Pixie** / **Hubble** / **Parca** — observabilidad eBPF, complementaria.
- **OpenCensus** / **OpenTracing** — proyectos predecesores, **deprecados** oficialmente por OTel.

### Ventajas / limitaciones

**Ventajas**: estándar CNCF con adopción masiva (vendors comerciales lo soportan); vendor-neutral real; unifica los tres pilares; Collector enormemente flexible.

**Limitaciones / riesgos**:
- **Madurez desigual por lenguaje y por signal** (logs son los más nuevos; algunos SDKs tienen rough edges).
- **Semconv ha cambiado** entre versiones (p. ej. `http.method` → `http.request.method`); migraciones requieren disciplina.
- **Métricas con delta vs cumulative** temporality: Prometheus exige cumulative, OTel default es `cumulative` para evitar sorpresas pero algunos backends (StatsD-style) prefieren delta.
- **Tail-based sampling** requiere stateful collectors y acumula memoria.
- **Overhead** no trivial si se instrumenta sin criterio (todo span, todo attribute).

### Relación con el programa

- Capa de instrumentación por default del **capstone**.
- Integra con **Prometheus + Grafana** (métricas), **Tempo** (traces), **Loki** (logs).
- Puente con **AWS CloudWatch** (ADOT) y **Google Cloud Operations** (OTel exporter → Cloud Trace/Monitoring/Logging).
- Posibilita **exemplars**: una métrica agregada enlaza al trace que la produjo (click-through en Grafana).

## 2. Prerrequisitos

| Tipo | Contenido |
|------|-----------|
| Obligatorios | Curso **prometheus-grafana** ≥ Nivel 2. Un lenguaje para instrumentar (Python aquí). Curso **docker**. |
| Recomendados | Curso **kubernetes** ≥ Nivel 2 (Collector como DaemonSet/Deployment, Operator en Nivel 3). |
| Complementarios | Un backend conocido (Prometheus/Grafana del curso previo; Datadog o similar si aplica en la organización). |

## 3. Organización (4 niveles)

El curso tiene **14 módulos**. Detalle en `ROADMAP.md`.

- **Nivel 1 — Fundamentos** (3): qué es OTel y por qué existe (unificación), especificación + semconv + context propagation, API vs SDK vs instrumentation.
- **Nivel 2 — Intermedio** (5): instrumentación Python (auto + manual, spans), metrics API, logs API y bridges con logging estándar, context propagation en profundidad, arquitectura del Collector (receivers/processors/exporters).
- **Nivel 3 — Avanzado** (4): patrones de despliegue del Collector (agent vs gateway), sampling (head vs tail, probabilistic, parent-based), backends y multi-exportación (Tempo, Jaeger, Loki, Prometheus), OTel Operator en K8s (Instrumentation CR, Collector CR, target allocator).
- **Nivel 4 — Producción empresarial** (2): fiabilidad y seguridad del pipeline (TLS, auth, backpressure, memory limits), platform patterns (vendor-neutral strategy, cost control, correlación cross-signal, gobernanza de semconv).

## 4. Entregables del curso

- App Python/FastAPI del capstone con auto-instrumentation + spans manuales clave + atributos semconv.
- Collector local (compose) y en K8s (DaemonSet "agent" + Deployment "gateway") configurado.
- Traces del capstone en **Tempo**, métricas en **Prometheus** (via OTLP ingest), logs en **Loki** — todo correlacionado en Grafana con exemplars y traceId en logs.
- Sampling tail-based con reglas (p. ej. sample 100% errores + 10% éxitos).
- ADR vendor-neutral: cómo el pipeline permite cambiar backend sin tocar código.

## 5. Evaluación

- **Conceptual**: explicar los tres pilares bajo OTel, context propagation con W3C traceparent, por qué `cumulative` vs `delta` temporality importa, qué resuelve tail-based que head-based no.
- **Operativa**: instrumentar un servicio con auto + manual; configurar Collector multi-exporter; implementar sampling tail-based; migrar un atributo deprecado del semconv antiguo al nuevo.
- **Arquitectónica**: diseñar el pipeline (agent vs gateway, dónde cae el sampling, qué backend por señal); evaluar el costo del tracing a escala; definir el contrato de telemetría de la plataforma.

## 6. Recursos

A verificar en Fase 4:

- Documentación oficial `opentelemetry.io/docs/`.
- Especificación OTel (`github.com/open-telemetry/opentelemetry-specification`).
- **Semantic Conventions** (`github.com/open-telemetry/semantic-conventions`).
- OTel Collector contrib (receivers/processors/exporters comunitarios).
- OTel Operator (`github.com/open-telemetry/opentelemetry-operator`).
- ADOT (**AWS Distro for OpenTelemetry**) y recomendación GCP equivalente.
- Grafana Tempo docs.
- OpenTelemetry status page (madurez por lenguaje y signal).
