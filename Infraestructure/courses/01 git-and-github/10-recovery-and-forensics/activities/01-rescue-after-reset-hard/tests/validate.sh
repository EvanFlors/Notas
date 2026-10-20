#!/usr/bin/env bash
# Validate the 3 recovery scenarios of gh-10-01-rescue-after-reset-hard.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks use
# `git log ... | grep -qx ...` which produces SIGPIPE (exit 141) on git when
# grep finds a match early. pipefail would spuriously mark those as failures.

BASE="${1:-${BASE_DIR:-/tmp/recover-adv}}"
passed=0
failed=0
report=""

check_scenario_1() {
  local repo="$BASE/scenario-1"
  local name="Scenario 1 (reflog + reset to restore main)"
  if [ ! -d "$repo/.git" ]; then
    report+="$name: FAIL (repo missing)\n"; failed=$((failed+1)); return
  fi
  cd "$repo"

  # Must be on main (not detached, not other)
  local head_ref
  head_ref="$(git symbolic-ref --quiet HEAD || echo DETACHED)"

  local has1 has2 has3
  has1="$(git log main --format='%s' 2>/dev/null | grep -x 'feat: step 1' || true)"
  has2="$(git log main --format='%s' 2>/dev/null | grep -x 'feat: step 2' || true)"
  has3="$(git log main --format='%s' 2>/dev/null | grep -x 'feat: step 3' || true)"

  if [ "$head_ref" = "refs/heads/main" ] && [ -n "$has1" ] && [ -n "$has2" ] && [ -n "$has3" ]; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    local why=""
    [ "$head_ref" != "refs/heads/main" ] && why+=" HEAD no está en main ($head_ref);"
    [ -z "$has1" ] && why+=" falta 'feat: step 1' en main;"
    [ -z "$has2" ] && why+=" falta 'feat: step 2' en main;"
    [ -z "$has3" ] && why+=" falta 'feat: step 3' en main;"
    report+="$name: FAIL —$why\n"
    failed=$((failed+1))
  fi
}

check_scenario_2() {
  local repo="$BASE/scenario-2"
  local name="Scenario 2 (recreate deleted branch from HEAD reflog)"
  if [ ! -d "$repo/.git" ]; then
    report+="$name: FAIL (repo missing)\n"; failed=$((failed+1)); return
  fi
  cd "$repo"

  local exists tip_subj has_module has_test
  exists=0
  if git show-ref --verify --quiet refs/heads/feature/payments; then
    exists=1
    tip_subj="$(git log -1 --format='%s' feature/payments 2>/dev/null || true)"
    has_module="$(git log feature/payments --format='%s' | grep -x 'feat: add payments module' || true)"
    has_test="$(git log feature/payments --format='%s' | grep -x 'test: payments happy path' || true)"
  fi

  if [ "$exists" -eq 1 ] && [ "$tip_subj" = "fix: payments edge case" ] \
     && [ -n "$has_module" ] && [ -n "$has_test" ]; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    local why=""
    [ "$exists" -ne 1 ] && why+=" rama feature/payments no existe;"
    [ "$exists" -eq 1 ] && [ "$tip_subj" != "fix: payments edge case" ] \
      && why+=" tip es '$tip_subj' (esperado 'fix: payments edge case');"
    [ -z "$has_module" ] && why+=" falta 'feat: add payments module' en la rama;"
    [ -z "$has_test" ] && why+=" falta 'test: payments happy path' en la rama;"
    report+="$name: FAIL —$why\n"
    failed=$((failed+1))
  fi
}

check_scenario_3() {
  local repo="$BASE/scenario-3"
  local name="Scenario 3 (fsck lost-found + apply recovered stash)"
  if [ ! -d "$repo/.git" ]; then
    report+="$name: FAIL (repo missing)\n"; failed=$((failed+1)); return
  fi
  cd "$repo"

  # 1) main must contain the rescue commit with the exact subject.
  local has_rescue
  has_rescue="$(git log main --format='%s' | grep -x 'rescue: apply recovered CRITICAL_FIX_MARKER' || true)"

  # 2) app.py at HEAD must contain the marker.
  local has_marker=0
  if git show main:app.py 2>/dev/null | grep -q 'CRITICAL_FIX_MARKER'; then
    has_marker=1
  fi

  # 3) Working tree clean.
  local clean=0
  [ -z "$(git status --porcelain)" ] && clean=1

  if [ -n "$has_rescue" ] && [ "$has_marker" -eq 1 ] && [ "$clean" -eq 1 ]; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    local why=""
    [ -z "$has_rescue" ] && why+=" falta commit 'rescue: apply recovered CRITICAL_FIX_MARKER' en main;"
    [ "$has_marker" -ne 1 ] && why+=" app.py en HEAD no contiene CRITICAL_FIX_MARKER;"
    [ "$clean" -ne 1 ] && why+=" working tree no está limpio;"
    report+="$name: FAIL —$why\n"
    failed=$((failed+1))
  fi
}

echo "== Validating 3 scenarios under $BASE =="

if [ ! -d "$BASE/scenario-1/.git" ] && [ ! -d "$BASE/scenario-2/.git" ] \
   && [ ! -d "$BASE/scenario-3/.git" ]; then
  echo "FAIL: no scenarios found under $BASE. Run starter/build-broken-repos.sh first."
  exit 1
fi

check_scenario_1
check_scenario_2
check_scenario_3

echo
printf "%b" "$report"
echo
echo "RESULT: $passed/3 scenarios OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
