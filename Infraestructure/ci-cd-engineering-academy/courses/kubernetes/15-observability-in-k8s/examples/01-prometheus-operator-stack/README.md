# Ejemplo 01 — kube-prometheus-stack sobre kind

## Concepto que demuestra

- Instalar `kube-prometheus-stack` con Helm.
- Confirmar que Prometheus, Alertmanager, Grafana, `node-exporter`, `kube-state-metrics` quedan corriendo.
- Verificar que la mixin oficial trae ServiceMonitors y PrometheusRules para componentes del cluster.
- Acceder a la UI de Prometheus y Grafana vía `kubectl port-forward`.

## Prerrequisitos

- `kind` ≥ 0.22, `kubectl` ≥ 1.28, `helm` ≥ 3.14, `docker` corriendo.
- **Al menos 4 GB** libres de RAM para Docker (el chart despliega varios componentes).
- Si tu host no tiene esos recursos o te falta `helm`/`docker`, saltá el ejemplo y leé el walkthrough — el conocimiento transferible está en los manifests y comandos.

## Archivos

- `values.yaml` — valores mínimos del chart (resources recortados, ingress deshabilitado, defaults razonables).
- `kind-cluster.yaml` — definición del cluster kind con 1 control-plane + 2 workers (para que `nodeSelector` y DaemonSets tengan sentido).

## Ejecución

```bash
# 1. Crear cluster kind
kind create cluster --name obs --config kind-cluster.yaml

# 2. Añadir repo Helm e instalar el chart
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kps prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --values values.yaml \
  --wait --timeout 10m

# 3. Esperar a que todo esté listo
kubectl -n monitoring get pods

# 4. UI de Prometheus (http://localhost:9090)
kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090:9090 &

# 5. UI de Grafana (http://localhost:3000, user: admin)
kubectl -n monitoring get secret kps-grafana -o jsonpath="{.data.admin-password}" | base64 -d; echo
kubectl -n monitoring port-forward svc/kps-grafana 3000:80 &
```

## Qué debés observar

- `kubectl -n monitoring get pods` muestra: `prometheus-kps-kube-prometheus-stack-prometheus-0`, `alertmanager-kps-kube-prometheus-stack-alertmanager-0`, `kps-grafana-...`, `kps-kube-state-metrics-...`, `kps-prometheus-node-exporter-*` (uno por nodo).
- `kubectl -n monitoring get servicemonitors` lista 10+ CRs ya desplegados por el chart (apiserver, kube-controller-manager, kube-scheduler, kubelet, coredns, kube-state-metrics, node-exporter, grafana, prometheus, alertmanager, operator).
- `kubectl -n monitoring get prometheusrules` lista decenas de reglas (la kubernetes-mixin).
- En Prometheus UI → **Status → Targets**: todos los targets deben estar `UP`. Si hay alguno `DOWN`, en kind es normal que `kube-controller-manager` y `kube-scheduler` den `DOWN` porque escuchan solo en `127.0.0.1` dentro del Pod del control plane (ver `values.yaml` para el workaround).
- En Grafana → **Dashboards → Browse**: dashboards precargados (`Kubernetes / Compute Resources / Cluster`, `/ Namespace (Pods)`, `/ Workload`, etc.).

## Fundamentos internos

- El chart aplica primero los CRDs (en `templates/crds/`), luego el `Deployment` del operator, luego los CRs (`Prometheus`, `Alertmanager`) y los `ServiceMonitor`/`PrometheusRule`.
- El operator **observa los CRs** y genera el `prometheus.yaml` real como Secret montado en el Pod de Prometheus. Un `curl -s localhost:9090/api/v1/status/config` (desde dentro del Pod) te lo muestra.
- Grafana lee datasources desde `kps-grafana-datasources` (Secret/ConfigMap). Prometheus está en `http://kps-kube-prometheus-stack-prometheus:9090` dentro del cluster.

## Limpieza

```bash
# Dejar de port-forwardear
pkill -f "kubectl.*port-forward" 2>/dev/null || true

# Borrar la release y los CRDs (los CRDs no se borran con uninstall)
helm uninstall kps -n monitoring
kubectl delete ns monitoring
kubectl get crd -o name | grep monitoring.coreos.com | xargs -r kubectl delete

# Borrar el cluster
kind delete cluster --name obs
```
