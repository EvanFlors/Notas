#!/usr/bin/env bash
# Validate: student diagnosed the Pending Pod and wrote the analysis.
#
# No `set -o pipefail` on purpose: downstream `grep -q` with pipes can
# produce SIGPIPE (141) that pipefail would mark as failure.

set -eu

OUT="/tmp/kube-pending"
fail=0

echo "== Validating k8s-11-01-why-is-pod-pending =="

if ! command -v kubectl >/dev/null 2>&1; then
  echo "SKIP: kubectl not installed."
  exit 0
fi

if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "SKIP: no reachable Kubernetes cluster (kubectl cluster-info failed)."
  echo "      Run 'bash starter/create-pending-pod.sh' first."
  exit 0
fi

# Pod must exist and must still be Pending (student should not "fix" before documenting).
if ! kubectl get pod pending-mystery >/dev/null 2>&1; then
  echo "  FAIL pod 'pending-mystery' does not exist. Did you run starter/create-pending-pod.sh?"
  exit 1
fi

phase="$(kubectl get pod pending-mystery -o jsonpath='{.status.phase}' 2>/dev/null)"
if [ "$phase" = "Pending" ]; then
  echo "  OK   pod phase is Pending"
else
  echo "  FAIL pod phase is '$phase' (expected Pending — do not fix before documenting)"
  fail=$((fail+1))
fi

# Scheduler must have emitted a FailedScheduling event.
events="$(kubectl get events --field-selector involvedObject.name=pending-mystery \
  -o jsonpath='{range .items[*]}{.reason}{"\n"}{end}' 2>/dev/null || echo "")"
if echo "$events" | grep -qx "FailedScheduling"; then
  echo "  OK   FailedScheduling event present"
else
  echo "  WARN no FailedScheduling event yet; scheduler may still be catching up. Re-run in 30s."
fi

# Evidence files.
if [ -f "$OUT/describe.txt" ]; then
  echo "  OK   $OUT/describe.txt captured"
else
  echo "  FAIL $OUT/describe.txt missing (kubectl describe pod pending-mystery > $OUT/describe.txt)"
  fail=$((fail+1))
fi

if [ -f "$OUT/events.txt" ]; then
  echo "  OK   $OUT/events.txt captured"
else
  echo "  FAIL $OUT/events.txt missing"
  fail=$((fail+1))
fi

# ANALYSIS.md with required phrases.
if [ -f "$OUT/ANALYSIS.md" ]; then
  echo "  OK   $OUT/ANALYSIS.md present"
  rc="$OUT/ANALYSIS.md"
  missing=""
  for phrase in "Pending" "FailedScheduling" "nodeSelector" "NodeAffinity" "kube-scheduler"; do
    if grep -qiF "$phrase" "$rc"; then
      echo "       - mentions: $phrase"
    else
      missing="$missing \"$phrase\""
    fi
  done
  if [ -n "$missing" ]; then
    echo "  FAIL ANALYSIS.md missing required phrases:$missing"
    fail=$((fail+1))
  fi
else
  echo "  FAIL $OUT/ANALYSIS.md missing — write the root-cause analysis"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: k8s-11-01 completed."
exit 0
