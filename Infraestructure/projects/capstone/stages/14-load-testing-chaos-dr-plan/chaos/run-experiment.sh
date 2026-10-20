#!/usr/bin/env bash
# Capstone stage 14 — apply a chaos-mesh experiment, wait for it to finish,
# then clean it up. SKIPs if kubectl or the chaos-mesh CRDs are missing.
#
# Usage: ./run-experiment.sh pod-kill | latency-inject | cpu-stress
#
# NOTE: NOT using `set -o pipefail` to avoid SIGPIPE false-positives from pipes.

set -eu

SCENARIO="${1:-pod-kill}"
HERE="$(cd "$(dirname "$0")" && pwd)"
FILE="$HERE/${SCENARIO}.yaml"

if [ ! -f "$FILE" ]; then
  echo "ERROR: unknown scenario '$SCENARIO' (expected pod-kill|latency-inject|cpu-stress)"
  exit 2
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "SKIP: kubectl not installed."
  exit 0
fi

if ! kubectl api-resources 2>/dev/null | grep -q chaos-mesh.org; then
  echo "SKIP: chaos-mesh CRDs not registered in the cluster."
  echo "      Install with: helm install chaos-mesh chaos-mesh/chaos-mesh -n chaos-mesh --create-namespace"
  exit 0
fi

echo "== Applying $SCENARIO =="
kubectl apply -f "$FILE"

# Extract duration (e.g. "30s", "1m", "2m") and sleep a little longer.
DUR="$(grep -E '^\s*duration:' "$FILE" | head -n1 | awk -F'"' '{print $2}')"
case "$DUR" in
  *s) SECS="${DUR%s}" ;;
  *m) SECS=$(( ${DUR%m} * 60 )) ;;
  *)  SECS=60 ;;
esac
SECS=$(( SECS + 15 ))

echo "Waiting ${SECS}s for the experiment to finish..."
sleep "$SECS"

echo "== Cleaning up $SCENARIO =="
kubectl delete -f "$FILE" --ignore-not-found
echo "Done."
