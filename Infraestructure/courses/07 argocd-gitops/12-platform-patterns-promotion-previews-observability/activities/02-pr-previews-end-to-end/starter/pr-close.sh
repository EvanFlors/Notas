#!/usr/bin/env bash
# Simulate closing a PR: remove the element from the ApplicationSet List generator,
# wait for Argo CD to prune, then explicitly delete the namespace (cleanup job).
#
# Usage:  ./pr-close.sh 123
#
# Note: no `set -o pipefail` on purpose.
set -eu

PR="${1:?missing PR number}"
HERE="$(cd "$(dirname "$0")" && pwd)"
APPSET="$HERE/appset.yaml"

if ! command -v yq >/dev/null 2>&1; then
  echo "ERROR: yq not found" >&2
  exit 2
fi

yq -i "del(.spec.generators[0].list.elements[] | select(.number == \"$PR\"))" "$APPSET"
kubectl apply -f "$APPSET"
echo "[pr-close] removed element number=$PR from ApplicationSet"

echo "[pr-close] waiting for Application preview-pr-$PR to disappear"
for i in $(seq 1 30); do
  if ! kubectl -n argocd get application "preview-pr-$PR" >/dev/null 2>&1; then
    echo "[pr-close] Application gone"
    break
  fi
  sleep 2
done

# Explicit namespace cleanup (what a real CronJob would do).
if kubectl get ns "pr-$PR" >/dev/null 2>&1; then
  kubectl delete ns "pr-$PR" --wait=false
  echo "[pr-close] namespace pr-$PR delete requested"
else
  echo "[pr-close] namespace pr-$PR already gone"
fi

echo "[pr-close] done"
