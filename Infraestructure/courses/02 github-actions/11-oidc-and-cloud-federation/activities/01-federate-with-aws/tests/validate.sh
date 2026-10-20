#!/usr/bin/env bash
# Validator for gha-11-01-federate-with-aws.
# NOTE: NOT using `set -o pipefail` with grep -q producers (SIGPIPE false positives).

BASE="${1:-${BASE_DIR:-/tmp/gha-oidc}}"
MODE="${MODE:-local}"
PROJECT="$BASE/project"

pass=0
fail=0
report=""

ok()  { report+="  OK   -- $1\n"; pass=$((pass+1)); }
bad() { report+="  FAIL -- $1\n"; fail=$((fail+1)); }

echo "== Validating gha-11-01 OIDC federation (MODE=$MODE) under $PROJECT =="

if [ ! -d "$PROJECT" ]; then
  bad "project missing at $PROJECT (run starter/bootstrap.sh first)"
  echo
  printf "%b" "$report"
  echo
  echo "RESULT: $pass OK / $fail FAIL  ->  FAIL"
  exit 1
fi

TRUST="$PROJECT/trust-policy.json"
WF="$PROJECT/.github/workflows/deploy.yml"
DOC="$PROJECT/docs/oidc.md"

# ---------- trust-policy.json ----------
if [ ! -f "$TRUST" ]; then
  bad "trust-policy.json missing"
else
  ok "trust-policy.json exists"
  verdict="$(python3 - "$TRUST" <<'PY' 2>&1
import json, sys
path = sys.argv[1]
try:
    data = json.load(open(path))
except Exception as e:
    print(f"PARSE_ERROR: {e}")
    sys.exit(1)

issues = []

if data.get("Version") != "2012-10-17":
    issues.append(f"Version must be '2012-10-17' (got {data.get('Version')!r})")

stmts = data.get("Statement") or []
if not isinstance(stmts, list) or not stmts:
    issues.append("Statement is empty or not a list")

found_valid = False
for s in stmts or []:
    if s.get("Effect") != "Allow":
        continue
    act = s.get("Action")
    acts = act if isinstance(act, list) else [act]
    if "sts:AssumeRoleWithWebIdentity" not in acts:
        continue
    princ = s.get("Principal", {}) or {}
    fed = princ.get("Federated", "")
    feds = fed if isinstance(fed, list) else [fed]
    if not any(isinstance(f, str) and f.endswith("/token.actions.githubusercontent.com") for f in feds):
        continue
    cond = s.get("Condition", {}) or {}
    aud_ok = False
    sub_pin = None
    sub_wildcard_bad = False
    sub_has_env = False
    for op, kv in cond.items():
        if not isinstance(kv, dict):
            continue
        for k, v in kv.items():
            vals = v if isinstance(v, list) else [v]
            if k == "token.actions.githubusercontent.com:aud":
                if "sts.amazonaws.com" in vals:
                    aud_ok = True
            if k == "token.actions.githubusercontent.com:sub":
                for val in vals:
                    if not isinstance(val, str):
                        continue
                    if val.startswith("repo:"):
                        sub_pin = val
                        parts = val.split(":")
                        # dangerous: repo:* or wildcard in owner/repo segment
                        if val.startswith("repo:*"):
                            sub_wildcard_bad = True
                        if len(parts) >= 2 and ("*" in parts[1]):
                            sub_wildcard_bad = True
                        # dangerous: repo:Org/Repo:*
                        if val.rstrip().endswith(":*"):
                            sub_wildcard_bad = True
                        if ":environment:" in val:
                            sub_has_env = True
    if not aud_ok:
        issues.append("Condition missing aud=sts.amazonaws.com")
    if sub_pin is None:
        issues.append("Condition missing a sub pin starting with 'repo:'")
    if sub_wildcard_bad:
        issues.append(f"sub pin uses dangerous wildcard: {sub_pin}")
    if sub_pin and not sub_has_env:
        issues.append(f"sub pin should include ':environment:' for prod (got {sub_pin})")
    if aud_ok and sub_pin and not sub_wildcard_bad and sub_has_env:
        found_valid = True
        break

if not found_valid and not issues:
    issues.append("no valid Allow statement for sts:AssumeRoleWithWebIdentity + GitHub OIDC")

if issues:
    for i in issues:
        print(f"ISSUE: {i}")
else:
    print("OK")
PY
)"
  if printf '%s' "$verdict" | grep -q '^PARSE_ERROR'; then
    bad "trust-policy.json invalid JSON: $(printf '%s' "$verdict")"
  elif printf '%s' "$verdict" | grep -q '^OK$'; then
    ok "trust-policy.json: valid, aud ok, sub pinned to :environment:"
  else
    bad "trust-policy.json issues: $(printf '%s' "$verdict" | tr '\n' '|')"
  fi
