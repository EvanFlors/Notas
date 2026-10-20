#!/usr/bin/env bash
# Validate the 3 OutOfSync diagnostic scenarios of argo-03-02.
# Each scenario is independent; a short per-scenario report is printed and
# the exit code is non-zero if any scenario still fails.
#
# Note: `set -o pipefail` deliberately NOT enabled; several checks use grep -q
# on piped output and pipefail would mark SIGPIPE from the producer as a failure.

BASE="${1:-${BASE_DIR:-/tmp/argo-03-02}}"
passed=0
failed=0
report=""

echo "== Validating 3 scenarios under $BASE =="

if [ ! -d "$BASE/scenario-a" ] && [ ! -d "$BASE/scenario-b" ] && [ ! -d "$BASE/scenario-c" ]; then
  echo "FAIL: no scenarios found under $BASE. Run starter/build-scenarios.sh first."
  exit 1
fi

report_filled_ok() {
  # $1 = path to report.md. Returns 0 if there is no TODO and at least a
  # non-empty "Causa raíz" line follows that header.
  local f="$1"
  if [ ! -f "$f" ]; then return 1; fi
  if grep -q 'TODO' "$f"; then return 1; fi
  # Any non-empty, non-header line after "## Causa raíz" header counts.
  awk '
    /^## Causa raíz/{inroot=1; next}
    inroot && /^##/{inroot=0}
    inroot && NF>0 {found=1}
    END{exit (found?0:1)}
  ' "$f"
}

check_scenario_a() {
  local dir="$BASE/scenario-a"
  local name="Scenario A (moving targetRevision)"
  if [ ! -f "$dir/application.yaml" ]; then
    report+="$name: FAIL (missing application.yaml)\n"; failed=$((failed+1)); return
  fi

  local tr
  tr="$(grep -E '^    targetRevision: ' "$dir/application.yaml" | head -n1 | sed 's/^    targetRevision: //')"
  local tr_ok=0
  if [ -n "$tr" ] && [ "$tr" != "HEAD" ]; then
    tr_ok=1
  fi

  local report_ok=0
  if report_filled_ok "$dir/report.md"; then report_ok=1; fi

  if [ "$tr_ok" -eq 1 ] && [ "$report_ok" -eq 1 ]; then
    report+="$name: OK (targetRevision=$tr, report completed)\n"
    passed=$((passed+1))
  else
    local why=""
    [ "$tr_ok" -ne 1 ]     && why+=" targetRevision sigue en HEAD o vacío;"
    [ "$report_ok" -ne 1 ] && why+=" report.md incompleto (TODO o sin causa raíz);"
    report+="$name: FAIL —$why\n"
    failed=$((failed+1))
  fi
}

check_scenario_b() {
  local dir="$BASE/scenario-b"
  local name="Scenario B (HPA mutating replicas)"
  if [ ! -f "$dir/application.yaml" ]; then
    report+="$name: FAIL (missing application.yaml)\n"; failed=$((failed+1)); return
  fi

  local has_ignore=0 has_respect=0 has_jsonptr=0
  if grep -q '^  ignoreDifferences:' "$dir/application.yaml"; then has_ignore=1; fi
  if grep -q 'RespectIgnoreDifferences=true' "$dir/application.yaml"; then has_respect=1; fi
  if grep -q '/spec/replicas' "$dir/application.yaml"; then has_jsonptr=1; fi

  local report_ok=0
  if report_filled_ok "$dir/report.md"; then report_ok=1; fi

  if [ "$has_ignore" -eq 1 ] && [ "$has_respect" -eq 1 ] && [ "$has_jsonptr" -eq 1 ] && [ "$report_ok" -eq 1 ]; then
    report+="$name: OK (ignoreDifferences+/spec/replicas+RespectIgnoreDifferences=true, report completed)\n"
    passed=$((passed+1))
  else
    local why=""
    [ "$has_ignore"  -ne 1 ] && why+=" falta bloque ignoreDifferences;"
    [ "$has_jsonptr" -ne 1 ] && why+=" falta /spec/replicas en ignoreDifferences;"
    [ "$has_respect" -ne 1 ] && why+=" falta RespectIgnoreDifferences=true en syncOptions;"
    [ "$report_ok"   -ne 1 ] && why+=" report.md incompleto (TODO o sin causa raíz);"
    report+="$name: FAIL —$why\n"
    failed=$((failed+1))
  fi
}

check_scenario_c() {
  local dir="$BASE/scenario-c"
  local name="Scenario C (manual kubectl edit)"
  if [ ! -f "$dir/desired-in-git.yaml" ] || [ ! -f "$dir/live-in-cluster.yaml" ]; then
    report+="$name: FAIL (missing desired/live yaml)\n"; failed=$((failed+1)); return
  fi

  # The student must reconcile desired and live by choosing one direction.
  # We check that LOG_LEVEL values match now.
  local lvl_desired lvl_live
  lvl_desired="$(grep -A1 'name: LOG_LEVEL' "$dir/desired-in-git.yaml" | awk '/value:/{print $2; exit}')"
  lvl_live="$(grep -A1    'name: LOG_LEVEL' "$dir/live-in-cluster.yaml" | awk '/value:/{print $2; exit}')"

  local reconciled=0
  if [ -n "$lvl_desired" ] && [ "$lvl_desired" = "$lvl_live" ]; then
    reconciled=1
  fi

  local report_ok=0
  if report_filled_ok "$dir/report.md"; then report_ok=1; fi

  if [ "$reconciled" -eq 1 ] && [ "$report_ok" -eq 1 ]; then
    report+="$name: OK (LOG_LEVEL alineado en desired=live=$lvl_desired, report completed)\n"
    passed=$((passed+1))
  else
    local why=""
    [ "$reconciled" -ne 1 ] && why+=" LOG_LEVEL difiere (desired='$lvl_desired' vs live='$lvl_live');"
    [ "$report_ok"  -ne 1 ] && why+=" report.md incompleto (TODO o sin causa raíz);"
    report+="$name: FAIL —$why\n"
    failed=$((failed+1))
  fi
}

check_scenario_a
check_scenario_b
check_scenario_c

echo
printf "%b" "$report"
echo
echo "RESULT: $passed/3 scenarios OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
