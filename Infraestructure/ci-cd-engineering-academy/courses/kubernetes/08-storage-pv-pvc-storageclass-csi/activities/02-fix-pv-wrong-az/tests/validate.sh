#!/usr/bin/env bash
# k8s-08-02 — validator.
# Static-only validator: parses starter/storageclass-bad.yaml and verifies the
# student changed volumeBindingMode to WaitForFirstConsumer and did not leave
# the buggy value behind.
#
# NOTE: deliberately no `set -o pipefail` because the checks below pipe
# `kubectl`/`cat` into `grep -q` and SIGPIPE from an early match would be
# flagged as a false failure.

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
STARTER="$HERE/../starter"
SC="$STARTER/storageclass-bad.yaml"
PVC="$STARTER/pvc.yaml"
DEP="$STARTER/deployment.yaml"

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

# File presence.
check "starter/storageclass-bad.yaml exists" test -f "$SC"
check "starter/pvc.yaml exists"              test -f "$PVC"
check "starter/deployment.yaml exists"       test -f "$DEP"

# Must contain WaitForFirstConsumer.
check "StorageClass has volumeBindingMode: WaitForFirstConsumer" \
  bash -c "grep -E '^[[:space:]]*volumeBindingMode:[[:space:]]*WaitForFirstConsumer[[:space:]]*$' '$SC'"

# Must NOT contain any uncommented Immediate.
# We allow 'Immediate' only inside comments or TODO text.
if grep -E '^[[:space:]]*volumeBindingMode:[[:space:]]*Immediate' "$SC" >/dev/null 2>&1; then
  report+="StorageClass must not keep volumeBindingMode: Immediate: FAIL\n"
  failed=$((failed+1))
else
  report+="StorageClass must not keep volumeBindingMode: Immediate: OK\n"
  passed=$((passed+1))
fi

# PVC still references the StorageClass.
check "PVC references StorageClass zonal-ssd" \
  bash -c "grep -E 'storageClassName:[[:space:]]*zonal-ssd' '$PVC'"

# Deployment still has the nodeSelector (we didn't want the student to delete it).
check "Deployment preserves nodeSelector topology.kubernetes.io/zone" \
  bash -c "grep -E 'topology.kubernetes.io/zone:[[:space:]]*us-east-1c' '$DEP'"

# Reasonable attempt at an explanation: student added a '# fix:' comment line.
if grep -E '^[[:space:]]*#[[:space:]]*fix:' "$SC" >/dev/null 2>&1; then
  report+="Explanation comment '# fix:' present: OK\n"
  passed=$((passed+1))
else
  report+="Explanation comment '# fix:' present: WARN (recommended, not required)\n"
  # don't count as failure
fi

printf "\n==== REPORT ====\n"
printf "%b" "$report"
printf "Passed: %d  Failed: %d\n" "$passed" "$failed"

if [ "$failed" -ne 0 ]; then
  exit 1
fi
exit 0
