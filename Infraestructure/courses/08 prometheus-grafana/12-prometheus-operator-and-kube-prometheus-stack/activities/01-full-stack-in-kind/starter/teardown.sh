#!/usr/bin/env bash
# obs-12-01 teardown.
set -u
CLUSTER="${CLUSTER:-obs12}"
SCRATCH="/tmp/obs12-starter"

if command -v kind >/dev/null 2>&1; then
  if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
    kind delete cluster --name "$CLUSTER"
  else
    echo "cluster '$CLUSTER' not present; skipping."
  fi
else
  echo "kind not installed; nothing to delete."
fi

# matar port-forwards huerfanos
pkill -f "port-forward svc/.*kube-prometheus-stack" 2>/dev/null || true
pkill -f "port-forward svc/.*grafana"               2>/dev/null || true

rm -rf "$SCRATCH"
echo "cleanup done."
