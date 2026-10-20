# Recursos — otel-08 Collector

## Documentacion oficial

- Collector overview: <https://opentelemetry.io/docs/collector/>
- Configuration structure: <https://opentelemetry.io/docs/collector/configuration/>
- Receivers (catalogo): <https://opentelemetry.io/docs/collector/configuration/#receivers>
- Processors (catalogo): <https://opentelemetry.io/docs/collector/configuration/#processors>
- Exporters (catalogo): <https://opentelemetry.io/docs/collector/configuration/#exporters>
- Deployment patterns: <https://opentelemetry.io/docs/collector/deployment/>

## Repos

- Core: <https://github.com/open-telemetry/opentelemetry-collector>
- Contrib: <https://github.com/open-telemetry/opentelemetry-collector-contrib>
- Builder (crear distros propias): <https://github.com/open-telemetry/opentelemetry-collector/tree/main/cmd/builder>

## OTTL

- OTTL overview: <https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/pkg/ottl>
- Transform processor: <https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/transformprocessor>
- OTTL contexts: span, spanevent, datapoint, log, resource.

## Processors clave

- memory_limiter: <https://github.com/open-telemetry/opentelemetry-collector/tree/main/processor/memorylimiterprocessor>
- batch: <https://github.com/open-telemetry/opentelemetry-collector/tree/main/processor/batchprocessor>
- attributes: <https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/attributesprocessor>
- resource: <https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/resourceprocessor>
- tail_sampling: <https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/tailsamplingprocessor>
- k8sattributes: <https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/k8sattributesprocessor>

## Imagenes Docker

- Core: `otel/opentelemetry-collector:latest`
- Contrib: `otel/opentelemetry-collector-contrib:latest`

## Debugging

- debug exporter (reemplaza al viejo `logging` exporter): <https://github.com/open-telemetry/opentelemetry-collector/tree/main/exporter/debugexporter>
- file exporter: <https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/fileexporter>

## Distros

- Grafana Alloy (sucesor de Grafana Agent, fork relacionado): <https://grafana.com/docs/alloy/latest/>
- AWS Distro for OpenTelemetry (ADOT): <https://aws-otel.github.io/>
- Splunk OpenTelemetry Collector: <https://docs.splunk.com/observability/en/gdi/opentelemetry/opentelemetry.html>

## Especificacion

- OTLP spec: <https://github.com/open-telemetry/opentelemetry-proto>
- Collector config spec: <https://github.com/open-telemetry/opentelemetry-collector/blob/main/CONFIG.md>
