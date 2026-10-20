# Recursos — otel-03

> Verifica fecha de la documentación: OTel evoluciona rápido. Nombres de paquetes y flags del CLI son los vigentes en 2024–2025 y pueden refinarse.

## Oficiales OpenTelemetry

- API / SDK / instrumentation (overview): `https://opentelemetry.io/docs/concepts/instrumentation/`
- Python getting started: `https://opentelemetry.io/docs/languages/python/getting-started/`
- Instrumentation libraries (Python contrib): `https://github.com/open-telemetry/opentelemetry-python-contrib`
- Registry (todas las instrumentations, cualquier lenguaje): `https://opentelemetry.io/ecosystem/registry/`
- `opentelemetry-instrument` CLI: `https://opentelemetry.io/docs/zero-code/python/`
- Spec: separación API/SDK: `https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/overview.md`

## eBPF / zero-code

- Grafana Beyla: `https://grafana.com/oss/beyla-ebpf/` y docs `https://grafana.com/docs/beyla/latest/`
- Pixie: `https://docs.px.dev/`
- Cilium Hubble (networking L7): `https://docs.cilium.io/en/stable/observability/hubble/`

## Paquetes PyPI mencionados

- `opentelemetry-api` — `https://pypi.org/project/opentelemetry-api/`
- `opentelemetry-sdk` — `https://pypi.org/project/opentelemetry-sdk/`
- `opentelemetry-distro` — `https://pypi.org/project/opentelemetry-distro/`
- `opentelemetry-instrumentation-fastapi` — `https://pypi.org/project/opentelemetry-instrumentation-fastapi/`
- `opentelemetry-instrumentation-requests` — `https://pypi.org/project/opentelemetry-instrumentation-requests/`
- `opentelemetry-instrumentation-psycopg2` — `https://pypi.org/project/opentelemetry-instrumentation-psycopg2/`
- `opentelemetry-instrumentation-logging` — `https://pypi.org/project/opentelemetry-instrumentation-logging/`

## Lecturas recomendadas

- "Why OpenTelemetry has an API/SDK split" (blog oficial): `https://opentelemetry.io/blog/`
- Charity Majors sobre observability y trazas: `https://charity.wtf/`
- Honeycomb — "The Three Pillars Problem": `https://www.honeycomb.io/`

## Dentro del curso

- Módulo previo: `../../01-what-and-why-signals-and-maturity/`
- Módulo siguiente: `../../04-instrumenting-python-traces/` (profundiza `otel-03` con spans manuales ricos y OTLP exporter).
