#!/usr/bin/env bash
# Validate k8s-17-01-backup-and-restore-cluster.
#
# NOTE: we deliberately do NOT enable `set -o pipefail` because several
# checks pipe into `grep -q`, and grep closing the pipe early produces
# SIGPIPE (141) on the upstream, which pipefail would misreport as a
# failure. We check individual command exit codes explicitly.

CLUSTER_NAME="${CLUSTER_NAME:-k8s-17-lab}"
MINIO_NS="${MINIO_NS:-minio}"
VELERO_NS="${VELERO_NS:-velero}"
DEMO_NS="${DEMO_NS:-demo}"
BACKUP_NAME="${BACKUP_NAME:-demo-backup}"
EXPECTED_PAYLOAD="${EXPECTED_PAYLOAD:-RESTORED-OK}"

pass=0
fail=0
report=""

ok() { report+="  OK   $1\n"; pass=$((pass+1)); }
ko() { report+="  FAIL $1\n"; fail=$((fail+1)); }

echo "== Validating k8s-17-01 on context kind-$CLUSTER_NAME =="

# 0. kubectl + context
if ! kubectl config get-contexts "kind-$CLUSTER_NAME" >/dev/null 2>&1; then
  echo "FATAL: kube context 'kind-$CLUSTER_NAME' not found. Did you create the cluster?"
  exit 2
fi
kubectl config use-context "kind-$CLUSTER_NAME" >/dev/null

# 1. namespaces
for ns in "$MINIO_NS" "$VELERO_NS" "$DEMO_NS"; do
  phase="$(kubectl get ns "$ns" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  if [ "$phase" = "Active" ]; then
    ok "namespace $ns Active"
  else
    ko "namespace $ns missing or not Active (got '$phase')"
  fi
done

# 2. MinIO Deployment Ready
ready="$(kubectl -n "$MINIO_NS" get deploy minio -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
if [ "${ready:-0}" -ge 1 ]; then
  ok "minio Deployment ready ($ready)"
else
  ko "minio Deployment not ready"
fi

# 3. Velero Deployment Ready
ready="$(kubectl -n "$VELERO_NS" get deploy velero -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
if [ "${ready:-0}" -ge 1 ]; then
  ok "velero Deployment ready ($ready)"
else
  ko "velero Deployment not ready"
fi

# 4. node-agent DaemonSet Ready
dsready="$(kubectl -n "$VELERO_NS" get daemonset node-agent -o jsonpath='{.status.numberReady}' 2>/dev/null || echo 0)"
if [ "${dsready:-0}" -ge 1 ]; then
  ok "velero node-agent DaemonSet ready ($dsready)"
else
  ko "velero node-agent DaemonSet not ready (did you pass --use-node-agent?)"
fi

# 5. BackupStorageLocation Available
bslphase="$(kubectl -n "$VELERO_NS" get backupstoragelocation default -o jsonpath='{.status.phase}' 2>/dev/null || true)"
if [ "$bslphase" = "Available" ]; then
  ok "BackupStorageLocation default is Available"
else
  ko "BackupStorageLocation default phase='$bslphase' (expected Available)"
fi

# 6. Backup Completed
bphase="$(kubectl -n "$VELERO_NS" get backup "$BACKUP_NAME" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
if [ "$bphase" = "Completed" ]; then
  ok "Backup $BACKUP_NAME phase=Completed"
else
  ko "Backup $BACKUP_NAME phase='$bphase' (expected Completed)"
fi

# 7. At least one Restore from that backup Completed
restore_phases="$(kubectl -n "$VELERO_NS" get restore \
    -o jsonpath='{range .items[?(@.spec.backupName=="'"$BACKUP_NAME"'")]}{.status.phase}{"\n"}{end}' \
    2>/dev/null || true)"
if echo "$restore_phases" | grep -qx "Completed"; then
  ok "At least one Restore from $BACKUP_NAME is Completed"
elif echo "$restore_phases" | grep -qx "PartiallyFailed"; then
  ok "A Restore from $BACKUP_NAME is PartiallyFailed (acceptable with reasons)"
else
  ko "No Completed Restore from $BACKUP_NAME found (phases seen: '$(echo "$restore_phases" | tr '\n' ',' )')"
fi

# 8. Deployment writer in demo Ready
wready="$(kubectl -n "$DEMO_NS" get deploy writer -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
if [ "${wready:-0}" -ge 1 ]; then
  ok "writer Deployment in $DEMO_NS is Ready"
else
  ko "writer Deployment in $DEMO_NS not Ready"
fi

# 9. PVC data Bound
pvcphase="$(kubectl -n "$DEMO_NS" get pvc data -o jsonpath='{.status.phase}' 2>/dev/null || true)"
if [ "$pvcphase" = "Bound" ]; then
  ok "PVC data Bound"
else
  ko "PVC data phase='$pvcphase' (expected Bound)"
fi

# 10. Payload contents preserved (critical check — proves file-system backup worked)
payload="$(kubectl -n "$DEMO_NS" exec deploy/writer -- cat /data/payload.txt 2>/dev/null | tr -d '\r\n' || true)"
if [ "$payload" = "$EXPECTED_PAYLOAD" ]; then
  ok "Payload in /data/payload.txt is '$EXPECTED_PAYLOAD' (restore preserved data)"
else
  ko "Payload mismatch: got '$payload', expected '$EXPECTED_PAYLOAD'"
fi

echo
printf "%b" "$report"
echo
echo "SUMMARY: $pass passed, $fail failed."

if [ "$fail" -gt 0 ]; then
  exit 1
fi
echo "OK: actividad completada correctamente."
exit 0
