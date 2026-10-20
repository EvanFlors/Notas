#!/usr/bin/env bash
# Reference solution for k8s-11-01-why-is-pod-pending.
# Reproduces, investigates, and writes evidence that passes the validator.
# Does NOT "fix" the Pod — the validator requires it to still be Pending.
#
# No `set -o pipefail` on purpose.

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ACT_DIR="$(cd "$HERE/.." && pwd)"
OUT="/tmp/kube-pending"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "SKIP: kubectl not installed." >&2
  exit 0
fi

# 1. Reproduce the broken Pod.
bash "$ACT_DIR/starter/create-pending-pod.sh"

# 2. Wait briefly for the scheduler to emit the FailedScheduling event.
i=0
while [ "$i" -lt 20 ]; do
  if kubectl get events --field-selector involvedObject.name=pending-mystery \
       -o jsonpath='{range .items[*]}{.reason}{"\n"}{end}' 2>/dev/null | grep -qx "FailedScheduling"; then
    break
  fi
  sleep 1
  i=$((i+1))
done

# 3. Capture evidence.
mkdir -p "$OUT"
kubectl describe pod pending-mystery > "$OUT/describe.txt"
kubectl get events --field-selector involvedObject.name=pending-mystery \
  -o wide > "$OUT/events.txt" || true

# 4. Write the ANALYSIS.md that satisfies the validator.
cp "$HERE/analysis.md" "$OUT/ANALYSIS.md"

echo
echo "Evidence in $OUT/:"
ls -la "$OUT"
echo
echo "Run: bash tests/validate.sh"
