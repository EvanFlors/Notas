#!/usr/bin/env bash
# Validate gh-12-02-codeowners-plus-required-reviewers.
# MODE=local (default): offline checks on files only.
# MODE=live: also calls GitHub to list codeowners errors.
#
# No `set -o pipefail` — we use grep/awk against files which may trip pipefail
# with SIGPIPE when grep -q exits early.

DIR="${1:-${SCRATCH_DIR:-/tmp/codeowners-lab}}"
MODE="${MODE:-local}"
fail=0

echo "== Validating $DIR (MODE=$MODE) =="
if [ ! -d "$DIR" ]; then
  echo "FAIL: $DIR missing. Run starter/build-repo.sh first."
  exit 1
fi

CO="$DIR/.github/CODEOWNERS"
PT="$DIR/.github/pull_request_template.md"
RS="$DIR/.github/ruleset-codeowners.json"

# 1) CODEOWNERS exists and has required mappings
if [ ! -s "$CO" ]; then
  echo "  FAIL CODEOWNERS missing or empty"
  fail=$((fail+1))
else
  echo "  OK   CODEOWNERS exists"

  check_rule() {
    local pattern="$1"; local owner="$2"; local label="$3"
    # find non-comment lines matching the pattern at col 1 and containing the owner anywhere after
    if awk -v p="$pattern" -v o="$owner" '
        /^[[:space:]]*#/ {next}
        NF==0 {next}
        $1==p {for (i=2;i<=NF;i++) if ($i==o) {found=1; exit}}
        END {exit found?0:1}' "$CO"; then
      echo "  OK   rule '$label' present ($pattern → $owner)"
    else
      echo "  FAIL rule '$label' missing or wrong ($pattern → $owner)"
      fail=$((fail+1))
    fi
  }

  check_rule "*"                       "@example-org/platform"         "default fallback"
  check_rule "infra/"                  "@example-org/sre"              "infra dir"
  check_rule "*.tf"                    "@example-org/sre"              "terraform files"
  check_rule "services/api/"           "@example-org/backend"          "api service team"
  # user alice must also appear on the services/api/ line
  if awk '$1=="services/api/" && /@alice/{found=1} END{exit found?0:1}' "$CO"; then
    echo "  OK   services/api/ also owns @alice"
  else
    echo "  FAIL services/api/ missing user owner @alice"
    fail=$((fail+1))
  fi
  check_rule "apps/web/"               "@example-org/frontend"         "frontend"
  check_rule "docs/"                   "@example-org/docs"             "docs"
  check_rule ".github/CODEOWNERS"      "@example-org/platform-admins"  "codeowners self-ownership"
fi

# 2) PR template with 4 sections
if [ ! -s "$PT" ]; then
  echo "  FAIL pull_request_template.md missing or empty"
  fail=$((fail+1))
else
  missing_sec=0
  for sec in Context Change Testing Risk; do
    if ! grep -qi "$sec" "$PT"; then
      echo "  FAIL PR template missing section mentioning '$sec'"
      missing_sec=$((missing_sec+1))
    fi
  done
  if [ "$missing_sec" -eq 0 ]; then
    echo "  OK   PR template has required sections"
  else
    fail=$((fail+missing_sec))
  fi
fi

# 3) Ruleset JSON valid and has require_code_owner_review: true
if [ ! -s "$RS" ]; then
  echo "  FAIL ruleset-codeowners.json missing or empty"
  fail=$((fail+1))
else
  python3 - "$RS" <<'PY' || exit 1
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception as e:
    print(f"  FAIL ruleset JSON invalid: {e}")
    sys.exit(2)
rules = d.get("rules", [])
pr = next((r for r in rules if r.get("type") == "pull_request"), None)
if not pr:
    print("  FAIL ruleset has no pull_request rule")
    sys.exit(3)
if not pr.get("parameters", {}).get("require_code_owner_review"):
    print("  FAIL ruleset.pull_request.require_code_owner_review not true")
    sys.exit(4)
print("  OK   ruleset JSON valid with require_code_owner_review=true")
PY
  rc=$?
  if [ "$rc" -ne 0 ]; then fail=$((fail+1)); fi
fi

# 4) Live mode: query codeowners errors
if [ "$MODE" = "live" ]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "  FAIL MODE=live needs 'gh'"
    fail=$((fail+1))
  elif [ -z "${GH_OWNER:-}" ] || [ -z "${GH_REPO:-}" ]; then
    echo "  FAIL MODE=live needs GH_OWNER and GH_REPO"
    fail=$((fail+1))
  else
    errs=$(gh api "repos/$GH_OWNER/$GH_REPO/codeowners/errors" 2>/dev/null || true)
    nerr=$(printf '%s' "$errs" | python3 -c "import sys,json;d=json.load(sys.stdin);print(len(d.get('errors',[])))" 2>/dev/null || echo "?")
    if [ "$nerr" = "0" ]; then
      echo "  OK   remote codeowners/errors is empty"
    else
      echo "  FAIL remote codeowners/errors reports $nerr error(s)"
      echo "  $errs"
      fail=$((fail+1))
    fi
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: actividad completada correctamente (MODE=$MODE)."
exit 0
