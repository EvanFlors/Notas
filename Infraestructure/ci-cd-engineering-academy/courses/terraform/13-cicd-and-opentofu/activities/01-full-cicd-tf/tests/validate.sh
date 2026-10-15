#!/usr/bin/env bash
# Validator for tf-13-01-full-cicd-tf.
# NOTE: we deliberately do NOT enable `set -o pipefail` because many checks pipe
# into `grep -q`, which closes stdin early (SIGPIPE) and would be reported as a
# producer-side failure under pipefail. We check exit codes explicitly instead.

BASE="${1:-${BASE_DIR:-/tmp/tf-cicd}}"
MODE="${MODE:-local}"
P="$BASE/project"

pass=0
fail=0
report=""
ok()  { report+="  OK   -- $1\n"; pass=$((pass+1)); }
bad() { report+="  FAIL -- $1\n"; fail=$((fail+1)); }

echo "== Validating tf-13-01 full CI/CD TF (MODE=$MODE) under $P =="

if [ ! -d "$P" ]; then
  bad "project missing at $P (run starter/bootstrap.sh first)"
  echo; printf "%b" "$report"; echo
  echo "RESULT: $pass OK / $fail FAIL  ->  FAIL"
  exit 1
fi

PLAN_WF="$P/.github/workflows/tf-plan.yml"
APPLY_WF="$P/.github/workflows/tf-apply.yml"
DRIFT_WF="$P/.github/workflows/tf-drift.yml"
PLAN_TRUST="$P/trust-policies/plan.json"
APPLY_TRUST="$P/trust-policies/apply.json"
VERSIONS="$P/terraform/versions.tf"
LOCKFILE="$P/terraform/.terraform.lock.hcl"
DOC="$P/docs/pipeline.md"

# ---- terraform/versions.tf ----
if [ ! -s "$VERSIONS" ]; then
  bad "terraform/versions.tf missing or empty"
else
  if grep -q 'required_version' "$VERSIONS"; then
    ok "versions.tf has required_version"
  else
    bad "versions.tf missing required_version"
  fi
fi

# ---- terraform/.terraform.lock.hcl ----
if [ ! -s "$LOCKFILE" ]; then
  bad ".terraform.lock.hcl missing or empty"
else
  if grep -q 'registry.terraform.io/hashicorp/aws' "$LOCKFILE"; then
    ok ".terraform.lock.hcl present with aws provider"
  else
    bad ".terraform.lock.hcl present but no hashicorp/aws provider"
  fi
fi

