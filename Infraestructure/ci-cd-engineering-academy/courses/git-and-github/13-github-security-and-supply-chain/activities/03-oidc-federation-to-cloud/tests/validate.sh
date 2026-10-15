#!/usr/bin/env bash
# Validator for gh-13-03-oidc-federation-to-cloud.
# NOT using `set -o pipefail` (SIGPIPE false positives with git/grep pipelines).

BASE="${1:-${BASE_DIR:-/tmp/oidc-fed}}"
MODE="${MODE:-local}"
PROJECT="$BASE/project"

pass=0
fail=0
report=""

ok()  { report+="  OK   — $1\n"; pass=$((pass+1)); }
bad() { report+="  FAIL — $1\n"; fail=$((fail+1)); }

echo "== Validating OIDC federation artifacts (MODE=$MODE) under $PROJECT =="

if [ ! -d "$PROJECT" ]; then
  bad "project missing at $PROJECT (run starter/bootstrap.sh first)"
  echo
  printf "%b" "$report"
  echo
  echo "RESULT: $pass OK / $fail FAIL  →  FAIL"
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
  # Parse + semantic checks via python3
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
    print("NO_STATEMENTS")
    sys.exit(0)

# Find a valid statement
found_valid = False
for s in stmts:
    if s.get("Effect") != "Allow":
        continue
    act = s.get("Action")
    acts = act if isinstance(act, list) else [act]
    if "sts:AssumeRoleWithWebIdentity" not in acts:
        continue
    princ = s.get("Principal", {})
    fed = princ.get("Federated", "")
    feds = fed if isinstance(fed, list) else [fed]
    if not any(f.endswith("/token.actions.githubusercontent.com") for f in feds):
        continue
    cond = s.get("Condition", {}) or {}
    # Build a flat map of all condition values across operators
    aud_ok = False
    sub_pin = None
    sub_wildcard_bad = False
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
                    if val.startswith("repo:"):
                        sub_pin = val
                        # Reject obvious wildcards right after the repo prefix.
                        # Allowed: repo:Org/Repo:ref:refs/heads/main
                        # Allowed: repo:Org/Repo:environment:production
                        # Rejected: repo:Org/*  or  repo:Org/Repo:*  (too permissive)
                        if val.startswith("repo:*") or "/*" in val.split(":")[1] if ":" in val else False:
                            sub_wildcard_bad = True
                        # Reject patterns that leave the repo name wildcarded
                        parts = val.split(":")
                        if len(parts) >= 2 and ("*" in parts[1] or parts[1].endswith("/*")):
                            sub_wildcard_bad = True
    if not aud_ok:
        issues.append("Condition is missing aud=sts.amazonaws.com for token.actions.githubusercontent.com")
    if sub_pin is None:
        issues.append("Condition is missing a sub pin starting with 'repo:'")
    if sub_wildcard_bad:
        issues.append(f"sub pin uses a dangerous wildcard: {sub_pin}")
    if aud_ok and sub_pin and not sub_wildcard_bad:
        found_valid = True
        break

if not found_valid and not issues:
    issues.append("no Statement with Effect=Allow + sts:AssumeRoleWithWebIdentity + GitHub OIDC Federated principal")

if issues:
    for i in issues:
        print(f"ISSUE: {i}")
else:
    print("OK")
PY
)"
  if printf '%s' "$verdict" | grep -q '^PARSE_ERROR'; then
    bad "trust-policy.json is not valid JSON: $(printf '%s' "$verdict")"
  elif printf '%s' "$verdict" | grep -q '^OK$'; then
    ok "trust-policy.json has correct structure, aud + sub pin"
  else
    bad "trust-policy.json structural issues: $(printf '%s' "$verdict" | tr '\n' '|' )"
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

jobs = (doc or {}).get("jobs") or {}
if not jobs:
    issues.append("no jobs defined")

# Find any permissions block (top-level or in a job) that has id-token: write
def perms_has_id_token_write(p):
    if not isinstance(p, dict): return False
    return str(p.get("id-token", "")).lower() == "write"

id_token_ok = perms_has_id_token_write((doc or {}).get("permissions") or {})
uses_cfg = False
has_role_to_assume = False
for jname, jbody in jobs.items():
    if not isinstance(jbody, dict): continue
    if perms_has_id_token_write(jbody.get("permissions") or {}):
        id_token_ok = True
    for step in (jbody.get("steps") or []):
        if not isinstance(step, dict): continue
        u = str(step.get("uses") or "")
        if u.startswith("aws-actions/configure-aws-credentials"):
            uses_cfg = True
            with_ = step.get("with") or {}
            if with_.get("role-to-assume"):
                has_role_to_assume = True

if not id_token_ok:
    issues.append("no 'permissions: id-token: write' at top-level or in any job")
if not uses_cfg:
    issues.append("no step uses aws-actions/configure-aws-credentials")
if not has_role_to_assume:
    issues.append("configure-aws-credentials step missing with.role-to-assume")

# Forbidden long-lived secret references
forbidden = [
    r"AKIA[0-9A-Z]{10,}",
    r"\$\{\{\s*secrets\.AWS_ACCESS_KEY_ID\s*\}\}",
    r"\$\{\{\s*secrets\.AWS_SECRET_ACCESS_KEY\s*\}\}",
]
for pat in forbidden:
    if re.search(pat, raw):
        issues.append(f"workflow contains forbidden long-lived credential ref: /{pat}/")

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
    ok "deploy.yml has id-token:write, configure-aws-credentials, no long-lived secrets"
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
  if [ -z "$missing" ]; then
    ok "docs/oidc.md mentions AssumeRoleWithWebIdentity, sub, OIDC provider"
  else
    bad "docs/oidc.md missing mentions:$missing"
  fi
fi

# ---------- MODE=live extra check ----------
if [ "$MODE" = "live" ]; then
  if command -v aws >/dev/null 2>&1; then
    if aws sts get-caller-identity >/dev/null 2>&1; then
      ok "aws sts get-caller-identity works (host-level creds; not the OIDC flow itself)"
    else
      bad "aws sts get-caller-identity failed; configure AWS CLI auth to exercise live mode"
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
  echo "RESULT: $pass OK / $fail FAIL  →  FAIL"
  exit 1
fi
