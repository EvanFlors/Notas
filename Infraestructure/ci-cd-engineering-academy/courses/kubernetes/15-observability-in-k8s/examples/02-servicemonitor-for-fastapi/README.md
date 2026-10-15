# Ejemplo 02 — ServiceMonitor para una app FastAPI

## Concepto que demuestra

- Instrumentar una app Python/FastAPI con `prometheus_client` para exponer `/metrics`.
- Empaquetarla y desplegarla en el cluster (`Deployment` + `Service`).
- Crear un `ServiceMonitor` que Prometheus Operator **adopta** y empieza a scrapear.
- Verificar en Prometheus UI que el target aparece `UP` y las métricas se consultan.

## Prerrequisitos

- Haber hecho `01-prometheus-operator-stack` (necesitás Prometheus Operator corriendo).
- `kubectl` ≥ 1.28, `docker`.

## Archivos

- `app.py` — FastAPI con `/`, `/healthz` y `/metrics`.
- `requirements.txt` — `fastapi`, `uvicorn`, `prometheus_client`.
- `Dockerfile` — imagen slim basada en `python:3.12-slim`.
- `k8s/deployment.yaml` — Deployment + Service (con `port.name: http` **requerido**).
- `k8s/servicemonitor.yaml` — el ServiceMonitor.

## Ejecución

```bash
cd examples/02-servicemonitor-for-fastapi

# 1. Build de la imagen (local) y carga en kind
docker build -t fastapi-metrics:0.1 .
kind load docker-image fastapi-metrics:0.1 --name obs

# 2. Namespace + manifests
kubectl create ns apps || true
kubectl -n apps apply -f k8s/deployment.yaml
kubectl -n apps apply -f k8s/servicemonitor.yaml

# 3. Esperar pods
kubectl -n apps rollout status deploy/fastapi

# 4. Generar algo de tráfico para que las métricas tengan sentido
kubectl -n apps port-forward svc/fastapi 8000:8000 &
for i in $(seq 1 50); do curl -s localhost:8000/ > /dev/null; done
for i in $(seq 1 10); do curl -s localhost:8000/boom > /dev/null; done

# 5. Verificar en Prometheus
kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090:9090 &
# En el browser: Status -> Targets -> buscar 'apps/fastapi'
# Query: rate(http_requests_total{app="fastapi"}[1m])
```

## Qué debés observar

- `kubectl -n apps get servicemonitor fastapi-app -o yaml` muestra `labels.release: kps` → **imprescindible** porque el `serviceMonitorSelector` del CR `Prometheus` matchea por ese label.
- En Prometheus UI → **Status → Targets**: aparece `serviceMonitor/apps/fastapi-app/0` con dos endpoints (uno por réplica) y estado `UP`.
- En Prometheus UI → **Graph**: `http_requests_total` tiene labels `app="fastapi"`, `handler="/"`, `method="GET"`, `status="200"`, etc.
- Si cambiás el `port.name` del Service a algo distinto de `http`, el ServiceMonitor **no scrapea** (el `endpoints[].port` matchea por nombre).

## Fundamentos internos

- `prometheus_client.start_http_server(...)` no se usa aquí: usamos `make_asgi_app()` para montar `/metrics` en el mismo puerto 8000 de FastAPI. Esto es más natural en Kubernetes porque el Service tiene **un** puerto.
- El Prometheus Operator convierte el `ServiceMonitor` en un `scrape_config` dentro del Secret `prometheus-kps-kube-prometheus-stack-prometheus`, montado como `/etc/prometheus/config_out/prometheus.env.yaml` en el Pod.
- Prometheus hace **service discovery** por Kubernetes API; cada Pod detrás del Service se scrapea individualmente (vía EndpointSlice).

## Limpieza

```bash
kubectl delete ns apps
docker rmi fastapi-metrics:0.1 2>/dev/null || true
pkill -f "kubectl.*port-forward" 2>/dev/null || true
```
