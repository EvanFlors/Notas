# Ejemplo 03 — OpenTelemetry Operator + Tempo

## Concepto que demuestra

- Instalar **cert-manager** (requerido por el OTel Operator para su webhook de admission).
- Instalar el **OpenTelemetry Operator** vía Helm.
- Desplegar **Tempo** monolítico (single-binary mode) como backend de traces.
- Desplegar un `OpenTelemetryCollector` (CR) que recibe OTLP y exporta a Tempo.
- Auto-instrumentar una app Python con el CR `Instrumentation`.
- Visualizar traces en Grafana (datasource Tempo).

## Prerrequisitos

- Haber hecho `01-prometheus-operator-stack` (Grafana corriendo).
- `kubectl` ≥ 1.28, `helm` ≥ 3.14.

## Archivos

- `cert-manager.sh` — instala cert-manager (requisito del webhook).
- `tempo.yaml` — Tempo single-binary con object storage local (emptyDir, no apto para prod).
- `otel-collector.yaml` — CR `OpenTelemetryCollector` modo `deployment` (sidecar-less).
- `instrumentation.yaml` — CR `Instrumentation` para auto-inyectar OTel SDK Python.
- `demo-app.yaml` — app con annotation `instrumentation.opentelemetry.io/inject-python: "true"`.
- `grafana-datasource-tempo.yaml` — datasource adicional en Grafana apuntando a Tempo.

## Ejecución

```bash
cd examples/03-otel-operator-with-tempo

# 1. cert-manager (webhook del operator depende de certs)
bash cert-manager.sh

# 2. OpenTelemetry Operator
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
helm install otel-op open-telemetry/opentelemetry-operator \
  --namespace opentelemetry-operator-system --create-namespace \
  --set manager.collectorImage.repository="otel/opentelemetry-collector-contrib" \
  --wait --timeout 10m

# 3. Tempo
kubectl create ns tracing || true
kubectl -n tracing apply -f tempo.yaml

# 4. Collector + Instrumentation + demo-app
kubectl create ns apps || true
kubectl -n apps apply -f otel-collector.yaml
kubectl -n apps apply -f instrumentation.yaml
kubectl -n apps apply -f demo-app.yaml

# 5. Datasource de Tempo en Grafana
kubectl -n monitoring apply -f grafana-datasource-tempo.yaml
kubectl -n monitoring rollout restart deploy/kps-grafana

# 6. Generar traces
kubectl -n apps port-forward svc/demo-app 8000:8000 &
for i in $(seq 1 20); do curl -s localhost:8000/ > /dev/null; done

# 7. Grafana → Explore → datasource Tempo → Service: demo-app
kubectl -n monitoring port-forward svc/kps-grafana 3000:80 &
```

## Qué debés observar

- `kubectl -n apps get otelinst,otelcol` muestra ambos CRs activos.
- El Pod del demo-app tiene un **initContainer** inyectado por el operator (`opentelemetry-auto-instrumentation`) que copia el SDK Python a un emptyDir y setea `PYTHONPATH`.
- En Grafana → Explore → Tempo → "Search" por `service.name=demo-app` aparece la lista de traces; abrir uno muestra los spans del servidor HTTP.
- El Collector del `OpenTelemetryCollector` CR expone métricas propias (`/metrics` del Collector) que podrías scrapear con un `PodMonitor`.

## Fundamentos internos

- El `Instrumentation` CR define imágenes de SDK por lenguaje y variables de entorno (`OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_SERVICE_NAME`, etc.). El operator los inyecta en el Pod al verlo con la annotation.
- El Collector es simplemente otro Deployment, pero su spec vive en el CR. Si editás el CR, el operator reconfigura el Collector con nueva config y reinicia.
- Tempo recibe traces vía OTLP gRPC (`:4317`) o HTTP (`:4318`). El Collector les hace batching antes de enviar.
- En Grafana, el datasource Tempo acepta `nativeSearch` desde 2.x; búsqueda por `service.name` es la query básica.

## Limpieza

```bash
kubectl delete ns apps tracing
helm uninstall otel-op -n opentelemetry-operator-system
kubectl delete ns opentelemetry-operator-system
kubectl delete ns cert-manager
pkill -f "kubectl.*port-forward" 2>/dev/null || true
```
