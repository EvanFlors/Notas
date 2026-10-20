# Ejemplo 01 — Diagrama de signals: traces, metrics, logs (+ profiling)

> Lectura y análisis. Sin ejecución. Objetivo: fijar en memoria **qué signal responde a qué pregunta** y por dónde fluye cada uno de la app al backend.

## 1. Las 4 preguntas, los 4 signals

```
┌─────────────────────────────────────────────────────────────────────┐
│  Pregunta operativa                 │  Signal natural               │
├─────────────────────────────────────┼───────────────────────────────┤
│ ¿Cuántos 5xx en la última hora?     │  METRICS   (agregación)       │
│ ¿Qué dashboard muestra la p95?      │  METRICS                      │
│                                     │                               │
│ ¿Por qué ESTE request tardó 2 s?    │  TRACES    (un request)       │
│ ¿Qué servicio es el cuello?         │  TRACES                       │
│                                     │                               │
│ ¿Qué pasó exactamente a las 03:14?  │  LOGS      (evento discreto)  │
│ ¿Qué dijo el servicio al fallar?    │  LOGS                         │
│                                     │                               │
│ ¿Dónde se me va el 40% del CPU?     │  PROFILING (incubación)       │
│ ¿Qué stack causa el leak de heap?   │  PROFILING                    │
└─────────────────────────────────────────────────────────────────────┘
```

Cada signal es **especialista**. Intentar responder a "¿por qué tardó 2 s este request?" **solo con métricas** es el equivalente a buscar unas llaves bajo la farola porque "ahí hay luz": no vas a encontrar nada.

## 2. Flujo end-to-end (ASCII)

```
            ┌───────────────────────────────────────────────┐
            │              Application (Python)             │
            │                                               │
            │   ┌──── traces ────┐                          │
            │   │ spans (checkout│                          │
            │   │  → DB → cache) │                          │
            │   └────────────────┘                          │
            │   ┌──── metrics ───┐                          │
            │   │ counters,      │   Shared Resource:       │
            │   │ histograms,    │   service.name,          │
            │   │ gauges         │   service.version,       │
            │   └────────────────┘   deployment.environment │
            │   ┌──── logs ──────┐   k8s.pod.name, ...      │
            │   │ log records    │                          │
            │   │ (+ trace_id,   │   Shared Context:        │
            │   │   span_id)     │   trace_id, span_id      │
            │   └────────────────┘                          │
            │   ┌─ profiling ────┐                          │
            │   │ (incubación)   │                          │
            │   └────────────────┘                          │
            └──────────────────────┬────────────────────────┘
                                   │  OTLP (gRPC / HTTP)
                                   ▼
            ┌───────────────────────────────────────────────┐
            │             OTel Collector                    │
            │  ┌──────────────┐  ┌──────────────┐           │
            │  │ receivers    │  │ processors   │           │
            │  │ (otlp, prom, │→ │ (batch,      │ → exporters
            │  │  jaeger…)    │  │  memory_lim, │           │
            │  └──────────────┘  │  attributes, │           │
            │                    │  tail_sampl.)│           │
            │                    └──────────────┘           │
            └───┬───────────────┬─────────────┬─────────────┘
                │               │             │
                ▼               ▼             ▼
         ┌──────────┐    ┌───────────┐  ┌───────────┐
         │ Prometheus│   │ Tempo /   │  │  Loki /   │
         │ / Mimir   │   │ Jaeger    │  │  Datadog  │
         │ (metrics) │   │ (traces)  │  │  (logs)   │
         └──────────┘    └───────────┘  └───────────┘
```

### Lectura clave

1. **Un único `Resource`** (quién emite: servicio, versión, pod) **se adjunta a los 3 signals**. Esto es lo que permite correlacionarlos en el backend.
2. **Un único `Context`** (quién es el request actual: `trace_id`, `span_id`) **se adjunta a los 3 signals** cuando aplica. Un log emitido dentro de un span lleva el `trace_id` del span automáticamente.
3. **El Collector** es opcional pero recomendado. Sin él, el SDK exporta directo al backend (más simple, menos robusto, sin filtros ni enriquecimiento).
4. **Cambiar de backend** = cambiar un **exporter** en el Collector. El código no se toca.

## 3. Lo que NO aparece en el diagrama (porque NO es OTel)

- **El storage** (TSDB de Prometheus, bucket de Tempo, índice de Loki). OTel entrega hasta la puerta; dentro del backend ya es asunto suyo.
- **El query language** (PromQL, TraceQL, LogQL). Son del backend. OTel estandariza la **emisión**, no la **consulta**.
- **Los dashboards** (Grafana, Datadog UI, Kibana). Siguen siendo específicos del backend.
- **El alerting** (Alertmanager, Grafana Alerting, PagerDuty). Idem.

Repítelo mentalmente mientras miras el diagrama hasta que suene aburrido:

> **OTel = generación + transporte + semántica. No almacena, no consulta, no dibuja.**

## 4. Preguntas de autocomprobación

1. Si un servicio emite **metrics** y **logs** pero **no traces**, ¿puede un log tener `trace_id` útil? ¿Por qué?
2. ¿Dónde se decide **a qué backend** van los traces: en el código de la app, en el SDK, o en el Collector? Da un argumento para cada ubicación posible.
3. Si quiero migrar de Datadog a Grafana Cloud **manteniendo el mismo código**, ¿qué 2–3 cosas tengo que cambiar?
4. ¿Por qué profiling está "en incubación" y qué consecuencias tiene asumir eso en una decisión de adopción hoy?

Las respuestas quedan abiertas; se discuten en la actividad `01-landscape-mapping/`.
