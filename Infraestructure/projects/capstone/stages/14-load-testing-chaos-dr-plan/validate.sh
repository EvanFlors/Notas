#!/usr/bin/env bash
# Capstone stage 14 — aggregate structural validator.
# Runs every activity's validate.sh and sanity-checks top-level artifacts
# (load, chaos, dr). Does not run live tooling (k6, chaos-mesh, kubectl).
#
# NOTE: NOT using `set -o pipefail` to avoid SIGPIPE false-positives from pipes.

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
fail=0

echo "== Capstone stage 14 — aggregate validation =="

required_files=(
  "README.md"
  "load/k6-script.js"
  "load/run-k6.sh"
  "chaos/pod-kill.yaml"
  "chaos/latency-inject.yaml"
  "chaos/cpu-stress.yaml"
  "chaos/run-experiment.sh"
  "dr/DR-PLAN.md"
  "dr/postgres-backup.sh"
  "dr/postgres-restore-drill.sh"
  "resources/links.md"
)
for rel in "${required_files[@]}"; do
  if [ -f "$HERE/$rel" ]; then
    echo "  OK   $rel"
  else
    echo "  FAIL $rel missing"
    fail=$((fail+1))
  fi
done

# Scripts must be executable.
for s in load/run-k6.sh chaos/run-experiment.sh dr/postgres-backup.sh dr/postgres-restore-drill.sh; do
  if [ -x "$HERE/$s" ]; then
    echo "  OK   $s is executable"
  else
    echo "  FAIL $s is not executable (chmod +x)"
    fail=$((fail+1))
  fi
done

# Shell scripts must use `set -eu` and NOT `set -o pipefail`, with a SIGPIPE
# comment (git-and-github reference convention).
for s in load/run-k6.sh chaos/run-experiment.sh dr/postgres-backup.sh dr/postgres-restore-drill.sh validate.sh; do
  p="$HERE/$s"
  [ -f "$p" ] || continue
  if ! grep -Eq '^set -eu[[:space:]]*$' "$p"; then
    echo "  FAIL $s must use 'set -eu' (without pipefail)"
    fail=$((fail+1))
  fi
  if grep -Eq '^set[[:space:]].*pipefail' "$p"; then
    echo "  FAIL $s must NOT enable pipefail"
    fail=$((fail+1))
  fi
  if ! grep -qi "SIGPIPE" "$p"; then
    echo "  FAIL $s must carry the SIGPIPE comment"
    fail=$((fail+1))
  fi
done

# ANALYSIS.md must not exist anywhere under the stage.
if find "$HERE" -name "ANALYSIS.md" | grep -q .; then
  echo "  FAIL ANALYSIS.md must not exist in the stage"
  fail=$((fail+1))
else
  echo "  OK   no ANALYSIS.md present"
fi

# Each activity must exist with activity.yaml declaring the expected prefix.
for act in 01-k6-smoke-and-soak 02-chaos-mesh-pod-kill-latency-cpu 03-dr-backup-restore-drill; do
  yaml="$HERE/activities/$act/activity.yaml"
  if [ ! -f "$yaml" ]; then
    echo "  FAIL activities/$act/activity.yaml missing"
    fail=$((fail+1))
    continue
  fi
  echo "  OK   activities/$act/activity.yaml exists"
  if grep -Eq "^id:[[:space:]]*cap-14-" "$yaml" \
     && grep -Eq "^technology:[[:space:]]*capstone[[:space:]]*$" "$yaml" \
     && grep -Eq "^module:[[:space:]]*14-load-testing-chaos-dr-plan[[:space:]]*$" "$yaml"; then
    echo "  OK   activities/$act identity fields correct"
  else
    echo "  FAIL activities/$act must declare id=cap-14-*, technology=capstone, module=14-load-testing-chaos-dr-plan"
    fail=$((fail+1))
  fi

  vs="$HERE/activities/$act/tests/validate.sh"
  if [ -x "$vs" ]; then
    echo "  --- running $(basename "$(dirname "$(dirname "$vs")")")/tests/validate.sh"
    if bash "$vs" >/tmp/cap14-sub.$$ 2>&1; then
      echo "    OK   activity validator passed"
    else
      echo "    FAIL activity validator reported issues:"
      sed 's/^/      /' /tmp/cap14-sub.$$
      fail=$((fail+1))
    fi
    rm -f /tmp/cap14-sub.$$
  else
    echo "  FAIL activities/$act/tests/validate.sh missing or not executable"
    fail=$((fail+1))
  fi
done

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail issue(s) found."
  exit 1
fi
echo "RESULT: 0 issue(s). Estructura valida."
exit 0
