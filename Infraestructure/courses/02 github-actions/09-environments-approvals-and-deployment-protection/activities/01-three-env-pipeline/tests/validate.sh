#!/usr/bin/env bash
# Validate gha-09-01-three-env-pipeline.
#
# MODE=local (default): parses workflow YAML + sidecars; verifies shape;
#                       no GitHub needed.
# MODE=live           : additionally creates/updates environments in a real
#                       repo via `gh api` and re-reads them.
#
# NOTE: no `set -o pipefail`. Several checks pipe long-producing commands
# (git log, gh api) into `grep -q`; pipefail + SIGPIPE would report
# false failures (exit 141).

BASE="${1:-${SCRATCH_DIR:-/tmp/gha09-three-env}}"
MODE="${MODE:-local}"
fail=0

note_ok()   { echo "  OK   $1"; }
note_fail() { echo "  FAIL $1"; fail=$((fail+1)); }

echo "== Validating $BASE (MODE=$MODE) =="

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE missing. Run starter/bootstrap.sh first." >&2
  exit 1
fi

WF="$BASE/.github/workflows/cd.yaml"
ENV_DEV="$BASE/environment-dev.yaml"
ENV_STG="$BASE/environment-staging.yaml"
ENV_PRD="$BASE/environment-prod.yaml"

for f in "$WF" "$ENV_DEV" "$ENV_STG" "$ENV_PRD"; do
  if [ ! -f "$f" ]; then
    note_fail "missing file: $f"
  fi
done
[ "$fail" -gt 0 ] && { echo; echo "RESULT: $fail checks failed."; exit 1; }

# ---------- Workflow checks (Python YAML) ----------
python3 - "$WF" <<'PY'
import sys, yaml
p = sys.argv[1]
try:
    d = yaml.safe_load(open(p))
except Exception as e:
    print(f"  FAIL workflow YAML not parseable: {e}")
    sys.exit(1)

errs = []
def need(c, m):
    if not c: errs.append(m)

# PyYAML parses the key 'on' as python True under YAML 1.1 ("on" boolean).
on = d.get("on", d.get(True))
need(on is not None, "workflow must declare 'on'")
if isinstance(on, dict):
    push = on.get("push", {})
    branches = push.get("branches", []) if isinstance(push, dict) else []
    need("main" in branches, "workflow must trigger on push to main")
else:
    errs.append("'on' must be a mapping with 'push: branches: [main]'")

perms = d.get("permissions", {})
need(isinstance(perms, dict), "workflow should declare 'permissions:' as a mapping")
if isinstance(perms, dict):
    need(perms.get("contents") == "read", "permissions.contents must be 'read'")
    need(perms.get("deployments") == "write", "permissions.deployments must be 'write'")

jobs = d.get("jobs", {}) or {}
for name in ("dev","staging","prod"):
    need(name in jobs, f"missing job '{name}'")

if all(n in jobs for n in ("dev","staging","prod")):
    dev, stg, prd = jobs["dev"], jobs["staging"], jobs["prod"]

    def env_name(job):
        e = job.get("environment")
        if isinstance(e, str): return e
        if isinstance(e, dict): return e.get("name")
        return None

    need(env_name(dev) == "dev", "job 'dev' must have environment: dev")
    need(env_name(stg) == "staging", "job 'staging' must have environment: staging")
    need(env_name(prd) == "prod", "job 'prod' must have environment: prod")

    def needs_of(j):
        n = j.get("needs")
        if n is None: return []
        if isinstance(n, str): return [n]
        return list(n)
    need("dev" in needs_of(stg), "job 'staging' must have needs: [dev]")
    need("staging" in needs_of(prd), "job 'prod' must have needs: [staging]")
    need(not needs_of(dev), "job 'dev' must not depend on anything")

    for n, j in (("dev",dev),("staging",stg),("prod",prd)):
        steps = j.get("steps") or []
        need(len(steps) >= 1, f"job '{n}' must have >=1 step")

if errs:
    for e in errs: print("  FAIL "+e)
    sys.exit(1)
print("  OK   workflow shape")
PY
rc=$?
[ "$rc" -ne 0 ] && fail=$((fail+1))

# ---------- Sidecar checks ----------
python3 - "$ENV_DEV" "$ENV_STG" "$ENV_PRD" <<'PY'
import sys, yaml
paths = sys.argv[1:4]
errs = []
def need(c, m):
    if not c: errs.append(m)

try:
    dev = yaml.safe_load(open(paths[0]))
    stg = yaml.safe_load(open(paths[1]))
    prd = yaml.safe_load(open(paths[2]))
except Exception as e:
    print(f"  FAIL sidecar YAML not parseable: {e}")
    sys.exit(1)

# dev
need(dev.get("name") == "dev", "environment-dev.yaml: name must be 'dev'")
need(dev.get("wait_timer", -1) == 0, "environment-dev.yaml: wait_timer must be 0")
need(dev.get("reviewers", None) == [] or dev.get("reviewers") is None or dev.get("reviewers") == [],
     "environment-dev.yaml: reviewers must be empty list")
bp = dev.get("deployment_branch_policy", {})
need(bp.get("protected_branches") is False, "environment-dev.yaml: protected_branches must be false")
need(bp.get("custom_branch_policies") is False, "environment-dev.yaml: custom_branch_policies must be false")

