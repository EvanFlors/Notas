#!/usr/bin/env bash
# Solution de referencia para k8s-02-01-create-local-cluster.
# Deliberadamente SIN `set -o pipefail`: algunos checks usan `cmd | grep -q`
# y pipefail puede promover SIGPIPE del upstream a fallo del pipeline.
set -eu

WORK="/tmp/k8s-02-01"
CLUSTER="academy"
NS="k8s-02-lab"

mkdir -p "$WORK"
cd "$WORK"

# 1. Cluster (idempotente: no recrea si ya existe).
if ! kind get clusters | grep -qx "$CLUSTER"; then
  kind create cluster --name "$CLUSTER"
fi

# 2. Namespace (idempotente).
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

# 3. Namespace por default del contexto actual.
kubectl config set-context --current --namespace="$NS"

# 4. ConfigMap declarativo.
cat > "$WORK/configmap.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: lab-config
  labels:
    module: k8s-02
    owner: academy
data:
  greeting: "hola k8s"
  module: "k8s-02"
YAML
kubectl apply -f "$WORK/configmap.yaml"

# 5. Snapshot.
CTX="$(kubectl config current-context)"
CTX_NS="$(kubectl config view --minify -o jsonpath='{.contexts[0].context.namespace}')"
NODE_LINE="$(kubectl get node -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type --no-headers)"
CM_DATA="$(kubectl get cm lab-config -o jsonpath='{.data}')"

cat > "$WORK/snapshot.md" <<EOF
# snapshot k8s-02-01

## current-context
$CTX

## namespace del contexto
$CTX_NS

## nodo
$NODE_LINE

## ConfigMap
$CM_DATA
EOF

echo
echo "Solution aplicada. Correr validator:"
echo "  bash courses/kubernetes/02-setup-local-and-kubectl/activities/01-create-local-cluster/tests/validate.sh"