# ---- helper: run Python inspector on a workflow ----
# Writes the semantic verdict to stdout (so caller can capture ROLE_ARN) AND
# updates pass/fail/report directly (NOT in a subshell).
WF_VERDICT=""
WF_ROLE=""
inspect_workflow() {
  local path="$1" kind="$2"
  WF_VERDICT=""; WF_ROLE=""
  if [ ! -s "$path" ]; then
    bad "workflow $kind missing or empty: $path"
    return
  fi
  ok "workflow $kind exists: $(basename "$path")"
  WF_VERDICT="$(KIND="$kind" python3 - "$path" <<'PY' 2>&1
import os, re, sys, yaml
kind = os.environ["KIND"]
path = sys.argv[1]
raw = open(path).read()
try:
    doc = yaml.safe_load(raw)
except Exception as e:
    print(f"PARSE_ERROR: {e}"); sys.exit(0)

issues = []
if not isinstance(doc, dict):
    print("ISSUE: root not a mapping"); sys.exit(0)

# PyYAML parses 'on:' as True (boolean). Accept both keys.
on = doc.get("on", doc.get(True))
top_perms = doc.get("permissions")

# --- top-level permissions must be restrictive ---
if top_perms is None:
    issues.append("top-level 'permissions:' must be declared explicitly ({} or contents: read)")
elif isinstance(top_perms, str):
    if top_perms.lower() == "write-all":
        issues.append("top-level 'permissions: write-all' is forbidden")
elif isinstance(top_perms, dict):
    if str(top_perms.get("id-token", "")).lower() == "write":
        issues.append("top-level 'id-token: write' not allowed; put it inside the job only")
    for k, v in top_perms.items():
        if str(v).lower() == "write" and k != "contents":
            issues.append(f"top-level permission '{k}: write' not allowed")

# --- trigger ---
def on_has(key):
    if isinstance(on, dict):
        return key in on
    if isinstance(on, list):
        return key in on
    if isinstance(on, str):
        return on == key
    return False

if kind == "plan" and not on_has("pull_request"):
    issues.append("plan workflow must trigger on: pull_request")
if kind == "apply" and not on_has("push"):
    issues.append("apply workflow must trigger on: push")
if kind == "drift" and not on_has("schedule"):
    issues.append("drift workflow must trigger on: schedule")

jobs = doc.get("jobs") or {}
if not jobs:
    issues.append("no jobs defined")

id_token_in_job = False
has_env_prod = False
uses_setup_tf = False
setup_tf_version = None
role_arn = None
has_oidc_configure = False
has_upload_artifact = False
has_download_artifact = False
has_apply_saved_plan = False
has_apply_auto_approve = False
has_refresh_only = False
has_detailed_exitcode = False
has_conditional_issue_step = False

for jname, jbody in jobs.items():
    if not isinstance(jbody, dict):
        continue
    jp = jbody.get("permissions")
    if isinstance(jp, dict) and str(jp.get("id-token", "")).lower() == "write":
        id_token_in_job = True
    env = jbody.get("environment")
    if isinstance(env, str) and env == "production":
        has_env_prod = True
    elif isinstance(env, dict) and env.get("name") == "production":
        has_env_prod = True
    for step in (jbody.get("steps") or []):
        if not isinstance(step, dict):
            continue
        u = str(step.get("uses") or "")
        name = str(step.get("name") or "")
        run = str(step.get("run") or "")
        if u.startswith("hashicorp/setup-terraform") or u.startswith("opentofu/setup-opentofu"):
            uses_setup_tf = True
            w = step.get("with") or {}
            setup_tf_version = w.get("terraform_version") or w.get("tofu_version")
        if u.startswith("aws-actions/configure-aws-credentials"):
            has_oidc_configure = True
            w = step.get("with") or {}
            if w.get("role-to-assume"):
                role_arn = str(w["role-to-assume"])
        if u.startswith("actions/upload-artifact"):
            has_upload_artifact = True
        if u.startswith("actions/download-artifact") or u.startswith("dawidd6/action-download-artifact"):
            has_download_artifact = True
        if re.search(r'terraform\s+apply\b[^#\n]*plan\.tfplan', run):
            has_apply_saved_plan = True
        if re.search(r'-auto-approve', run):
            has_apply_auto_approve = True
        if '-refresh-only' in run:
            has_refresh_only = True
        if '-detailed-exitcode' in run:
            has_detailed_exitcode = True
        # Conditional issue-opening step
        cond = str(step.get("if") or "")
        if re.search(r"steps\.[A-Za-z0-9_-]+\.outputs\.exitcode\s*==\s*'?2'?", cond):
            has_conditional_issue_step = True

# Per-kind requirements
if kind == "plan":
    if not id_token_in_job:
        issues.append("plan: no job declares 'permissions: id-token: write'")
    if not uses_setup_tf:
        issues.append("plan: no step uses hashicorp/setup-terraform or opentofu/setup-opentofu")
    if setup_tf_version in (None, ""):
        issues.append("plan: setup action missing explicit terraform_version/tofu_version")
    if not has_oidc_configure or not role_arn:
        issues.append("plan: missing aws-actions/configure-aws-credentials with role-to-assume")
    if role_arn and ("plan" not in role_arn):
        issues.append(f"plan: role-to-assume should be a plan role, got '{role_arn}'")
    if not has_upload_artifact:
        issues.append("plan: must upload the plan artifact (actions/upload-artifact)")
if kind == "apply":
    if not id_token_in_job:
        issues.append("apply: no job declares 'permissions: id-token: write'")
    if not uses_setup_tf:
        issues.append("apply: no setup-terraform/setup-opentofu step")
    if setup_tf_version in (None, ""):
        issues.append("apply: setup action missing explicit terraform_version/tofu_version")
    if not has_env_prod:
        issues.append("apply: must declare 'environment: production'")
    if not has_oidc_configure or not role_arn:
        issues.append("apply: missing aws-actions/configure-aws-credentials with role-to-assume")
    if role_arn and ("apply" not in role_arn):
        issues.append(f"apply: role-to-assume should be an apply role, got '{role_arn}'")
    if not has_download_artifact:
        issues.append("apply: must download the plan artifact (actions/download-artifact or dawidd6/action-download-artifact)")
    if not has_apply_saved_plan:
        issues.append("apply: must run 'terraform apply <...> plan.tfplan' (saved plan)")
    if has_apply_auto_approve:
        issues.append("apply: must NOT use -auto-approve when applying a saved plan")
if kind == "drift":
    if not id_token_in_job:
        issues.append("drift: no job declares 'permissions: id-token: write'")
    if not has_refresh_only:
        issues.append("drift: no step runs 'terraform plan -refresh-only'")
    if not has_detailed_exitcode:
        issues.append("drift: no step uses '-detailed-exitcode'")
    if not has_conditional_issue_step:
        issues.append("drift: no conditional step guarded by 'steps.<id>.outputs.exitcode == 2'")

# Forbidden patterns (apply to any workflow)
forbidden = [
    (r"AKIA[0-9A-Z]{10,}", "AKIA access key"),
    (r"\$\{\{\s*secrets\.AWS_ACCESS_KEY_ID\s*\}\}", "secrets.AWS_ACCESS_KEY_ID"),
    (r"\$\{\{\s*secrets\.AWS_SECRET_ACCESS_KEY\s*\}\}", "secrets.AWS_SECRET_ACCESS_KEY"),
    (r"permissions:\s*write-all", "permissions: write-all"),
]
for pat, label in forbidden:
    if re.search(pat, raw):
        issues.append(f"forbidden pattern '{label}' present")

print(f"ROLE_ARN={role_arn or ''}")
if issues:
    for i in issues:
        print(f"ISSUE: {i}")
else:
    print("OK")
PY
)"
  if printf '%s' "$WF_VERDICT" | grep -q '^PARSE_ERROR'; then
    bad "$kind workflow invalid YAML: $(printf '%s' "$WF_VERDICT" | head -1)"
  elif printf '%s' "$WF_VERDICT" | grep -q '^OK$'; then
    ok "$kind workflow passes semantic checks"
  else
    local issues_line
    issues_line="$(printf '%s' "$WF_VERDICT" | grep '^ISSUE:' | tr '\n' '|')"
    bad "$kind workflow issues: $issues_line"
  fi
  WF_ROLE="$(printf '%s' "$WF_VERDICT" | grep -E '^ROLE_ARN=' | sed 's/^ROLE_ARN=//')"
}

