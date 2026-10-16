#!/usr/bin/env bash
# Structural validation for sec-04-01-full-pipeline-secret-scan.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
set -eu

BASE="${1:-${BASE_DIR:-/tmp/sec-04-full-pipeline}}"
fail=0

echo "== Validating sec-04-01 pipeline under $BASE =="

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE does not exist. Build the repo first (see README.md)."
  exit 1
fi

# ---------- 1. git repo ----------
if [ -d "$BASE/.git" ]; then
  echo "  OK   .git directory present"
else
  echo "  FAIL $BASE is not a git repo (missing .git/)"
  fail=$((fail+1))
fi

# ---------- 2. .pre-commit-config.yaml ----------
PRECOMMIT="$BASE/.pre-commit-config.yaml"
if [ -f "$PRECOMMIT" ]; then
  echo "  OK   .pre-commit-config.yaml present"
  if grep -qi "gitleaks" "$PRECOMMIT"; then
    echo "  OK   .pre-commit-config.yaml references gitleaks"
  else
    echo "  FAIL .pre-commit-config.yaml does not reference gitleaks"
    fail=$((fail+1))
  fi
  if grep -qE "^\s*rev:" "$PRECOMMIT"; then
    echo "  OK   .pre-commit-config.yaml pins a rev (version)"
  else
    echo "  FAIL .pre-commit-config.yaml missing 'rev:' pin"
    fail=$((fail+1))
  fi
else
  echo "  FAIL $PRECOMMIT missing"
  fail=$((fail+1))
fi

# ---------- 3. .gitleaks.toml ----------
TOML="$BASE/.gitleaks.toml"
if [ -f "$TOML" ]; then
  echo "  OK   .gitleaks.toml present"
  if grep -qE "^\[extend\]" "$TOML" && grep -qE "useDefault\s*=\s*true" "$TOML"; then
    echo "  OK   .gitleaks.toml extends default rules"
  else
    echo "  FAIL .gitleaks.toml does not '[extend] useDefault = true'"
    fail=$((fail+1))
  fi
  if grep -qE "^\[allowlist\]" "$TOML"; then
    echo "  OK   .gitleaks.toml declares an [allowlist]"
  else
    echo "  FAIL .gitleaks.toml missing [allowlist]"
    fail=$((fail+1))
  fi
  if grep -q "tests/fixtures" "$TOML"; then
    echo "  OK   allowlist covers tests/fixtures path"
  else
    echo "  FAIL allowlist does not mention tests/fixtures"
    fail=$((fail+1))
  fi
  if grep -qE "stopwords" "$TOML"; then
    echo "  OK   .gitleaks.toml declares stopwords"
  else
    echo "  FAIL .gitleaks.toml missing stopwords"
    fail=$((fail+1))
  fi
else
  echo "  FAIL $TOML missing"
  fail=$((fail+1))
fi

# ---------- 4. GitHub Actions workflow ----------
WF="$BASE/.github/workflows/secret-scan.yml"
if [ -f "$WF" ]; then
  echo "  OK   secret-scan workflow present"
  if grep -q "actions/checkout" "$WF"; then
    echo "  OK   workflow uses actions/checkout"
  else
    echo "  FAIL workflow does not reference actions/checkout"
    fail=$((fail+1))
  fi
  if grep -qE "fetch-depth:\s*0" "$WF"; then
    echo "  OK   workflow sets fetch-depth: 0 (full history)"
  else
    echo "  FAIL workflow missing 'fetch-depth: 0' (needed to scan history)"
    fail=$((fail+1))
  fi
  if grep -qi "gitleaks" "$WF"; then
    echo "  OK   workflow invokes gitleaks"
  else
    echo "  FAIL workflow does not run gitleaks"
    fail=$((fail+1))
  fi
else
  echo "  FAIL $WF missing"
  fail=$((fail+1))
fi

# ---------- 5. fake fixture ----------
FIX="$BASE/tests/fixtures/sample.env"
if [ -f "$FIX" ]; then
  echo "  OK   tests/fixtures/sample.env present"
  if grep -qiE "fake|demo" "$FIX"; then
    echo "  OK   fixture contains obvious-fake markers (fake/demo)"
  else
    echo "  FAIL fixture lacks obvious-fake markers; secrets must look clearly fake"
    fail=$((fail+1))
  fi
else
  echo "  FAIL $FIX missing (needed to exercise the allowlist)"
  fail=$((fail+1))
fi

# ---------- 6. RUNBOOK.md ----------
RUN="$BASE/RUNBOOK.md"
if [ -f "$RUN" ]; then
  echo "  OK   RUNBOOK.md present"
  for kw in "rotar" "post-mortem" "blast radius"; do
    if grep -qi "$kw" "$RUN"; then
      echo "  OK   RUNBOOK mentions '$kw'"
    else
      echo "  FAIL RUNBOOK does not mention '$kw'"
      fail=$((fail+1))
    fi
  done
  if grep -qiE "filter-repo|bfg" "$RUN"; then
    echo "  OK   RUNBOOK mentions filter-repo or BFG"
  else
    echo "  FAIL RUNBOOK does not mention filter-repo nor BFG"
    fail=$((fail+1))
  fi
  if grep -qiE "force[- ]push" "$RUN"; then
    echo "  OK   RUNBOOK mentions force-push coordination"
  else
    echo "  FAIL RUNBOOK does not mention force-push"
    fail=$((fail+1))
  fi
  # Order check: 'rotar' must appear before 'filter-repo' / 'bfg' in the file.
  rotate_line=$(grep -niE "rotar" "$RUN" | head -n1 | cut -d: -f1 || true)
  rewrite_line=$(grep -niE "filter-repo|bfg" "$RUN" | head -n1 | cut -d: -f1 || true)
  if [ -n "$rotate_line" ] && [ -n "$rewrite_line" ] && [ "$rotate_line" -lt "$rewrite_line" ]; then
    echo "  OK   RUNBOOK mentions rotar BEFORE filter-repo/bfg"
  else
    echo "  FAIL RUNBOOK order wrong: rotar must appear before filter-repo/bfg"
    fail=$((fail+1))
  fi
else
  echo "  FAIL $RUN missing"
  fail=$((fail+1))
fi

# ---------- 7. optional smoke test with real gitleaks ----------
if command -v gitleaks >/dev/null 2>&1; then
  echo "  INFO gitleaks found; running smoke test on fixture (allowlist expected to pass)"
  if (cd "$BASE" && gitleaks detect --no-git --redact --config .gitleaks.toml --source tests/fixtures >/dev/null 2>&1); then
    echo "  OK   gitleaks respects allowlist on tests/fixtures"
  else
    echo "  FAIL gitleaks flagged tests/fixtures despite the allowlist (review your .gitleaks.toml)"
    fail=$((fail+1))
  fi
else
  echo "  SKIP gitleaks not installed; structural checks only"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  exit 1
fi
echo "OK: pipeline estructura valida. Compara con solution/REFERENCE.md para autoevaluarte."
exit 0
