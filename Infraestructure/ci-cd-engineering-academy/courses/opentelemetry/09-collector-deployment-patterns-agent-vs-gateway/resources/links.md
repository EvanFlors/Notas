# Recursos — otel-09

## Documentación oficial

- Collector — overview: <https://opentelemetry.io/docs/collector/>
- Collector — deployment: <https://opentelemetry.io/docs/collector/deployment/>
  - Agent pattern: <https://opentelemetry.io/docs/collector/deployment/agent/>
  - Gateway pattern: <https://opentelemetry.io/docs/collector/deployment/gateway/>
  - Sidecar pattern: <https://opentelemetry.io/docs/collector/deployment/no-collector/> (y variantes)
  - "No Collector" pattern: <https://opentelemetry.io/docs/collector/deployment/no-collector/>
- Collector — scaling: <https://opentelemetry.io/docs/collector/scaling/>
- Configuration — exporters OTLP (`sending_queue`, `retry_on_failure`): <https://github.com/open-telemetry/opentelemetry-collector/tree/main/exporter/otlpexporter>
- Extension `file_storage`: <https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/extension/storage/filestorage>
- Extension `health_check`: <https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/extension/healthcheckextension>
- Processor `memory_limiter`: <https://github.com/open-telemetry/opentelemetry-collector/tree/main/processor/memorylimiterprocessor>
- Processor `batch`: <https://github.com/open-telemetry/opentelemetry-collector/tree/main/processor/batchprocessor>
- Processor `k8sattributes`: <https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/k8sattributesprocessor>

## Distros

- `otelcol` core: <https://github.com/open-telemetry/opentelemetry-collector-releases>
- `otelcol-contrib`: <https://github.com/open-telemetry/opentelemetry-collector-contrib>
- **ADOT** (AWS Distro for OpenTelemetry): <https://aws-otel.github.io/>
- **Grafana Alloy**: <https://grafana.com/docs/alloy/>
- OTel Operator (CRs OpenTelemetryCollector, Instrumentation, TargetAllocator): <https://github.com/open-telemetry/opentelemetry-operator>

## Tooling de laboratorio

- `kind`: <https://kind.sigs.k8s.io/>
- `telemetrygen`: <https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/cmd/telemetrygen>

## Lecturas recomendadas

- CNCF Blog — "OpenTelemetry Collector deployment patterns": <https://www.cncf.io/blog/>
- Grafana — "Introducing Grafana Alloy": <https://grafana.com/blog/>
- AWS — "Build an observability pipeline with ADOT": <https://aws.amazon.com/blogs/opensource/>
- OTel SIGs — Collector performance benchmarks: <https://github.com/open-telemetry/opentelemetry-collector/tree/main/testbed>
