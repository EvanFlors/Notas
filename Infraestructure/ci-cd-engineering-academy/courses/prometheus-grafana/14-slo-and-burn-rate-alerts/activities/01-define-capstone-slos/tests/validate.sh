#!/usr/bin/env bash
# Validate the student's rules.yaml against the solution's test.yaml.
# Student edits `starter/rules.yaml`; we smoke-test it with promtool via Docker.
#
# Note: we intentionally do NOT enable `set -o pipefail` because some checks
# below use `grep -q`, which can trigger SIGPIPE (exit 141) that pipefail would
# misreport as a failure. We rely on explicit `rc` chaining instead.

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ACT_DIR="$(cd "$HERE/.." && pwd)"
PROM_IMAGE="prom/prometheus:v2.54.1"
SCRATCH="/tmp/obs-14-01-$$"

cleanup() { rm -rf "$SCRATCH"; }
trap cleanup EXIT

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker not available"
  exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker daemon not reachable"
  exit 0
fi

STUDENT="$ACT_DIR/starter/rules.yaml"
if [ ! -f "$STUDENT" ]; then
  echo "FAIL: $STUDENT not found"
  exit 1
fi

# Prepare scratch workdir with the student's rules + the shared test fixture.
mkdir -p "$SCRATCH"
cp "$STUDENT" "$SCRATCH/rules.yaml"
cp "$ACT_DIR/solution/test.yaml" "$SCRATCH/test.yaml"

report=""
rc=0

echo "==> promtool check rules"
if docker run --rm --entrypoint promtool -v "$SCRATCH:/w" -w /w "$PROM_IMAGE" \
     check rules rules.yaml; then
  report+="check rules: OK\n"
else
  report+="check rules: FAIL\n"
  rc=1
fi

# Soft smell-check: student must have at least one PAGE alert.
if grep -q "severity: page" "$STUDENT"; then
  report+="page severity present: OK\n"
else
  report+="page severity present: FAIL (no 'severity: page' label)\n"
  rc=1
fi

# Soft smell-check: at least 5 record rules.
record_count="$(grep -c '^      - record:' "$STUDENT" || true)"
if [ "$record_count" -ge 5 ]; then
  report+="ingredient count ($record_count>=5): OK\n"
else
  report+="ingredient count ($record_count<5): FAIL\n"
  rc=1
fi

echo "==> promtool test rules (shared fixture)"
if docker run --rm --entrypoint promtool -v "$SCRATCH:/w" -w /w "$PROM_IMAGE" \
     test rules test.yaml; then
  report+="test rules: OK\n"
else
  report+="test rules: FAIL\n"
  rc=1
fi

echo
echo "----- report -----"
printf "%b" "$report"
echo "------------------"
if [ "$rc" -eq 0 ]; then
  echo "ALL OK"
else
  echo "SOME CHECKS FAILED"
fi
exit "$rc"
