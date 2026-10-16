#!/usr/bin/env bash
# Instala External Secrets Operator en el cluster kind via Helm.
#
# Note: we deliberately do NOT enable `set -o pipefail` because some checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
set -eu

CLUSTER=sec-13-capstone
CTX="kind-$CLUSTER"

for tool in helm kubectl kind; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "SKIP: $tool not installed."
    exit 0
  fi
done

if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "SKIP: cluster '$CLUSTER' does not exist. Run ./02-create-cluster.sh first."
  exit 0
fi

echo "== Installing External Secrets Operator via Helm =="
helm repo add external-secrets https://charts.external-secrets.io >/dev/null 2>&1 || true
helm repo update >/dev/null

helm upgrade --install external-secrets external-secrets/external-secrets \
  --kube-context "$CTX" \
  -n external-secrets --create-namespace \
  --set installCRDs=true \
  --wait --timeout=5m

kubectl --context "$CTX" -n external-secrets get pods
