# otel-12 — Recursos

## Documentación oficial

- OpenTelemetry Operator — repo: <https://github.com/open-telemetry/opentelemetry-operator>
- OpenTelemetry Operator — docs del CR `OpenTelemetryCollector`: <https://github.com/open-telemetry/opentelemetry-operator/blob/main/docs/api.md>
- OpenTelemetry — K8s guide (collector + operator): <https://opentelemetry.io/docs/kubernetes/>
- Auto-instrumentation (operator): <https://opentelemetry.io/docs/kubernetes/operator/automatic/>
- Target Allocator: <https://github.com/open-telemetry/opentelemetry-operator/blob/main/cmd/otel-allocator/README.md>

## Processors / receivers citados

- `k8sattributes` processor: <https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/k8sattributesprocessor>
- `k8sobjects` receiver: <https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/k8sobjectsreceiver>
- `k8s_cluster` receiver: <https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/k8sclusterreceiver>
- `kubeletstats` receiver: <https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/kubeletstatsreceiver>

## Dependencias

- cert-manager: <https://cert-manager.io/docs/installation/>
- Prometheus Operator (integración con TA): <https://github.com/prometheus-operator/prometheus-operator>

## Lecturas recomendadas

- Blog CNCF: "OpenTelemetry Operator — architecture deep dive": <https://www.cncf.io/blog/>
- Grafana Labs — "Using the OTel Operator with Grafana Cloud": <https://grafana.com/docs/opentelemetry/>
- "Operator vs Helm for OTel in production" (comparativa comunitaria frecuente — buscar entradas recientes en el blog de OTel): <https://opentelemetry.io/blog/>

## Charts / manifests referenciados

- Operator release YAML (manifest unificado): <https://github.com/open-telemetry/opentelemetry-operator/releases>
- cert-manager release YAML: <https://github.com/cert-manager/cert-manager/releases>
- opentelemetry-collector-contrib images: <https://hub.docker.com/r/otel/opentelemetry-collector-contrib/tags>