inspect_workflow "$PLAN_WF"  "plan";  PLAN_ROLE="$WF_ROLE"
inspect_workflow "$APPLY_WF" "apply"; APPLY_ROLE="$WF_ROLE"
inspect_workflow "$DRIFT_WF" "drift"; DRIFT_ROLE="$WF_ROLE"

# Compare plan vs apply role (they must differ)
if [ -n "$PLAN_ROLE" ] && [ -n "$APPLY_ROLE" ]; then
  if [ "$PLAN_ROLE" = "$APPLY_ROLE" ]; then
    bad "plan and apply workflows use the SAME role '$PLAN_ROLE' — must be two distinct roles"
  else
    ok "plan role ($PLAN_ROLE) differs from apply role ($APPLY_ROLE)"
  fi
fi

# ---- trust policies ----
check_trust() {
  local path="$1" kind="$2"
  if [ ! -s "$path" ]; then
    bad "trust-policies/$kind.json missing or empty"
    return
  fi
  ok "trust-policies/$kind.json exists"
  local verdict
  verdict="$(KIND="$kind" python3 - "$path" <<'PY' 2>&1
import json, os, sys
kind = os.environ["KIND"]
path = sys.argv[1]
try:
    data = json.load(open(path))
except Exception as e:
    print(f"PARSE_ERROR: {e}"); sys.exit(1)

issues = []
if data.get("Version") != "2012-10-17":
    issues.append(f"Version must be '2012-10-17' (got {data.get('Version')!r})")

stmts = data.get("Statement") or []
if not isinstance(stmts, list) or not stmts:
    issues.append("Statement must be a non-empty list")

found_valid = False
for s in stmts:
    if s.get("Effect") != "Allow":
        continue
    acts = s.get("Action")
    acts = acts if isinstance(acts, list) else [acts]
    if "sts:AssumeRoleWithWebIdentity" not in acts:
        continue
    princ = s.get("Principal") or {}
    fed = princ.get("Federated")
    feds = fed if isinstance(fed, list) else [fed]
    if not any(isinstance(f, str) and f.endswith("/token.actions.githubusercontent.com") for f in feds):
        continue
    cond = s.get("Condition") or {}
    aud_ok = False
    sub_val = None
    for op, kv in cond.items():
        if not isinstance(kv, dict):
            continue
        for k, v in kv.items():
            vals = v if isinstance(v, list) else [v]
            if k == "token.actions.githubusercontent.com:aud" and "sts.amazonaws.com" in vals:
                aud_ok = True
            if k == "token.actions.githubusercontent.com:sub":
                for val in vals:
                    if isinstance(val, str) and val.startswith("repo:"):
                        sub_val = val
    if not aud_ok:
        issues.append("Condition missing aud=sts.amazonaws.com")
        continue
    if sub_val is None:
        issues.append("Condition missing a sub pin starting with 'repo:'")
        continue
    # dangerous wildcards: repo:*  or wildcard in owner/repo
    parts = sub_val.split(":")
    if sub_val.startswith("repo:*") or (len(parts) >= 2 and "*" in parts[1]):
        issues.append(f"sub pin uses dangerous wildcard: {sub_val}")
        continue
    if sub_val.rstrip().endswith(":*"):
        issues.append(f"sub pin ends with wildcard ':*': {sub_val}")
        continue
    # kind-specific sub expectations
    if kind == "plan":
        if ":environment:production" in sub_val:
            issues.append(f"plan trust should NOT pin environment:production (got {sub_val})")
            continue
        if (":pull_request" not in sub_val) and (":ref:refs/pull/" not in sub_val):
            issues.append(f"plan trust must pin sub to ':pull_request' or ':ref:refs/pull/' (got {sub_val})")
            continue
    if kind == "apply":
        if ":pull_request" in sub_val:
            issues.append(f"apply trust must NOT pin ':pull_request' (got {sub_val})")
            continue
        if ":environment:production" not in sub_val:
            issues.append(f"apply trust must pin ':environment:production' (got {sub_val})")
            continue
    found_valid = True
    break

if not found_valid and not issues:
    issues.append("no valid Allow sts:AssumeRoleWithWebIdentity statement for GitHub OIDC")

if issues:
    for i in issues: print(f"ISSUE: {i}")
else:
    print("OK")
PY
)"
  if printf '%s' "$verdict" | grep -q '^PARSE_ERROR'; then
    bad "trust-policies/$kind.json invalid JSON: $(printf '%s' "$verdict")"
  elif printf '%s' "$verdict" | grep -q '^OK$'; then
    ok "trust-policies/$kind.json passes semantic checks"
  else
    bad "trust-policies/$kind.json issues: $(printf '%s' "$verdict" | tr '\n' '|')"
  fi
}

