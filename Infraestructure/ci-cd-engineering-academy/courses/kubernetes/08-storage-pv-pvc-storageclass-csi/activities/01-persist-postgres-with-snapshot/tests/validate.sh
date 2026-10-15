#!/usr/bin/env bash
# k8s-08-01 — validator.
# Checks:
#   - cluster-side: namespace, PVC Bound, Pod Running, data persisted
#   - static:       snapshot manifests exist and have the right fields
#
# NOTE: deliberately no `set -o pipefail` — several checks use `grep -q`
# which triggers SIGPIPE on upstream (kubectl/yq) and would flag as failure.

set -eu

NS="k8s08-pg"
POD="pg"
PVC="pg-data"
PGPASS="devpass"
EXPECTED_ROW="persisted-by-k8s-08-01"

HERE="$(cd "$(dirname "$0")" && pwd)"
MANIFESTS="$HERE/../starter/manifests"

passed=0
failed=0
report=""

check() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL\n"; failed=$((failed+1))
  fi
}

# ---- Static manifest checks (always runnable) ----

check "File volumesnapshotclass.yaml exists" \
  test -f "$MANIFESTS/volumesnapshotclass.yaml"
check "File volumesnapshot.yaml exists" \
  test -f "$MANIFESTS/volumesnapshot.yaml"
check "File pvc-restored.yaml exists" \
  test -f "$MANIFESTS/pvc-restored.yaml"

# apiVersion / kind sanity on each file.
check "volumesnapshotclass kind=VolumeSnapshotClass" \
  bash -c "grep -E '^kind:[[:space:]]*VolumeSnapshotClass' '$MANIFESTS/volumesnapshotclass.yaml'"
check "volumesnapshotclass apiVersion snapshot.storage.k8s.io/v1" \
  bash -c "grep -E '^apiVersion:[[:space:]]*snapshot.storage.k8s.io/v1' '$MANIFESTS/volumesnapshotclass.yaml'"
check "volumesnapshotclass has driver field" \
  bash -c "grep -E '^driver:' '$MANIFESTS/volumesnapshotclass.yaml'"

check "volumesnapshot kind=VolumeSnapshot" \
  bash -c "grep -E '^kind:[[:space:]]*VolumeSnapshot' '$MANIFESTS/volumesnapshot.yaml'"
check "volumesnapshot references source PVC pg-data" \
  bash -c "grep -E 'persistentVolumeClaimName:[[:space:]]*pg-data' '$MANIFESTS/volumesnapshot.yaml'"
check "volumesnapshot references volumeSnapshotClassName" \
  bash -c "grep -E 'volumeSnapshotClassName:' '$MANIFESTS/volumesnapshot.yaml'"

check "pvc-restored dataSource.kind=VolumeSnapshot" \
  bash -c "grep -E 'kind:[[:space:]]*VolumeSnapshot' '$MANIFESTS/pvc-restored.yaml'"
check "pvc-restored dataSource.apiGroup=snapshot.storage.k8s.io" \
  bash -c "grep -E 'apiGroup:[[:space:]]*snapshot.storage.k8s.io' '$MANIFESTS/pvc-restored.yaml'"
check "pvc-restored dataSource references snapshot pg-snap" \
  bash -c "grep -E 'name:[[:space:]]*pg-snap' '$MANIFESTS/pvc-restored.yaml'"

# ---- Cluster-side checks (skip gracefully if no cluster) ----

if ! command -v kubectl >/dev/null 2>&1; then
  report+="Cluster checks: SKIP (kubectl not installed)\n"
else
  if ! kubectl cluster-info >/dev/null 2>&1; then
    report+="Cluster checks: SKIP (no reachable cluster)\n"
  else
    check "Namespace $NS exists" \
      kubectl get ns "$NS"

    check "PVC $PVC is Bound" \
      bash -c "kubectl -n $NS get pvc $PVC -o jsonpath='{.status.phase}' | grep -qx Bound"

    check "Pod $POD is Running" \
      bash -c "kubectl -n $NS get pod $POD -o jsonpath='{.status.phase}' | grep -qx Running"

    # Expected row persisted.
    row="$(kubectl -n "$NS" exec "$POD" -- sh -c "PGPASSWORD=$PGPASS psql -U postgres -tAc 'SELECT nota FROM marcadores LIMIT 1'" 2>/dev/null || true)"
    if [ "$row" = "$EXPECTED_ROW" ]; then
      report+="Row '$EXPECTED_ROW' present after pod recreation: OK\n"
      passed=$((passed+1))
    else
      report+="Row '$EXPECTED_ROW' present after pod recreation: FAIL (got '$row')\n"
      failed=$((failed+1))
    fi

    # Optional: snapshot runtime, only if CRDs installed.
    if kubectl get crd volumesnapshots.snapshot.storage.k8s.io >/dev/null 2>&1; then
      check "VolumeSnapshot pg-snap exists in cluster" \
        kubectl -n "$NS" get volumesnapshot pg-snap
    else
      report+="VolumeSnapshot runtime: SKIP (CRDs not installed; manifests validated statically)\n"
    fi
  fi
fi

printf "\n==== REPORT ====\n"
printf "%b" "$report"
printf "Passed: %d  Failed: %d\n" "$passed" "$failed"

if [ "$failed" -ne 0 ]; then
  exit 1
fi
exit 0
