# Recursos — otel-01

Referencias oficiales y lecturas de apoyo para este módulo. **Verificar en Fase 4** del curso para asegurar vigencia (los enlaces y estados cambian).

## Oficiales (OpenTelemetry / CNCF)

- **Sitio oficial**: `https://opentelemetry.io/`
- **Qué es OTel (introducción)**: `https://opentelemetry.io/docs/what-is-opentelemetry/`
- **Status page (madurez por lenguaje × signal)**: `https://opentelemetry.io/status/`
- **Especificación**: `https://github.com/open-telemetry/opentelemetry-specification`
- **Semantic Conventions**: `https://github.com/open-telemetry/semantic-conventions`
- **CNCF (proyecto OTel)**: `https://www.cncf.io/projects/opentelemetry/`

## Historia (OpenTracing + OpenCensus → OpenTelemetry)

- Blog "merger" (anuncio 2019): buscar "OpenCensus and OpenTracing merge into OpenTelemetry" en el blog de CNCF / Google Open Source.
- Proyectos predecesores (deprecados):
  - OpenTracing: `https://opentracing.io/`
  - OpenCensus: `https://opencensus.io/`

## Signals

- **Traces**: `https://opentelemetry.io/docs/concepts/signals/traces/`
- **Metrics**: `https://opentelemetry.io/docs/concepts/signals/metrics/`
- **Logs**: `https://opentelemetry.io/docs/concepts/signals/logs/`
- **Profiling (incubación)**: `https://opentelemetry.io/docs/specs/otel/profiles/` (verificar estado).

## Backends y convivencia

- **Jaeger** (ahora proyecto OTel-compatible): `https://www.jaegertracing.io/`
- **Zipkin**: `https://zipkin.io/`
- **Prometheus + OTLP ingest**: `https://prometheus.io/docs/prometheus/latest/feature_flags/#otlp-receiver`
- **Grafana Tempo**: `https://grafana.com/docs/tempo/latest/`
- **Grafana Loki**: `https://grafana.com/docs/loki/latest/`

## OTel Collector (vista previa; se profundiza en `otel-08`)

- **Collector**: `https://opentelemetry.io/docs/collector/`
- **Collector Contrib** (receivers/processors/exporters comunitarios): `https://github.com/open-telemetry/opentelemetry-collector-contrib`
- **Distros**:
  - **ADOT** (AWS Distro for OpenTelemetry): `https://aws-otel.github.io/`
  - **Grafana Alloy** (sucesor/relacionado): `https://grafana.com/docs/alloy/latest/`

## Lecturas y charlas (buscar la versión más reciente)

- KubeCon talks "OpenTelemetry 101" / "State of OpenTelemetry" — hay varias cada año en el canal CNCF de YouTube.
- "OpenTelemetry: The Future of Observability" (CNCF blog, varias ediciones).
- "What is OpenTelemetry?" por Honeycomb / Lightstep / Grafana Labs.

## Específicos del módulo

- **W3C Trace Context** (base de la propagación — se profundiza en `otel-02`): `https://www.w3.org/TR/trace-context/`
- **CNCF Observability landscape**: `https://landscape.cncf.io/` → categoría *Observability and Analysis*.

## Para el curso previo (contexto)

- Si no completaste `prometheus-grafana` ≥ Nivel 2, al menos lee:
  - `courses/prometheus-grafana/01-observability-pillars-and-pull-model/theory/lesson.md`
  - `courses/prometheus-grafana/02-install-local-stack-and-first-scrape/README.md`

## Checklist de verificación requerida en Fase 4

- Estado actual del **status page** (especialmente Python para este curso).
- Estado del signal de **profiling** (si sigue en incubación o ya es Beta/Stable).
- Versión actual de **Semantic Conventions** y migraciones recientes.
- Compatibilidad OTLP ingest en **Prometheus** (feature flag o GA).
- Comparación vigente **OTel Collector contrib** vs **Grafana Alloy** vs **ADOT**.
