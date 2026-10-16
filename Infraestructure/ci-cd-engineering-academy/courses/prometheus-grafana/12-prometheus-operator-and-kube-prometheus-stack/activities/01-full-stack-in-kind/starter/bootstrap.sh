#!/usr/bin/env bash
# obs-12-01: montar kube-prometheus-stack sobre kind con una app de demo.
# Scratch dir /tmp/obs12-*. Degrada con SKIP si falta software o no hay docker.
#
# NO 'set -o pipefail': usamos 'grep -q' en pipelines donde SIGPIPE sería
# reportado como fallo espurio.
set -eu

CLUSTER="${CLUSTER:-obs12}"
NS_MON="${NS_MON:-monitoring}"
NS_APPS="${NS_APPS:-apps}"
RELEASE="${RELEASE:-kps}"
SCRATCH="/tmp/obs12-starter"

step() { echo; echo "== $* =="; }
have() { command -v "$1" >/dev/null 2>&1; }

step "0. Prerequisites"
missing=0
for b in docker kind kubectl helm; do
  if have "$b"; then
    echo "  OK  : $b -> $(command -v $b)"
  else
    echo "  MISS: $b not installed"; missing=$((missing+1))
  fi
done
if [ "$missing" -gt 0 ]; then
  echo "SKIP: $missing prerequisite(s) missing. Install them and retry."
  exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker daemon not running."
  exit 0
fi

mkdir -p "$SCRATCH"

step "1. kind cluster '$CLUSTER'"
if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "  cluster already exists; reusing."
else
  cat >"$SCRATCH/kind.yaml" <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
EOF
  kind create cluster --name "$CLUSTER" --config "$SCRATCH/kind.yaml"
fi
kubectl config use-context "kind-$CLUSTER" >/dev/null

step "2. Helm repo + namespaces"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null
kubectl get ns "$NS_MON"  >/dev/null 2>&1 || kubectl create ns "$NS_MON"
kubectl get ns "$NS_APPS" >/dev/null 2>&1 || kubectl create ns "$NS_APPS"

step "3. kube-prometheus-stack install"
cat >"$SCRATCH/values.yaml" <<'EOF'
grafana:
  adminPassword: admin
  service: { type: ClusterIP }
prometheus:
  prometheusSpec:
    retention: 2d
    resources:
      requests: { cpu: 100m, memory: 400Mi }
alertmanager:
  alertmanagerSpec:
    resources:
      requests: { cpu: 50m, memory: 100Mi }
kubeControllerManager: { enabled: false }
kubeScheduler:         { enabled: false }
kubeEtcd:              { enabled: false }
kubeProxy:             { enabled: false }
EOF

if helm status "$RELEASE" -n "$NS_MON" >/dev/null 2>&1; then
  echo "  release already installed; running upgrade."
  helm upgrade "$RELEASE" prometheus-community/kube-prometheus-stack \
    -n "$NS_MON" -f "$SCRATCH/values.yaml" --wait --timeout 10m
else
  helm install "$RELEASE" prometheus-community/kube-prometheus-stack \
    -n "$NS_MON" -f "$SCRATCH/values.yaml" --wait --timeout 10m
fi

step "4. Demo app + Service"
cat >"$SCRATCH/app.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fastapi
  namespace: $NS_APPS
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
          ports: [{ name: http, containerPort: 8080 }]
---
apiVersion: v1
kind: Service
metadata:
  name: fastapi
  namespace: $NS_APPS
  labels: { app: fastapi }
spec:
  selector: { app: fastapi }
  ports:
    - { name: http, port: 8080, targetPort: http }
EOF
kubectl apply -f "$SCRATCH/app.yaml"
kubectl -n "$NS_APPS" rollout status deploy/fastapi --timeout=120s

step "5. ServiceMonitor"
cat >"$SCRATCH/sm.yaml" <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: fastapi
  namespace: $NS_APPS
  labels:
    release: $RELEASE
spec:
  selector: { matchLabels: { app: fastapi } }
  namespaceSelector: { matchNames: [$NS_APPS] }
  endpoints:
    - port: http
      path: /metrics
      interval: 15s
EOF
kubectl apply -f "$SCRATCH/sm.yaml"

step "6. Dashboard as ConfigMap"
cat >"$SCRATCH/fastapi-dashboard.json" <<'EOF'
{
  "annotations": {"list": []}, "editable": true,
  "panels": [{
    "datasource": {"type":"prometheus","uid":"prometheus"},
    "type":"timeseries","title":"FastAPI RPS",
    "gridPos":{"h":8,"w":24,"x":0,"y":0},"id":1,
    "targets":[{"expr":"sum by (job) (rate(http_requests_total[1m]))","refId":"A"}]
  }],
  "schemaVersion":39,"style":"dark","tags":["fastapi","demo"],
  "templating":{"list":[]},"time":{"from":"now-15m","to":"now"},
  "timezone":"","title":"FastAPI Demo","uid":"fastapi-demo","version":1
}
EOF
kubectl -n "$NS_MON" create configmap fastapi-dashboard \
  --from-file=fastapi-dashboard.json="$SCRATCH/fastapi-dashboard.json" \
  --dry-run=client -o yaml \
  | kubectl apply -f -
kubectl -n "$NS_MON" label configmap fastapi-dashboard grafana_dashboard=1 --overwrite

step "7. Done"
cat <<EOF

Access UIs with port-forward (in a separate terminal):

  kubectl -n $NS_MON port-forward svc/${RELEASE}-kube-prometheus-stack-prometheus 9090:9090
    http://localhost:9090/targets

  kubectl -n $NS_MON port-forward svc/${RELEASE}-grafana 3000:80
    http://localhost:3000  (admin/admin)  -> "FastAPI Demo"

  kubectl -n $NS_MON port-forward svc/${RELEASE}-kube-prometheus-stack-alertmanager 9093:9093
    http://localhost:9093

Validate with:   bash tests/validate.sh
Teardown with:   bash starter/teardown.sh
EOF
