#!/usr/bin/env bash
# Validate tf-07-02-fix-count-reindex-drift.
# Checks:
#   1) Refactor done: main.tf uses for_each and does NOT use count.
#   2) Three files alpha.txt, beta.txt, gamma.txt exist in out/ (no numeric prefix).
#   3) Evidence of the problem: plan-count-cascade.txt exists and shows a replace or destroy
#      that is NOT only for the removed element (i.e. mentions alpha or gamma being touched).
#   4) Evidence of the fix: plan-for_each-clean.txt exists and mentions
#      local_file.item["beta"] being destroyed, and does NOT mention alpha or gamma
#      being replaced.
#
# Note: NO `set -o pipefail`. We use `grep -q` in several places; pipefail would
# spuriously fail some pipelines when grep finds a match early and closes the pipe.

BASE="${1:-${BASE_DIR:-/tmp/tf-07-02}}"
passed=0
failed=0
report=""

check() {
  local name="$1" ok="$2" why="$3"
  if [ "$ok" = "1" ]; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL — $why\n"; failed=$((failed+1))
  fi
}

echo "== Validating tf-07-02-fix-count-reindex-drift =="
echo "BASE=$BASE"
echo

if [ ! -d "$BASE" ]; then
  echo "ERROR: $BASE does not exist. Did you copy starter/ there and complete the activity?"
  exit 2
fi

MAIN="$BASE/main.tf"

# 1a. for_each present
if [ -f "$MAIN" ] && grep -q "for_each" "$MAIN"; then
  check "hcl[for_each]" 1 ""
else
  check "hcl[for_each]" 0 "main.tf debe usar for_each"
fi

# 1b. count absent (ignore commented lines)
if [ -f "$MAIN" ] && grep -qE "^[^#]*\bcount\s*=" "$MAIN"; then
  check "hcl[no-count]" 0 "main.tf aún usa count"
else
  check "hcl[no-count]" 1 ""
fi

# 2. Output files with STABLE keys (no "0-alpha" style)
for name in alpha beta gamma; do
  if [ -f "$BASE/out/${name}.txt" ]; then
    check "file[${name}.txt]" 1 ""
  else
    check "file[${name}.txt]" 0 "falta $BASE/out/${name}.txt (filename debe usar each.key, no index)"
  fi
done

# Reject residual numeric-prefixed files (sign of unfinished refactor).
if ls "$BASE/out/" 2>/dev/null | grep -qE "^[0-9]+-"; then
  check "file[no-numeric-prefix]" 0 "quedan archivos con prefijo numérico en out/ (count residual)"
else
  check "file[no-numeric-prefix]" 1 ""
fi

# 3. Evidence of cascade: plan-count-cascade.txt
PCASCADE="$BASE/plan-count-cascade.txt"
if [ -f "$PCASCADE" ]; then
  if grep -qE "(must be replaced|-/\+ resource|will be destroyed)" "$PCASCADE"; then
    check "evidence[plan-count-cascade]" 1 ""
  else
    check "evidence[plan-count-cascade]" 0 "no muestra replace/destroy"
  fi
else
  check "evidence[plan-count-cascade]" 0 "falta $PCASCADE (Fase A)"
fi

# 4. Evidence of clean fix: plan-for_each-clean.txt
PCLEAN="$BASE/plan-for_each-clean.txt"
if [ -f "$PCLEAN" ]; then
  mentions_beta=0
  touches_alpha_or_gamma=0
  grep -q 'local_file.item\["beta"\]' "$PCLEAN" && mentions_beta=1
  if grep -qE 'local_file\.item\["(alpha|gamma)"\].*(must be replaced|will be destroyed|-/\+)' "$PCLEAN"; then
    touches_alpha_or_gamma=1
  fi
  if [ "$mentions_beta" = "1" ] && [ "$touches_alpha_or_gamma" = "0" ]; then
    check "evidence[plan-for_each-clean]" 1 ""
  else
    why=""
    [ "$mentions_beta" = "0" ] && why+=" no menciona local_file.item[\"beta\"];"
    [ "$touches_alpha_or_gamma" = "1" ] && why+=" toca alpha o gamma;"
    check "evidence[plan-for_each-clean]" 0 "$why"
  fi
else
  check "evidence[plan-for_each-clean]" 0 "falta $PCLEAN (Fase B)"
fi

echo
printf "%b" "$report"
echo
echo "== Summary =="
echo "PASS: $passed"
echo "FAIL: $failed"

[ "$failed" -eq 0 ] || exit 1
exit 0
