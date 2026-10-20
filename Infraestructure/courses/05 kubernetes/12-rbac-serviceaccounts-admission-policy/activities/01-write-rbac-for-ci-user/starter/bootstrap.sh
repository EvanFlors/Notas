#!/usr/bin/env bash
# Bootstrap kind cluster + scratch dir for k8s-12-01-write-rbac-for-ci-user.
# Idempotent. Does NOT use `set -o pipefail` to avoid false negatives from
# grep -q against long producers.
set -eu

BASE="${1:-/tmp/k8s-12-01}"
CLUSTER_NAME="k8s-12-01"

echo "== Preparing scratch dir at $BASE =="
mkdir -p "$BASE/manifests"

# Preconditions
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

cat > "$BASE/manifests/.gitkeep" <<'EOF'
# Place your apps-rbac.yaml and apps-rbac.md here.
EOF

cat <<EOF

Ready.

- Scratch dir: $BASE
- Cluster context: kind-$CLUSTER_NAME
- Next: write $BASE/manifests/apps-rbac.yaml and $BASE/manifests/apps-rbac.md
        then run: bash tests/validate.sh $BASE
EOF
