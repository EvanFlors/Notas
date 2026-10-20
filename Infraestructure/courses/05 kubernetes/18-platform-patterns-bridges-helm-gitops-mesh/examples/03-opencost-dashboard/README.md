# Ejemplo 03 — OpenCost dashboard tour

> Instalar **OpenCost** (CNCF) en un cluster local junto con Prometheus (dependencia), ver el dashboard y entender qué está midiendo. OpenCost calcula el coste K8s por workload/namespace/label combinando métricas Prometheus con precios cloud (o un pricing custom).

## Qué vamos a hacer

1. Cluster `kind` con una app sintética (que consuma CPU/memoria visible).
2. Instalar `kube-prometheus-stack` (trae Prometheus + Grafana).
3. Instalar OpenCost apuntando al Prometheus del paso 2.
4. Tour por el dashboard de OpenCost (UI propia) y por el Grafana con dashboards OpenCost.
5. Limpiar.

## Prerrequisitos

- `kind`, `kubectl`, `helm`.
- Al menos 6 GB libres para Docker (Prometheus + OpenCost pesan).
- Red hacia los repos helm.

## Pasos

### 1. Cluster y app de carga sintética

```bash
mkdir -p /tmp/k8s-18-opencost && cd /tmp/k8s-18-opencost
kind create cluster --name k8s18-cost

kubectl create ns demo
kubectl -n demo create deployment hog --image=nginx:1.27
kubectl -n demo set resources deployment/hog \
  --requests=cpu=200m,memory=256Mi \
  --limits=cpu=500m,memory=512Mi
kubectl -n demo label deployment hog team=platform-demo product=hog
```

### 2. Prometheus stack

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kps prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=30030 \
  --wait --timeout 10m
```

Prometheus queda en `monitoring/kps-kube-prometheus-stack-prometheus:9090`.

### 3. OpenCost

```bash
helm repo add opencost https://opencost.github.io/opencost-helm-chart
helm repo update

helm install opencost opencost/opencost \
  --namespace opencost --create-namespace \
  --set opencost.prometheus.internal.enabled=true \
  --set opencost.prometheus.internal.namespaceName=monitoring \
  --set opencost.prometheus.internal.serviceName=kps-kube-prometheus-stack-prometheus \
  --set opencost.prometheus.internal.port=9090 \
  --wait --timeout 5m
```

Esperar al pod:

```bash
kubectl -n opencost rollout status deploy/opencost --timeout=5m
```

Port-forwards (en terminales separadas o en background):

```bash
kubectl -n opencost port-forward svc/opencost 9003:9003 9090:9090 &
# UI de OpenCost: http://localhost:9090   (NO el Prometheus; es su propio UI servido en 9090 del pod)
# API JSON:       http://localhost:9003/allocation/compute?window=1h
```

### 4. Tour del dashboard

En la UI (`http://localhost:9090`):

- **Allocations** — coste asignado por `namespace`, `controller`, `pod`, `label`. Agrúpalo por `namespace` y filtra ventana `1h`. Verás `demo` con coste imputado al Pod `hog`.
- **Assets** — recursos subyacentes (nodes, disks). En kind, el "nodo" vale $0 por default (no hay pricing cloud; el default local es simbólico).
- **Savings** — recomendaciones (p. ej. requests infladas). Con 1h de datos no hay mucho; mira el modelo.
- **Reports** — reports guardados (vacíos al inicio).
- **Settings** — pricing. En producción se conecta al pricing de AWS/GCP/Azure.

Prueba la API cruda:

```bash
curl -s 'http://localhost:9003/allocation/compute?window=1h&aggregate=namespace' \
  | head -c 800
```

Verás un JSON con, al menos, `__idle__` y `demo` como keys.

En Grafana (`http://localhost:30030`, user `admin`, password):

```bash
kubectl -n monitoring get secret kps-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

Importa el dashboard oficial de OpenCost (ID y JSON en la doc de OpenCost; el chart suele incluir un dashboard provisionable). Vista por `namespace`, `controller`, `label` (`team`, `product`).

### 5. Lectura mental

- OpenCost **no** pide tu factura cloud: estima en base a métricas Prometheus + un modelo de precios.
- La precisión depende de: pricing correcto, labels disciplinados en los workloads (sin `team=` no hay allocation por equipo), y requests razonables (sobre-provisioning aparece como coste "asignado pero no usado").
- **Showback** = publicar el dashboard a los equipos. **Chargeback** = facturar internamente. Empieza por showback hasta que confíes en los números.
- Kubecost = producto comercial encima; añade UI multi-cluster, forecasts y features enterprise.

## Limpieza

```bash
pkill -f "port-forward svc/opencost" || true

helm uninstall opencost -n opencost
helm uninstall kps -n monitoring
kubectl delete ns opencost monitoring demo --ignore-not-found
kind delete cluster --name k8s18-cost
rm -rf /tmp/k8s-18-opencost
```