fi

# ---------- deploy.yml ----------
if [ ! -f "$WF" ]; then
  bad "workflow .github/workflows/deploy.yml missing"
else
  ok "workflow deploy.yml exists"
  wf_verdict="$(python3 - "$WF" <<'PY' 2>&1
import yaml, sys, re
path = sys.argv[1]
raw = open(path).read()
try:
    doc = yaml.safe_load(raw)
except Exception as e:
    print(f"PARSE_ERROR: {e}")
    sys.exit(0)

issues = []
if not isinstance(doc, dict):
    issues.append("workflow root is not a mapping")
    print("\n".join(f"ISSUE: {i}" for i in issues)); sys.exit(0)

# top-level permissions must be restrictive: {} or contents:read only
top_perms = doc.get("permissions")
if top_perms is None:
    # Omitted is NOT equivalent to {}, it means "default", which includes some scopes.
    # We require an explicit restrictive declaration.
    issues.append("top-level 'permissions:' must be declared explicitly ({} or contents: read)")
elif isinstance(top_perms, str):
    if top_perms.lower() == "write-all":
        issues.append("top-level 'permissions: write-all' is forbidden")
elif isinstance(top_perms, dict):
    if str(top_perms.get("id-token", "")).lower() == "write":
        issues.append("top-level 'id-token: write' not allowed; put it inside the job only")
    # allow {} or {contents: read} (and nothing else write)
    for k, v in top_perms.items():
        if str(v).lower() == "write" and k != "contents":
            issues.append(f"top-level permission '{k}: write' not allowed; restrict to {{}} or contents: read")

jobs = doc.get("jobs") or {}
if not jobs:
    issues.append("no jobs defined")

id_token_in_job = False
uses_cfg = False
has_role_to_assume = False
job_has_environment = False
for jname, jbody in jobs.items():
    if not isinstance(jbody, dict):
        continue
    jp = jbody.get("permissions")
    if isinstance(jp, dict) and str(jp.get("id-token", "")).lower() == "write":
        id_token_in_job = True
    if "environment" in jbody:
        job_has_environment = True
    for step in (jbody.get("steps") or []):
        if not isinstance(step, dict):
            continue
        u = str(step.get("uses") or "")
        if u.startswith("aws-actions/configure-aws-credentials"):
            uses_cfg = True
            with_ = step.get("with") or {}
            if with_.get("role-to-assume"):
                has_role_to_assume = True

if not id_token_in_job:
    issues.append("no job declares 'permissions: id-token: write'")
if not uses_cfg:
    issues.append("no step uses aws-actions/configure-aws-credentials")
if not has_role_to_assume:
    issues.append("configure-aws-credentials step missing with.role-to-assume")
if not job_has_environment:
    issues.append("no job declares 'environment:' (recommended for prod OIDC)")

# forbidden long-lived creds
forbidden = [
    (r"AKIA[0-9A-Z]{10,}", "AKIA access key id"),
    (r"\$\{\{\s*secrets\.AWS_ACCESS_KEY_ID\s*\}\}", "secrets.AWS_ACCESS_KEY_ID"),
    (r"\$\{\{\s*secrets\.AWS_SECRET_ACCESS_KEY\s*\}\}", "secrets.AWS_SECRET_ACCESS_KEY"),
    (r"permissions:\s*write-all", "permissions: write-all"),
]
for pat, label in forbidden:
    if re.search(pat, raw):
        issues.append(f"workflow contains forbidden pattern: {label}")

if issues:
    for i in issues:
        print(f"ISSUE: {i}")
else:
    print("OK")
PY
)"
  if printf '%s' "$wf_verdict" | grep -q '^PARSE_ERROR'; then
    bad "deploy.yml invalid YAML: $(printf '%s' "$wf_verdict")"
  elif printf '%s' "$wf_verdict" | grep -q '^OK$'; then
    ok "deploy.yml: id-token in job, environment set, no long-lived secrets"
  else
    bad "deploy.yml issues: $(printf '%s' "$wf_verdict" | tr '\n' '|')"
  fi
fi

# ---------- docs/oidc.md ----------
if [ ! -f "$DOC" ]; then
  bad "docs/oidc.md missing"
else
  ok "docs/oidc.md exists"
  missing=""
  grep -qi 'AssumeRoleWithWebIdentity' "$DOC" || missing+=" AssumeRoleWithWebIdentity"
  grep -qi 'sub' "$DOC" || missing+=" sub"
  grep -qi 'OIDC provider' "$DOC" || missing+=" 'OIDC provider'"
  grep -qi 'environment' "$DOC" || missing+=" environment"
  if [ -z "$missing" ]; then
    ok "docs/oidc.md mentions required concepts"
  else
    bad "docs/oidc.md missing mentions:$missing"
  fi
fi

# ---------- MODE=live extra ----------
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
