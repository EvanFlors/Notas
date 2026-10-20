#!/usr/bin/env bash
# Structural validator for cap-14-03-dr-backup-restore-drill.
#
# NOTE: NOT using `set -o pipefail` to avoid SIGPIPE false-positives from pipes.

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ACT="$(cd "$HERE/.." && pwd)"
STAGE="$(cd "$ACT/../.." && pwd)"
fail=0

echo "== Validating cap-14-03-dr-backup-restore-drill =="

check_exec() {
  if [ -x "$1" ]; then
    echo "  OK   $1 is executable"
  else
    echo "  FAIL $1 is not executable (chmod +x)"
    fail=$((fail+1))
  fi
}

for f in "$STAGE/dr/postgres-backup.sh" "$STAGE/dr/postgres-restore-drill.sh"; do
  if [ ! -f "$f" ]; then
    echo "  FAIL $f missing"
    fail=$((fail+1))
    continue
  fi
  echo "  OK   $f exists"
  check_exec "$f"
  if grep -q "SKIP" "$f"; then
    echo "  OK   $f has SKIP branch"
  else
    echo "  FAIL $f must SKIP when kubectl/backups missing"
    fail=$((fail+1))
  fi
done

if [ -f "$STAGE/dr/DR-PLAN.md" ]; then
  echo "  OK   dr/DR-PLAN.md exists"
  for section in "Alcance" "Targets" "Procedimiento" "Owners"; do
    if grep -Eq "^##[[:space:]]+[0-9]*\.?[[:space:]]*${section}" "$STAGE/dr/DR-PLAN.md"; then
      echo "  OK   DR-PLAN.md section mentions '$section'"
    else
      echo "  FAIL DR-PLAN.md missing section '$section'"
      fail=$((fail+1))
    fi
  done
  if grep -Eq "RTO" "$STAGE/dr/DR-PLAN.md" && grep -Eq "RPO" "$STAGE/dr/DR-PLAN.md"; then
    echo "  OK   DR-PLAN.md mentions RTO and RPO"
  else
    echo "  FAIL DR-PLAN.md must declare RTO and RPO"
    fail=$((fail+1))
  fi
else
  echo "  FAIL dr/DR-PLAN.md missing"
  fail=$((fail+1))
fi

REPORT=""
for cand in "$ACT/drill-report.md" "$ACT/starter/drill-report.md"; do
  if [ -f "$cand" ]; then REPORT="$cand"; break; fi
done
if [ -z "$REPORT" ]; then
  echo "  FAIL drill-report.md missing"
  fail=$((fail+1))
else
  echo "  OK   drill-report.md at $REPORT"
  for section in "Resultado" "Comparacion vs DR-PLAN"; do
    if grep -Eq "^##[[:space:]]+${section}" "$REPORT"; then
      echo "  OK   drill-report.md has '## $section'"
    else
      echo "  FAIL drill-report.md missing '## $section'"
      fail=$((fail+1))
    fi
  done
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail issue(s) found."
  exit 1
fi
echo "RESULT: 0 issue(s). Estructura valida."
exit 0
