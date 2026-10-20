#!/usr/bin/env bash
# Validate gh-12-01-apply-rulesets.
# Modes:
#   MODE=local (default) — only parses JSON and checks shape; no GitHub needed.
#   MODE=live           — additionally applies ruleset via gh api and re-reads.
#
# Note: no `set -o pipefail` here — we use grep -q against potentially
# large outputs; SIGPIPE would cause spurious failures.

DIR="${1:-${SCRATCH_DIR:-/tmp/apply-rulesets}}"
MODE="${MODE:-local}"
fail=0

echo "== Validating $DIR (MODE=$MODE) =="

if [ ! -d "$DIR" ]; then
  echo "FAIL: $DIR missing. Run starter/build-scratch.sh first."
  exit 1
fi

JSON="$DIR/ruleset-main.json"
DECISION="$DIR/DECISION.md"

if [ ! -f "$JSON" ]; then
  echo "  FAIL ruleset-main.json missing"
  exit 1
fi

# 1) JSON parseable
if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$JSON" 2>/dev/null; then
  echo "  FAIL ruleset-main.json is not valid JSON"
  exit 1
fi
echo "  OK   JSON parseable"

# 2) Shape checks via python
python3 - "$JSON" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
errs = []
def need(cond, msg):
    if not cond: errs.append(msg)

need(d.get("name") == "protect-main", "name must be 'protect-main'")
need(d.get("target") == "branch", "target must be 'branch'")
need(d.get("enforcement") in ("active","evaluate"), "enforcement must be active|evaluate")
cond = d.get("conditions",{})
rn = cond.get("ref_name",{})
need("refs/heads/main" in (rn.get("include") or []), "conditions.ref_name.include must contain refs/heads/main")
rules = d.get("rules",[])
types = [r.get("type") for r in rules]
for t in ("deletion","non_fast_forward","pull_request","required_status_checks"):
    need(t in types, f"rules missing type '{t}'")
# pull_request params
pr = next((r for r in rules if r.get("type")=="pull_request"), None)
if pr:
    params = pr.get("parameters",{})
    need((params.get("required_approving_review_count") or 0) >= 1,
         "pull_request.required_approving_review_count must be >=1")
sc = next((r for r in rules if r.get("type")=="required_status_checks"), None)
if sc:
    checks = sc.get("parameters",{}).get("required_status_checks",[])
    need(len(checks) >= 1, "required_status_checks must list >=1 check")
need(isinstance(d.get("bypass_actors"), list),
     "bypass_actors must be a list (possibly empty)")

if errs:
    for e in errs: print("  FAIL "+e)
    sys.exit(1)
print("  OK   shape checks passed")
PY
if [ "$?" -ne 0 ]; then fail=$((fail+1)); fi

# 3) DECISION.md with substantive content (>=5 non-empty lines)
if [ ! -f "$DECISION" ]; then
  echo "  FAIL DECISION.md missing"
  fail=$((fail+1))
else
  nlines=$(grep -cve '^[[:space:]]*$' "$DECISION" 2>/dev/null || echo 0)
  if [ "$nlines" -ge 5 ]; then
    echo "  OK   DECISION.md present ($nlines non-empty lines)"
  else
    echo "  FAIL DECISION.md too short ($nlines non-empty lines, need >=5)"
    fail=$((fail+1))
  fi
fi

# 4) Live mode: apply via gh and re-read
if [ "$MODE" = "live" ]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "  FAIL MODE=live needs 'gh' installed"
    fail=$((fail+1))
  elif [ -z "${GH_OWNER:-}" ] || [ -z "${GH_REPO:-}" ]; then
    echo "  FAIL MODE=live needs GH_OWNER and GH_REPO exported"
    fail=$((fail+1))
  else
    echo "  .. applying ruleset to $GH_OWNER/$GH_REPO"
    created=$(gh api -X POST "repos/$GH_OWNER/$GH_REPO/rulesets" --input "$JSON" 2>&1) || {
      echo "  FAIL gh api POST failed: $created"
      fail=$((fail+1))
    }
    rid=$(printf '%s' "$created" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || true)
    if [ -n "$rid" ]; then
      echo "  OK   ruleset applied (id=$rid)"
      remote=$(gh api "repos/$GH_OWNER/$GH_REPO/rulesets/$rid" 2>/dev/null || true)
      if printf '%s' "$remote" | grep -q "protect-main"; then
        echo "  OK   remote ruleset readable and matches name"
      else
        echo "  FAIL remote ruleset not matching"
        fail=$((fail+1))
      fi
      echo "  .. remember to delete it: gh api -X DELETE repos/$GH_OWNER/$GH_REPO/rulesets/$rid"
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
