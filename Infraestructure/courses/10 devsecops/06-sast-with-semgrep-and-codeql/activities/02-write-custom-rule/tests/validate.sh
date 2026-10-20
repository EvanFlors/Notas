#!/usr/bin/env bash
# Structural validation for sec-06-02-write-custom-rule.
#
# Note: we deliberately do NOT enable `set -o pipefail` because some checks use
# `... | grep -q ...` which produces SIGPIPE (exit 141) when grep finds a match
# early. pipefail would spuriously mark those as failures.
set -eu

BASE="${1:-/tmp/sec-06-02-custom-rule}"
pass=0
fail=0
skip=0

say_ok()   { echo "  OK   $*"; pass=$((pass+1)); }
say_fail() { echo "  FAIL $*"; fail=$((fail+1)); }
say_skip() { echo "  SKIP $*"; skip=$((skip+1)); }

echo "== Structural validation for $BASE =="

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE does not exist. Create it per the activity README."
  exit 1
fi

RULE="$BASE/.semgrep/no-requests-without-timeout.yml"
FIX="$BASE/.semgrep/no-requests-without-timeout.test.py"
TPL="$BASE/TEMPLATE.md"

# 1) Rule file.
if [ -f "$RULE" ]; then
  say_ok ".semgrep/no-requests-without-timeout.yml exists"
  grep -q "id: *no-requests-without-timeout" "$RULE" \
    && say_ok "rule id matches" \
    || say_fail "rule id does not match 'no-requests-without-timeout'"
  grep -q "languages:" "$RULE" && grep -q "python" "$RULE" \
    && say_ok "rule declares python" \
    || say_fail "rule missing 'languages: [python]'"
  grep -qE "severity: *(ERROR|WARNING)" "$RULE" \
    && say_ok "rule has severity ERROR or WARNING" \
    || say_fail "rule missing severity"
  grep -qi "timeout" "$RULE" \
    && say_ok "rule mentions 'timeout' in message/pattern" \
    || say_fail "rule does not mention 'timeout'"
  grep -q "owner" "$RULE" \
    && say_ok "rule has metadata.owner" \
    || say_fail "rule missing 'owner' in metadata"
else
  say_fail "rule file missing"
fi

# 2) Fixture file.
if [ -f "$FIX" ]; then
  say_ok "fixture file exists"
  ruleid_count=$(grep -c "ruleid: *no-requests-without-timeout" "$FIX" || true)
  ok_count=$(grep -c "ok: *no-requests-without-timeout" "$FIX" || true)
  if [ "$ruleid_count" -ge 3 ]; then
    say_ok "fixture has >=3 ruleid lines ($ruleid_count)"
  else
    say_fail "fixture has $ruleid_count ruleid lines (expected >=3)"
  fi
  if [ "$ok_count" -ge 3 ]; then
    say_ok "fixture has >=3 ok lines ($ok_count)"
  else
    say_fail "fixture has $ok_count ok lines (expected >=3)"
  fi
  verbs=0
  for v in "requests.get" "requests.post" "requests.put" "requests.delete" \
           "requests.patch" "requests.head" "requests.request"; do
    grep -q "$v" "$FIX" && verbs=$((verbs+1))
  done
  if [ "$verbs" -ge 3 ]; then
    say_ok "fixture covers >=3 HTTP verbs ($verbs)"
  else
    say_fail "fixture covers only $verbs HTTP verbs (expected >=3)"
  fi
else
  say_fail "fixture file missing"
fi

# 3) TEMPLATE.md
if [ -f "$TPL" ]; then
  say_ok "TEMPLATE.md exists"
  sections=0
  grep -qiE '^#+ *(Qu[eé] detecta|What)'          "$TPL" && sections=$((sections+1))
  grep -qiE '^#+ *(Cu[aá]ndo suprimir|Suppress)'  "$TPL" && sections=$((sections+1))
  grep -qiE '^#+ *(Cu[aá]ndo migrar|Migrar|Wrapper)' "$TPL" && sections=$((sections+1))
  grep -qiE '^#+ *(Due[nñ]o|Owner)'               "$TPL" && sections=$((sections+1))
  if [ "$sections" -ge 4 ]; then
    say_ok "TEMPLATE.md has 4 required sections"
  else
    say_fail "TEMPLATE.md has only $sections of 4 required sections"
  fi
else
  say_fail "TEMPLATE.md missing"
fi

# 4) Optional: semgrep --test.
if command -v semgrep >/dev/null 2>&1; then
  if [ -d "$BASE/.semgrep" ]; then
    if semgrep --test --quiet "$BASE/.semgrep/" >/dev/null 2>&1; then
      say_ok "semgrep --test passes"
    else
      say_fail "semgrep --test failed (check rule vs fixture)"
    fi
  else
    say_skip "semgrep: .semgrep/ not present"
  fi
else
  say_skip "semgrep CLI not installed"
fi

echo
echo "== Summary =="
echo "  pass=$pass  fail=$fail  skip=$skip"
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: estructura valida. Compara con solution/REFERENCE.md y solution/TEMPLATE.md."
exit 0