check_trust "$PLAN_TRUST"  "plan"
check_trust "$APPLY_TRUST" "apply"

# ---- docs/pipeline.md ----
if [ ! -s "$DOC" ]; then
  bad "docs/pipeline.md missing or empty"
else
  ok "docs/pipeline.md exists"
  missing=""
  grep -qi 'plan\.tfplan'    "$DOC" || missing+=" plan.tfplan"
  grep -qi 'TOCTOU'          "$DOC" || missing+=" TOCTOU"
  grep -qi 'environment'     "$DOC" || missing+=" environment"
  grep -qi 'OIDC'            "$DOC" || missing+=" OIDC"
  grep -qi 'refresh-only'    "$DOC" || missing+=" refresh-only"
  if [ -z "$missing" ]; then
    ok "docs/pipeline.md mentions required concepts"
  else
    bad "docs/pipeline.md missing mentions:$missing"
  fi
fi

# ---- MODE=live extra ----
if [ "$MODE" = "live" ]; then
  if command -v aws >/dev/null 2>&1; then
    if aws sts get-caller-identity >/dev/null 2>&1; then
      ok "aws sts get-caller-identity works (host-level creds)"
    else
      bad "aws sts get-caller-identity failed; configure AWS CLI for live mode"
    fi
  else
    bad "aws CLI not installed (required for MODE=live)"
  fi
fi

echo
printf "%b" "$report"
echo
if [ "$fail" -eq 0 ]; then
  echo "RESULT: ALL CHECKS PASS ($pass/$pass)"
  exit 0
else
  echo "RESULT: $pass OK / $fail FAIL  ->  FAIL"
  exit 1
fi
