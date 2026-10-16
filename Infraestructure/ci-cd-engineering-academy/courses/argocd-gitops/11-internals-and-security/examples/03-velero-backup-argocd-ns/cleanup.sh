#!/usr/bin/env bash
# Uninstall Velero + MinIO and remove scratch.
set -eu

velero uninstall --force 2>/dev/null || true
kubectl delete ns velero --wait=false 2>/dev/null || true
rm -rf /tmp/argo-11-ex03 /tmp/argo-11-ex03-last-backup
echo "OK: cleanup done."