# staging
need(stg.get("name") == "staging", "environment-staging.yaml: name must be 'staging'")
need(stg.get("wait_timer") == 2, "environment-staging.yaml: wait_timer must be 2")
need(stg.get("reviewers") in ([], None), "environment-staging.yaml: reviewers must be empty")
bp = stg.get("deployment_branch_policy", {})
need(bp.get("protected_branches") is False, "environment-staging.yaml: protected_branches must be false")
need(bp.get("custom_branch_policies") is False, "environment-staging.yaml: custom_branch_policies must be false")

# prod
need(prd.get("name") == "prod", "environment-prod.yaml: name must be 'prod'")
wt = prd.get("wait_timer", -1)
need(isinstance(wt, int) and wt >= 5, "environment-prod.yaml: wait_timer must be >= 5")
need(prd.get("prevent_self_review") is True, "environment-prod.yaml: prevent_self_review must be true")
revs = prd.get("reviewers") or []
need(isinstance(revs, list) and len(revs) >= 1, "environment-prod.yaml: reviewers must have >= 1 entry")
for r in revs if isinstance(revs, list) else []:
    need(r.get("type") in ("User","Team"),
         "environment-prod.yaml: each reviewer must have type User|Team")
bp = prd.get("deployment_branch_policy", {})
need(bp.get("protected_branches") is False, "environment-prod.yaml: protected_branches must be false")
need(bp.get("custom_branch_policies") is True, "environment-prod.yaml: custom_branch_policies must be true")
patterns = bp.get("patterns") or []
need("refs/heads/main" in patterns, "environment-prod.yaml: patterns must include 'refs/heads/main'")

if errs:
    for e in errs: print("  FAIL "+e)
    sys.exit(1)
print("  OK   sidecar shape (dev, staging, prod)")
PY
rc=$?
[ "$rc" -ne 0 ] && fail=$((fail+1))

# ---------- Optional actionlint ----------
if command -v actionlint >/dev/null 2>&1; then
  if actionlint "$WF" >/dev/null 2>&1; then
    note_ok "actionlint passed on workflow"
  else
    note_fail "actionlint found issues (run: actionlint $WF)"
  fi
else
  echo "  --   actionlint not installed, skipping (optional)"
fi

# ---------- Live mode: apply environments to a real repo ----------
if [ "$MODE" = "live" ]; then
  if ! command -v gh >/dev/null 2>&1; then
    note_fail "MODE=live needs gh CLI installed"
  elif [ -z "${GH_OWNER:-}" ] || [ -z "${GH_REPO:-}" ]; then
    note_fail "MODE=live needs GH_OWNER and GH_REPO exported"
  elif ! gh auth status >/dev/null 2>&1; then
    note_fail "MODE=live needs gh auth"
  else
    echo "  .. applying environments to $GH_OWNER/$GH_REPO"
    for name in dev staging prod; do
      case "$name" in
        dev)     wt=0 ; sidecar="$ENV_DEV" ;;
        staging) wt=2 ; sidecar="$ENV_STG" ;;
        prod)    sidecar="$ENV_PRD"
                 wt=$(python3 -c "import yaml; print(yaml.safe_load(open('$sidecar'))['wait_timer'])")
                 ;;
      esac
      cbp=$(python3 -c "import yaml; print(str(yaml.safe_load(open('$sidecar'))['deployment_branch_policy']['custom_branch_policies']).lower())")
      if [ "$cbp" = "true" ]; then
        gh api -X PUT "repos/$GH_OWNER/$GH_REPO/environments/$name" \
          -F wait_timer="$wt" \
          -F "deployment_branch_policy[protected_branches]=false" \
          -F "deployment_branch_policy[custom_branch_policies]=true" \
          >/dev/null && note_ok "env '$name' upserted (wait=$wt, custom_branch=true)" \
          || note_fail "env '$name' upsert failed"
        gh api -X POST "repos/$GH_OWNER/$GH_REPO/environments/$name/deployment-branch-policies" \
          -f name='refs/heads/main' >/dev/null 2>&1 || true
      else
        # No restriction: pass empty object (API requires it to be null for no policy)
        gh api -X PUT "repos/$GH_OWNER/$GH_REPO/environments/$name" \
          -F wait_timer="$wt" \
          >/dev/null && note_ok "env '$name' upserted (wait=$wt, no branch policy)" \
          || note_fail "env '$name' upsert failed"
      fi
      # Re-read and verify wait_timer
      got=$(gh api "repos/$GH_OWNER/$GH_REPO/environments/$name" --jq '.wait_timer' 2>/dev/null || echo "")
      if [ "$got" = "$wt" ]; then
        note_ok "env '$name' remote wait_timer=$got matches"
      else
        note_fail "env '$name' remote wait_timer=$got != expected $wt"
      fi
    done
    echo "  .. remember to delete the environments after you're done:"
    echo "       for e in dev staging prod; do gh api -X DELETE repos/$GH_OWNER/$GH_REPO/environments/\$e; done"
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT ($MODE): $fail check(s) failed."
  exit 1
fi
echo "OK: actividad completada correctamente (MODE=$MODE)."
exit 0
