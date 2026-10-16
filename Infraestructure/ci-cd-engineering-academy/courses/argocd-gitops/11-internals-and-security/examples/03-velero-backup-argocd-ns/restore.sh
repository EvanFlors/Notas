#!/usr/bin/env bash
# Restore the latest backup created by backup.sh.
set -euo pipefail

if ! command -v velero >/dev/null 2>&1; then
  echo "SKIP: velero CLI not installed" >&2
  exit 0
fi

BACKUP="${BACKUP:-$(cat /tmp/argo-11-ex03-last-backup 2>/dev/null || echo '')}"
if [ -z "$BACKUP" ]; then
  echo "ERROR: no backup name. Set BACKUP=... or run backup.sh first." >&2
  exit 1
fi

NAME="restore-$(date +%s)"
echo "== Restoring from backup $BACKUP as $NAME =="
velero restore create "$NAME" --from-backup "$BACKUP" \
  --existing-resource-policy update \
  --wait

echo
velero restore describe "$NAME" --details | sed -n '1,40p'

echo
echo "State after restore:"
kubectl -n argocd get applications 2>/dev/null || true
kubectl -n argocd get cm argocd-cm -o jsonpath='{.data.url}'; echo
