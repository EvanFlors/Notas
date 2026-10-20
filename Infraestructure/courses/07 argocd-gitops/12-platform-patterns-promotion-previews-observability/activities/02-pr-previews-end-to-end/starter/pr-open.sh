#!/usr/bin/env bash
# Simulate opening a PR of the given number: add the element to the ApplicationSet
# List generator and apply a ResourceQuota to the preview namespace.
#
# Usage:  ./pr-open.sh 123
#
# Note: no `set -o pipefail` on purpose (grep -q in checks closes upstream).
set -eu

PR="${1:?missing PR number}"
HERE="$(cd "$(dirname "$0")" && pwd)"
APPSET="$HERE/appset.yaml"

if ! command -v yq >/dev/null 2>&1; then
  echo "ERROR: yq not found" >&2
  exit 2
fi

# Add { number: "<PR>" } to .spec.generators[0].list.elements if not already there.
EXISTS=$(yq ".spec.generators[0].list.elements[] | select(.number == \"$PR\") | .number" "$APPSET" || true)
if [ -z "$EXISTS" ]; then
  yq -i ".spec.generators[0].list.elements += [{\"number\": \"$PR\"}]" "$APPSET"
  echo "[pr-open] added element number=$PR to $APPSET"
else
  echo "[pr-open] element number=$PR already present"
fi

kubectl apply -f "$APPSET"

# Wait for the Application to appear, then for namespace to exist (CreateNamespace=true creates it).
echo "[pr-open] waiting for Application preview-pr-$PR to appear"
for i in $(seq 1 30); do
  if kubectl -n argocd get application "preview-pr-$PR" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

echo "[pr-open] waiting for namespace pr-$PR to be created"
for i in $(seq 1 30); do
  if kubectl get ns "pr-$PR" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

# Apply ResourceQuota to the preview namespace (part of the lab contract).
if kubectl get ns "pr-$PR" >/dev/null 2>&1; then
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: preview-quota
  namespace: pr-$PR
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 4Gi
    pods: "20"
EOF
  echo "[pr-open] ResourceQuota applied in pr-$PR"
else
  echo "[pr-open] WARN: namespace pr-$PR did not appear in time; quota not applied"
fi

echo "[pr-open] done. Check with:  kubectl get ns,application -A | grep -E 'pr-$PR|preview-pr-$PR'"
