#!/usr/bin/env bash
# Validate gha-09-02-add-manual-gate-to-prod.
#
# MODE=local (default): verifies workflow was NOT modified, sidecar shape, DECISION.md.
# MODE=live           : additionally applies the sidecar to a real repo via gh api.
#
# NOTE: no `set -o pipefail`. Several checks pipe long-producing output into
# grep -q / head and would get SIGPIPE (141) with pipefail enabled.

BASE="${1:-${SCRATCH_DIR:-/tmp/gha09-manual-gate}}"
MODE="${MODE:-local}"
fail=0

note_ok()   { echo "  OK   $1"; }
note_fail() { echo "  FAIL $1"; fail=$((fail+1)); }

echo "== Validating $BASE (MODE=$MODE) =="

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE missing. Run starter/bootstrap.sh first." >&2
  exit 1
fi

WF="$BASE/.github/workflows/release.yaml"
HASHFILE="$BASE/.starter-hash"
ENV_PRD="$BASE/environment-prod.yaml"
DECISION="$BASE/DECISION.md"

# ---------- 1) Workflow unmodified ----------
if [ ! -f "$WF" ] || [ ! -f "$HASHFILE" ]; then
  note_fail "workflow or hash file missing (did you run bootstrap?)"
else
  if command -v sha256sum >/dev/null 2>&1; then
    cur=$(sha256sum "$WF" | awk '{print $1}')
  else
    cur=$(shasum -a 256 "$WF" | awk '{print $1}')
  fi
  expected=$(cat "$HASHFILE")
  if [ "$cur" = "$expected" ]; then
    note_ok "workflow unmodified (hash matches starter)"
  else
    note_fail "workflow modified unexpectedly — the gate must live on the environment, not in the YAML"
  fi
fi

# ---------- 2) Sidecar shape ----------
if [ ! -f "$ENV_PRD" ]; then
  note_fail "environment-prod.yaml missing"
else
  python3 - "$ENV_PRD" <<'PY'
import sys, yaml
p = sys.argv[1]
try:
    d = yaml.safe_load(open(p))
except Exception as e:
    print(f"  FAIL environment-prod.yaml not parseable: {e}")
    sys.exit(1)
errs = []
def need(c, m):
    if not c: errs.append(m)

need(d.get("name") == "prod", "name must be 'prod'")
wt = d.get("wait_timer", -1)
need(isinstance(wt, int) and wt >= 5, "wait_timer must be >= 5")
need(d.get("prevent_self_review") is True, "prevent_self_review must be true")
revs = d.get("reviewers") or []
need(isinstance(revs, list) and len(revs) >= 2, "reviewers must have >= 2 entries")
types = [r.get("type") for r in revs if isinstance(r, dict)]
need("Team" in types, "at least one reviewer must have type Team")
bp = d.get("deployment_branch_policy", {})
need(bp.get("protected_branches") is False, "protected_branches must be false")
need(bp.get("custom_branch_policies") is True, "custom_branch_policies must be true")
patterns = bp.get("patterns") or []
need("refs/heads/main" in patterns, "patterns must include 'refs/heads/main'")

if errs:
    for e in errs: print("  FAIL "+e)
    sys.exit(1)
print("  OK   environment-prod.yaml shape")
PY
  rc=$?
  [ "$rc" -ne 0 ] && fail=$((fail+1))
fi

# ---------- 3) DECISION.md substantive ----------
if [ ! -f "$DECISION" ]; then
  note_fail "DECISION.md missing"
else
  nlines=$(grep -cve '^[[:space:]]*$' "$DECISION" 2>/dev/null || echo 0)
  if [ "$nlines" -ge 10 ]; then
    note_ok "DECISION.md present ($nlines non-empty lines)"
  else
    note_fail "DECISION.md too short ($nlines non-empty lines, need >= 10)"
  fi
fi

# ---------- 4) Live mode ----------
if [ "$MODE" = "live" ]; then
  if ! command -v gh >/dev/null 2>&1; then
    note_fail "MODE=live needs gh CLI"
  elif [ -z "${GH_OWNER:-}" ] || [ -z "${GH_REPO:-}" ]; then
    note_fail "MODE=live needs GH_OWNER and GH_REPO exported"
  elif ! gh auth status >/dev/null 2>&1; then
    note_fail "MODE=live needs gh auth"
  else
    wt=$(python3 -c "import yaml; print(yaml.safe_load(open('$ENV_PRD'))['wait_timer'])")
    echo "  .. upserting prod environment to $GH_OWNER/$GH_REPO (wait=$wt)"
    gh api -X PUT "repos/$GH_OWNER/$GH_REPO/environments/prod" \
      -F wait_timer="$wt" \
      -F "deployment_branch_policy[protected_branches]=false" \
      -F "deployment_branch_policy[custom_branch_policies]=true" \
      >/dev/null && note_ok "env 'prod' upserted" \
      || note_fail "env 'prod' upsert failed"
    gh api -X POST "repos/$GH_OWNER/$GH_REPO/environments/prod/deployment-branch-policies" \
      -f name='refs/heads/main' >/dev/null 2>&1 || true
    note_ok "pattern refs/heads/main added (if missing)"
    echo "  .. remember to delete when done:"
    echo "       gh api -X DELETE repos/$GH_OWNER/$GH_REPO/environments/prod"
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT ($MODE): $fail check(s) failed."
  exit 1
fi
echo "OK: actividad completada correctamente (MODE=$MODE)."
exit 0
