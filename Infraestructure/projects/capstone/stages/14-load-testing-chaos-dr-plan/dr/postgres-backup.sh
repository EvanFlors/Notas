#!/usr/bin/env bash
# Capstone stage 14 — pg_dump logical backup for the capstone postgres.
# SKIPs if kubectl or the target pod are missing.
#
# NOTE: NOT using `set -o pipefail` to avoid SIGPIPE false-positives from pipes.

set -eu

NAMESPACE="${NAMESPACE:-app}"
POD="${POD:-postgres-0}"
DB="${DB:-capstone}"
USER="${USER_PG:-postgres}"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="${BACKUP_DIR:-$HERE/../backups}"
TS="$(date +%Y%m%d-%H%M%S)"
OUT="$OUT_DIR/pg-$TS.sql.gz"

mkdir -p "$OUT_DIR"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "SKIP: kubectl not installed."
  exit 0
fi

if ! kubectl -n "$NAMESPACE" get pod "$POD" >/dev/null 2>&1; then
  echo "SKIP: pod $NAMESPACE/$POD not found (nothing to back up)."
  exit 0
fi

echo "== pg_dump $NAMESPACE/$POD -> $OUT =="
# Stream the dump out of the pod, compress on the host.
kubectl -n "$NAMESPACE" exec "$POD" -- \
  pg_dump -U "$USER" -Fc "$DB" > "$OUT.tmp"
gzip -c "$OUT.tmp" > "$OUT"
rm -f "$OUT.tmp"

# Integrity check: pg_restore --list must succeed on the archive.
if command -v pg_restore >/dev/null 2>&1; then
  if gunzip -c "$OUT" | pg_restore --list >/dev/null 2>&1; then
    echo "  OK   archive is a valid pg_dump custom-format file"
  else
    echo "  FAIL archive failed pg_restore --list check"
    exit 1
  fi
else
  echo "  NOTE pg_restore not on host; skipping integrity check"
fi

echo "$TS  $OUT  $(wc -c <"$OUT") bytes" >> "$OUT_DIR/backup-log.txt"
echo "RESULT: backup ok -> $OUT"
