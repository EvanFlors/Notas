#!/usr/bin/env bash
# Capstone stage 14 — restore drill. Picks the latest backup, spins a disposable
# postgres in a fresh namespace, restores into it, verifies rows, measures RTO,
# and tears everything down. Never touches the production postgres.
# SKIPs if kubectl or backups are missing.
#
# NOTE: NOT using `set -o pipefail` to avoid SIGPIPE false-positives from pipes.

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="${BACKUP_DIR:-$HERE/../backups}"
DRILL_LOG="$BACKUP_DIR/drill-log.md"
TS="$(date +%Y%m%d-%H%M%S)"
NS="drill-$TS"
DB="${DB:-capstone}"
USER_PG="${USER_PG:-postgres}"
IMAGE="${IMAGE:-postgres:16-alpine}"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "SKIP: kubectl not installed."
  exit 0
fi

LATEST="$(ls -1t "$BACKUP_DIR"/pg-*.sql.gz 2>/dev/null | head -n1 || true)"
if [ -z "$LATEST" ]; then
  echo "SKIP: no backups found under $BACKUP_DIR (run postgres-backup.sh first)."
  exit 0
fi

START=$(date +%s)
echo "== Drill using $LATEST into namespace $NS =="

cleanup() {
  if [ "${KEEP_NS:-0}" = "1" ]; then
    echo "KEEP_NS=1 set; namespace $NS left for forensics."
  else
    kubectl delete ns "$NS" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

kubectl create ns "$NS"

cat <<YAML | kubectl apply -n "$NS" -f -
apiVersion: v1
kind: Pod
metadata:
  name: drill-pg
  labels:
    app: drill-pg
spec:
  restartPolicy: Never
  containers:
    - name: pg
      image: $IMAGE
      env:
        - name: POSTGRES_PASSWORD
          value: dummy-not-a-secret
        - name: POSTGRES_DB
          value: $DB
        - name: POSTGRES_USER
          value: $USER_PG
      ports:
        - containerPort: 5432
YAML

echo "Waiting for drill-pg to be Ready..."
kubectl -n "$NS" wait --for=condition=Ready pod/drill-pg --timeout=120s

echo "Copying backup into pod..."
kubectl -n "$NS" cp "$LATEST" drill-pg:/tmp/backup.sql.gz

echo "Restoring..."
kubectl -n "$NS" exec drill-pg -- bash -c \
  "gunzip -c /tmp/backup.sql.gz | pg_restore --clean --if-exists -U $USER_PG -d $DB" \
  || true  # pg_restore may warn on empty DB; semantic check below

echo "Verifying canonical table 'items' exists and has rows..."
COUNT="$(kubectl -n "$NS" exec drill-pg -- \
  psql -U "$USER_PG" -d "$DB" -tAc \
  "SELECT count(*) FROM items;" 2>/dev/null || echo "ERR")"

END=$(date +%s)
RTO=$(( END - START ))

mkdir -p "$BACKUP_DIR"
touch "$DRILL_LOG"

if [ "$COUNT" = "ERR" ] || [ -z "$COUNT" ]; then
  echo "RESULT: drill FAILED (could not query items)"
  echo "- $TS  backup=$LATEST  rto=${RTO}s  verdict=FAILED  reason=query_error" >> "$DRILL_LOG"
  exit 1
fi

if [ "$COUNT" -lt 1 ]; then
  echo "RESULT: drill FAILED (items table empty after restore)"
  echo "- $TS  backup=$LATEST  rto=${RTO}s  verdict=FAILED  reason=empty_table" >> "$DRILL_LOG"
  exit 1
fi

echo "items has $COUNT row(s); RTO measured = ${RTO}s"
echo "- $TS  backup=$LATEST  rto=${RTO}s  verdict=OK  rows=$COUNT" >> "$DRILL_LOG"
echo "RESULT: drill ok"
