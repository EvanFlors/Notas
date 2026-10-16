# Recursos — otel-10 sampling

## Documentación oficial

- OpenTelemetry — Sampling concepts: https://opentelemetry.io/docs/concepts/sampling/
- OTel Python SDK samplers (`ParentBased`, `TraceIdRatioBased`): https://opentelemetry-python.readthedocs.io/en/latest/sdk/trace.sampling.html
- OTel Collector `tail_sampling` processor README: https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/tailsamplingprocessor
- OTel Collector `probabilistic_sampler` processor: https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/probabilisticsamplerprocessor
- OTel Collector `loadbalancing` exporter (afinidad por `trace_id`): https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/loadbalancingexporter

## Specs / enhancement proposals

- OTEP 235 — Consistent probability sampling: https://github.com/open-telemetry/oteps/blob/main/text/trace/0235-sampling-threshold-in-trace-state.md
- W3C Trace Context (`traceparent` / `tracestate`): https://www.w3.org/TR/trace-context/
- OTel sampling SDK spec: https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/trace/sdk.md#sampling

## Charlas y lecturas

- "Tail-based sampling at scale" — KubeCon talks (buscar KubeCon + "tail sampling").
- Grafana Tempo docs — sampling recommendations: https://grafana.com/docs/tempo/latest/configuration/
- Lightstep (ServiceNow) — "The pros and cons of head and tail-based sampling": https://docs.lightstep.com/docs/sampling-and-tracing (histórico, aún útil conceptualmente).
- OpenTelemetry Collector Operator docs (si usas K8s): https://github.com/open-telemetry/opentelemetry-operator

## Herramientas útiles

- `telemetrygen` — generador de carga OTLP para probar policies: https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/cmd/telemetrygen
- `otel-cli` — enviar traces desde shell: https://github.com/equinix-labs/otel-cli
