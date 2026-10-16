# Example 01 — Instalar kube-prometheus-stack via Helm

Instalación mínima reproducible sobre un cluster `kind` para hacerse una idea del footprint y de los recursos que crea.

> **Nota de recursos**: el chart arrastra ~500 MB de imágenes. Si tu máquina tiene < 6 GB RAM libres o no tienes Docker arrancado, salta este ejemplo (los conceptos están en `theory/lesson.md`).

## Prerrequisitos

```bash
command -v docker >/dev/null  && echo OK docker
command -v kind   >/dev/null  && echo OK kind
command -v kubectl >/dev/null && echo OK kubectl
command -v helm   >/dev/null  && echo OK helm
```

## Paso 1 — Crear el cluster kind

```bash
cat >/tmp/kind-kps.yaml <<'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
EOF

kind create cluster --name kps-demo --config /tmp/kind-kps.yaml
kubectl cluster-info --context kind-kps-demo
```

## Paso 2 — Añadir el repo y crear el namespace

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring
```

## Paso 3 — Values mínimos

Suficiente para kind: desactivamos componentes del control-plane que kind no expone (etcd, controller-manager, scheduler, kube-proxy) para evitar targets rojos.

```bash
cat >/tmp/kps-values.yaml <<'EOF'
grafana:
  adminPassword: admin
  service:
    type: ClusterIP
prometheus:
  prometheusSpec:
    retention: 2d
    resources:
      requests: { cpu: 100m, memory: 400Mi }
alertmanager:
  alertmanagerSpec:
    resources:
      requests: { cpu: 50m, memory: 100Mi }
# kind no expone estos components de forma scrapeable:
kubeControllerManager: { enabled: false }
kubeScheduler:         { enabled: false }
kubeEtcd:              { enabled: false }
kubeProxy:             { enabled: false }
EOF
```

## Paso 4 — Instalar

```bash
helm install kps prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f /tmp/kps-values.yaml \
  --wait --timeout 10m
```

## Paso 5 — Inspeccionar lo que creó

```bash
# Pods del stack
kubectl -n monitoring get pods

# CRDs del Operator (deberían verse ≥ 7)
kubectl get crd | grep monitoring.coreos.com

# Recursos custom creados por el chart
kubectl -n monitoring get prometheus,alertmanager,servicemonitor,prometheusrule
```

## Paso 6 — Acceder a las UIs

```bash
# Prometheus
kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090:9090 &
# http://localhost:9090/targets

# Grafana (user admin / pass admin)
kubectl -n monitoring port-forward svc/kps-grafana 3000:80 &
# http://localhost:3000

# Alertmanager
kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-alertmanager 9093:9093 &
# http://localhost:9093
```

## Paso 7 — Mirar el `prometheus.yml` generado

```bash
kubectl -n monitoring get secret prometheus-kps-kube-prometheus-stack-prometheus \
  -o jsonpath='{.data.prometheus\.yaml\.gz}' \
  | base64 -d | gunzip > /tmp/prometheus.generated.yml
wc -l /tmp/prometheus.generated.yml       # típicamente > 400 líneas
grep -c 'job_name' /tmp/prometheus.generated.yml   # un job por scrape
```

Esto demuestra la *indirección* del Operator: tú no escribiste YAML Prometheus, pero existe.

## Limpieza

```bash
pkill -f "port-forward svc/kps" 2>/dev/null || true
helm uninstall kps -n monitoring
kubectl delete namespace monitoring
kind delete cluster --name kps-demo
rm -f /tmp/kind-kps.yaml /tmp/kps-values.yaml /tmp/prometheus.generated.yml
```
