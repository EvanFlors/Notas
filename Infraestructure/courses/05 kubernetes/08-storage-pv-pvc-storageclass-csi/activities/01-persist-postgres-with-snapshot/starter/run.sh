#!/usr/bin/env bash
# k8s-08-01 — starter: build the lab environment.
# Idempotent: safe to re-run after failures.
#
# Note: deliberately NOT using `set -o pipefail`. Several checks use `grep -q`
# which causes SIGPIPE on upstream (kubectl) that would show up as failures.

set -eu

NS="k8s08-pg"
POD="pg"
PVC="pg-data"
PGPASS="devpass"

HERE="$(cd "$(dirname "$0")" && pwd)"
MANIFESTS="$HERE/manifests"

say() { printf "\n== %s ==\n" "$*"; }

require_kubectl() {
  if ! command -v kubectl >/dev/null 2>&1; then
    echo "SKIP: kubectl not installed; this lab requires a Kubernetes cluster."
    exit 0
  fi
  if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "SKIP: no reachable cluster (kubectl cluster-info failed). Start kind: kind create cluster"
    exit 0
  fi
}

wait_pod_ready() {
  local name="$1"
  local tries=120
  local i
  for i in $(seq 1 "$tries"); do
    phase="$(kubectl -n "$NS" get pod "$name" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
    if [ "$phase" = "Running" ]; then
      return 0
    fi
    sleep 2
  done
  echo "ERROR: pod $name never became Running after $((tries*2))s"
  kubectl -n "$NS" describe pod "$name" | tail -40 || true
  return 1
}

wait_pg_ready() {
  local name="$1"
  local tries=90
  local i
  for i in $(seq 1 "$tries"); do
    if kubectl -n "$NS" exec "$name" -- sh -c "PGPASSWORD=$PGPASS psql -U postgres -tAc 'SELECT 1'" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  echo "ERROR: Postgres never accepted connections after $((tries*2))s"
  kubectl -n "$NS" logs --tail=50 "$name" || true
  return 1
}

require_kubectl

say "Step 0: create namespace"
kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create ns "$NS"

say "Step 1: apply PVC"
kubectl apply -f "$MANIFESTS/pvc.yaml"

say "Step 2: apply Pod"
kubectl apply -f "$MANIFESTS/pod.yaml"

say "Step 3: wait for Pod Running"
wait_pod_ready "$POD"

say "Step 4: wait for Postgres accepting psql"
wait_pg_ready "$POD"

say "Step 5: create table + insert marker"
kubectl -n "$NS" exec "$POD" -- sh -c "PGPASSWORD=$PGPASS psql -U postgres -c 'CREATE TABLE IF NOT EXISTS marcadores (nota text);'"
kubectl -n "$NS" exec "$POD" -- sh -c "PGPASSWORD=$PGPASS psql -U postgres -c \"INSERT INTO marcadores VALUES ('persisted-by-k8s-08-01');\""
kubectl -n "$NS" exec "$POD" -- sh -c "PGPASSWORD=$PGPASS psql -U postgres -c 'SELECT nota FROM marcadores;'"

say "Step 6: destroy pod, keep PVC"
kubectl -n "$NS" delete pod "$POD" --wait=true

say "Step 7: recreate pod with same PVC"
kubectl apply -f "$MANIFESTS/pod.yaml"
wait_pod_ready "$POD"
wait_pg_ready "$POD"

say "Step 8: verify data persisted"
kubectl -n "$NS" exec "$POD" -- sh -c "PGPASSWORD=$PGPASS psql -U postgres -tAc 'SELECT nota FROM marcadores;'"

say "Step 9: snapshot manifests"
# Apply snapshot/snapshotclass only if CRDs are installed. Otherwise, inform.
if kubectl get crd volumesnapshots.snapshot.storage.k8s.io >/dev/null 2>&1; then
  say "VolumeSnapshot CRDs present — applying snapshotclass + snapshot"
  kubectl apply -f "$MANIFESTS/volumesnapshotclass.yaml"
  kubectl apply -f "$MANIFESTS/volumesnapshot.yaml"
  echo "(snapshot ReadyToUse depends on driver support; local-path will NOT satisfy it)"
else
  echo "VolumeSnapshot CRDs NOT installed in this cluster."
  echo "The manifests are on disk and will be validated statically by tests/validate.sh:"
  ls -1 "$MANIFESTS"/volumesnapshot*.yaml "$MANIFESTS"/pvc-restored.yaml
fi

say "DONE — now run: bash tests/validate.sh"
