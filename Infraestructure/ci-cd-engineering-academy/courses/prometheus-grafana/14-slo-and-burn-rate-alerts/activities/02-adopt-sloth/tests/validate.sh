#!/usr/bin/env bash
# Validate the student's slo.yaml by running `sloth generate` and `promtool check rules`.
#
# Note: we intentionally do NOT enable `set -o pipefail` because some checks
# below use `grep -q`, which can hit SIGPIPE (exit 141) that pipefail would
# misreport as failure.

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ACT_DIR="$(cd "$HERE/.." && pwd)"
SLOTH_IMAGE="ghcr.io/slok/sloth:v0.11.0"
PROM_IMAGE="prom/prometheus:v2.54.1"
SCRATCH="/tmp/obs-14-02-$$"

cleanup() { rm -rf "$SCRATCH"; }
trap cleanup EXIT

STUDENT="$ACT_DIR/starter/slo.yaml"
if [ ! -f "$STUDENT" ]; then
  echo "FAIL: $STUDENT not found"
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker not available"
  exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker daemon not reachable"
  exit 0
fi

mkdir -p "$SCRATCH"
cp "$STUDENT" "$SCRATCH/slo.yaml"

report=""
rc=0

# Soft smell-check: the SLO list must not be empty.
if grep -q "^slos: \[\]" "$STUDENT"; then
  report+="slos not empty: FAIL (slo list is still '[]')\n"
  rc=1
else
  report+="slos not empty: OK\n"
fi

# Soft smell-check: must declare a page_alert.
if grep -q "page_alert" "$STUDENT"; then
  report+="page_alert declared: OK\n"
else
  report+="page_alert declared: FAIL\n"
  rc=1
fi

echo "==> sloth generate"
if docker run --rm -v "$SCRATCH:/w" -w /w "$SLOTH_IMAGE" \
     generate -i slo.yaml -o generated-rules.yaml; then
  report+="sloth generate: OK\n"
else
  report+="sloth generate: FAIL\n"
  rc=1
fi

if [ -f "$SCRATCH/generated-rules.yaml" ]; then
  echo "==> promtool check rules"
  if docker run --rm --entrypoint promtool -v "$SCRATCH:/w" -w /w "$PROM_IMAGE" \
       check rules generated-rules.yaml; then
    report+="promtool check rules: OK\n"
  else
    report+="promtool check rules: FAIL\n"
    rc=1
  fi
else
  report+="generated-rules.yaml missing: FAIL\n"
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
