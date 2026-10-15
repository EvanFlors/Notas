#!/usr/bin/env bash
# k8s-08-01 — cleanup.
# Note: no `set -o pipefail` by convention of this course.

set -eu

NS="k8s08-pg"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "SKIP: kubectl not installed, nothing to clean."
  exit 0
fi
if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "SKIP: no reachable cluster."
  exit 0
fi

echo "Deleting namespace $NS (cascades to PVC, Pod, VolumeSnapshot)..."
kubectl delete namespace "$NS" --ignore-not-found --wait=true
echo "Done."
