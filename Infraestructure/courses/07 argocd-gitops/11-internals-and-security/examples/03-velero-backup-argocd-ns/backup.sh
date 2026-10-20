#!/usr/bin/env bash
# Create a Velero Backup of the argocd namespace + argoproj CRs.
set -euo pipefail

if ! command -v velero >/dev/null 2>&1; then
  echo "SKIP: velero CLI not installed" >&2
  exit 0
fi

NAME="${NAME:-argocd-ns-$(date +%s)}"
echo "== Creating backup $NAME =="
velero backup create "$NAME" \
  --include-namespaces argocd \
  --include-cluster-resources=true \
  --include-resources '*,applications.argoproj.io,appprojects.argoproj.io,applicationsets.argoproj.io' \
  --wait

echo
velero backup describe "$NAME" --details | sed -n '1,40p'
echo
echo "OK: backup '$NAME' completed."
echo "$NAME" > /tmp/argo-11-ex03-last-backup
