#!/usr/bin/env bash
# Bootstrap kind cluster + scratch dir for k8s-12-02-enforce-signed-images-cluster-wide.
# Idempotent. Does NOT use `set -o pipefail`.
set -eu

BASE="${1:-/tmp/k8s-12-02}"
CLUSTER_NAME="k8s-12-02"

echo "== Preparing scratch dir at $BASE =="
mkdir -p "$BASE/policies"

for bin in kubectl kind; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "ERROR: '$bin' not found in PATH" >&2
    exit 2
  fi
done

echo "== Ensuring kind cluster '$CLUSTER_NAME' =="
if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  echo "Cluster '$CLUSTER_NAME' already exists — reusing."
else
  kind create cluster --name "$CLUSTER_NAME" --wait 90s
fi

kubectl --context "kind-$CLUSTER_NAME" cluster-info >/dev/null

cat <<EOF

Ready.

- Scratch dir: $BASE
- Cluster context: kind-$CLUSTER_NAME
- Next steps:
    1) Install Kyverno:
         kubectl --context kind-$CLUSTER_NAME create -f \\
           https://github.com/kyverno/kyverno/releases/download/v1.12.5/install.yaml
         kubectl --context kind-$CLUSTER_NAME -n kyverno \\
           wait --for=condition=Ready pod --all --timeout=180s
    2) Write $BASE/policies/require-signed-images.yaml
    3) Apply it, then run: bash tests/validate.sh $BASE
EOF
