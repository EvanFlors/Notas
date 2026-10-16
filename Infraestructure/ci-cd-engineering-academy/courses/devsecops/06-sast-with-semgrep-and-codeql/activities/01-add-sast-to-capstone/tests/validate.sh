#!/usr/bin/env bash
# Structural validation for sec-06-01-add-sast-to-capstone.
#
# Note: we deliberately do NOT enable `set -o pipefail` because several checks
# use `... | grep -q ...` which produces SIGPIPE (exit 141) when grep finds a
# match early. pipefail would spuriously mark those as failures.
set -eu

BASE="${1:-/tmp/sec-06-01-capstone}"
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

# 1) src/app.py must exist and contain the 3 planted vulns.
APP="$BASE/src/app.py"
if [ -f "$APP" ]; then
  say_ok "src/app.py exists"
  if grep -q "requests.get" "$APP" && ! grep -q "timeout=" "$APP"; then
    say_ok "src/app.py has requests.get without timeout"
  else
    say_fail "src/app.py missing 'requests.get(...)' without timeout"
  fi
  if grep -Eq "hashlib\.(md5|sha1)" "$APP"; then
    say_ok "src/app.py uses weak hash (md5/sha1)"
  else
    say_fail "src/app.py missing hashlib.md5 or hashlib.sha1"
  fi
  if grep -q "shell=True" "$APP"; then
    say_ok "src/app.py uses subprocess with shell=True"
  else
    say_fail "src/app.py missing 'shell=True'"
  fi
else
  say_fail "src/app.py missing"
fi

# 2) Workflows.
SEM_WF="$BASE/.github/workflows/semgrep.yml"
if [ -f "$SEM_WF" ]; then
  say_ok ".github/workflows/semgrep.yml exists"
  if grep -q "upload-sarif" "$SEM_WF"; then
    say_ok "semgrep.yml uploads SARIF"
  else
    say_fail "semgrep.yml missing 'upload-sarif' step"
  fi
  if grep -q "pull_request" "$SEM_WF"; then
    say_ok "semgrep.yml runs on pull_request"
  else
    say_fail "semgrep.yml missing 'pull_request' trigger"
  fi
else
  say_fail ".github/workflows/semgrep.yml missing"
fi

CQ_WF="$BASE/.github/workflows/codeql.yml"
if [ -f "$CQ_WF" ]; then
  say_ok ".github/workflows/codeql.yml exists"
  if grep -qi "python" "$CQ_WF"; then
    say_ok "codeql.yml declares python language"
  else
    say_fail "codeql.yml does not mention 'python'"
  fi
  if grep -q "codeql-action/init" "$CQ_WF" && grep -q "codeql-action/analyze" "$CQ_WF"; then
    say_ok "codeql.yml has init + analyze steps"
  else
    say_fail "codeql.yml missing init and/or analyze step"
  fi
else
  say_fail ".github/workflows/codeql.yml missing"
fi

# 3) TRIAGE.md
TRG="$BASE/TRIAGE.md"
if [ -f "$TRG" ]; then
  say_ok "TRIAGE.md exists"
  # Count table rows (lines starting with '|'); header+sep+10 rows = >=12.
  rows=$(grep -cE '^\|' "$TRG" || true)
  if [ "$rows" -ge 12 ]; then
    say_ok "TRIAGE.md has at least 10 entries ($rows pipe-lines found)"
  else
    say_fail "TRIAGE.md has only $rows pipe-lines (expected >=12 for 10 entries + header + sep)"
  fi
  cats=0
  grep -qiE 'fix' "$TRG"             && cats=$((cats+1))
  grep -qiE 'suppress' "$TRG"        && cats=$((cats+1))
  grep -qiE 'false[- ]positive|FP' "$TRG" && cats=$((cats+1))
  if [ "$cats" -ge 3 ]; then
    say_ok "TRIAGE.md uses all 3 categories (fix / suppress / false-positive)"
  else
    say_fail "TRIAGE.md uses only $cats of the 3 required categories"
  fi
else
  say_fail "TRIAGE.md missing"
fi

# 4) Optional: run semgrep / bandit if available (SKIP otherwise).
if command -v semgrep >/dev/null 2>&1; then
  if [ -d "$BASE/src" ]; then
    if semgrep scan --quiet --config auto --error "$BASE/src" >/dev/null 2>&1; then
      # No findings — unexpected for the planted vulns.
      say_fail "semgrep ran but reported 0 ERROR findings (expected some)"
    else
      say_ok "semgrep ran and reported findings"
    fi
  else
    say_skip "semgrep: src/ not present, skipping scan"
  fi
else
  say_skip "semgrep CLI not installed"
fi

if command -v bandit >/dev/null 2>&1; then
  if [ -d "$BASE/src" ]; then
    bandit -q -r "$BASE/src" >/dev/null 2>&1
    rc=$?
    if [ "$rc" -ne 0 ]; then
      say_ok "bandit ran and reported findings (exit $rc)"
    else
      say_fail "bandit ran but reported 0 findings (expected some)"
    fi
  else
    say_skip "bandit: src/ not present, skipping scan"
  fi
else
  say_skip "bandit CLI not installed"
fi

# CodeQL is doc-only; even if installed, we only check the workflow file above.
say_skip "codeql: doc-only in this module (workflow checked above)"

echo
echo "== Summary =="
echo "  pass=$pass  fail=$fail  skip=$skip"
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: estructura valida. Compara TRIAGE.md con solution/REFERENCE.md para autoevaluarte."
exit 0
