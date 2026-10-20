# Example 02 — ServiceMonitor para una app FastAPI

Partimos de un cluster con `kube-prometheus-stack` instalado (release `kps`, namespace `monitoring`) — ver ejemplo 01.

Vamos a desplegar una app FastAPI que exponga `/metrics`, un `Service` y un `ServiceMonitor`. Luego verificamos que aparece como `UP` en Prometheus.

## Paso 1 — Namespace y app

```bash
kubectl create namespace apps
```

Un Deployment con la imagen pública [`prometheus/prometheus-example-app`](https://github.com/brancz/prometheus-example-app) (ya expone `/metrics` sobre el port 8080 — nos ahorra escribir Python).

```bash
cat >/tmp/fastapi-app.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fastapi
  namespace: apps
  labels: { app: fastapi }
spec:
  replicas: 2
  selector: { matchLabels: { app: fastapi } }
  template:
    metadata:
      labels: { app: fastapi }
    spec:
      containers:
        - name: app
          image: ghcr.io/prometheus-community/prometheus-example-app:v0.6.0
          args: ["--listen-address=:8080"]
          ports:
            - { name: http, containerPort: 8080 }
---
apiVersion: v1
kind: Service
metadata:
  name: fastapi
  namespace: apps
  labels: { app: fastapi }
spec:
  selector: { app: fastapi }
  ports:
    - { name: http, port: 8080, targetPort: http }
EOF

kubectl apply -f /tmp/fastapi-app.yaml
kubectl -n apps rollout status deploy/fastapi
```

## Paso 2 — ServiceMonitor

**Clave**: la label `release: kps` para que el Prometheus CR por default lo recoja (ver §6 de la lección).

```bash
cat >/tmp/fastapi-sm.yaml <<'EOF'
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: fastapi
  namespace: apps
  labels:
    release: kps
spec:
  selector:
    matchLabels:
      app: fastapi
  namespaceSelector:
    matchNames: [apps]
  endpoints:
    - port: http          # nombre, no número
      path: /metrics
      interval: 15s
EOF

kubectl apply -f /tmp/fastapi-sm.yaml
```

## Paso 3 — Verificar que lo recogió

```bash
# El Operator debería re-generar en ≤ 30s. Comprobamos el prometheus.yml.
kubectl -n monitoring get secret prometheus-kps-kube-prometheus-stack-prometheus \
  -o jsonpath='{.data.prometheus\.yaml\.gz}' \
  | base64 -d | gunzip | grep -A1 'job_name:.*apps/fastapi'
```

En la UI:

```bash
kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090:9090 &
# http://localhost:9090/targets → debería listar "serviceMonitor/apps/fastapi/0" como UP
# http://localhost:9090/graph?g0.expr=up%7Bjob%3D%22fastapi%22%7D
```

Query en PromQL:

```promql
sum by (instance) (rate(http_requests_total[1m]))
```

Generar algo de tráfico para ver métricas crecer:

```bash
kubectl -n apps run gen --rm -i --image=curlimages/curl --restart=Never -- \
  sh -c 'for i in $(seq 1 100); do curl -s fastapi.apps.svc:8080/ >/dev/null; done'
```

## Troubleshooting

Si no aparece:

```bash
# ¿SM tiene la label 'release: kps'?
kubectl -n apps get servicemonitor fastapi --show-labels

# ¿Service tiene endpoints?
kubectl -n apps get endpoints fastapi

# ¿Qué selector pide el Prometheus CR?
kubectl -n monitoring get prometheus kps-kube-prometheus-stack-prometheus \
  -o jsonpath='{.spec.serviceMonitorSelector}{"\n"}'
```

## Limpieza

```bash
pkill -f "port-forward svc/kps" 2>/dev/null || true
kubectl delete -f /tmp/fastapi-sm.yaml -f /tmp/fastapi-app.yaml
kubectl delete namespace apps
rm -f /tmp/fastapi-app.yaml /tmp/fastapi-sm.yaml
```
