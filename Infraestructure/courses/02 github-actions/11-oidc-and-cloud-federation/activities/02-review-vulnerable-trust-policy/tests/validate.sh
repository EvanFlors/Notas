#!/usr/bin/env bash
# Validator for gha-11-02-review-vulnerable-trust-policy.
# NOTE: NOT using `set -o pipefail` with grep -q producers (SIGPIPE false positives).

BASE="${1:-${BASE_DIR:-/tmp/gha-oidc-audit}}"
PROJECT="$BASE/project"

pass=0
fail=0
report=""

ok()  { report+="  OK   -- $1\n"; pass=$((pass+1)); }
bad() { report+="  FAIL -- $1\n"; fail=$((fail+1)); }

echo "== Validating gha-11-02 audit under $PROJECT =="

if [ ! -d "$PROJECT" ]; then
  bad "project missing at $PROJECT (run starter/bootstrap.sh first)"
  echo
  printf "%b" "$report"
  echo
  echo "RESULT: $pass OK / $fail FAIL  ->  FAIL"
  exit 1
fi

AUDIT="$PROJECT/audit.md"
FIXES_DIR="$PROJECT/fixes"

check_fix() {
  local n="$1" rule="$2"
  local path="$FIXES_DIR/trust-policy-$n.json"
  if [ ! -f "$path" ]; then
    bad "fixes/trust-policy-$n.json missing"
    return
  fi
  local v
  v="$(RULE="$rule" python3 - "$path" <<'PY' 2>&1
import json, os, sys
path = sys.argv[1]
rule = os.environ["RULE"]
try:
    data = json.load(open(path))
except Exception as e:
    print(f"PARSE_ERROR: {e}")
    sys.exit(0)

issues = []
if data.get("Version") != "2012-10-17":
    issues.append(f"Version must be '2012-10-17' (got {data.get('Version')!r})")

stmts = data.get("Statement") or []
if not isinstance(stmts, list) or not stmts:
    issues.append("no Statement list")

found = False
for s in stmts or []:
    if s.get("Effect") != "Allow":
        continue
    act = s.get("Action")
    acts = act if isinstance(act, list) else [act]
    if "sts:AssumeRoleWithWebIdentity" not in acts:
        continue
    fed = (s.get("Principal") or {}).get("Federated", "")
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
                    if isinstance(val, str):
                        sub_val = val
    if not aud_ok:
        issues.append("missing aud=sts.amazonaws.com")
        continue
    if sub_val is None:
        issues.append("missing sub pin")
        continue
    # Universal safety checks
    if sub_val.startswith("repo:*"):
        issues.append(f"sub starts with 'repo:*' (owner wildcard): {sub_val}")
    parts = sub_val.split(":")
    if len(parts) >= 2 and "*" in parts[1]:
        issues.append(f"wildcard in owner/repo segment: {sub_val}")
    if sub_val.rstrip().endswith(":*"):
        issues.append(f"sub ends with ':*' (too permissive): {sub_val}")
    if ":environment:*" in sub_val:
        issues.append(f"environment:* wildcard not acceptable: {sub_val}")
    # Rule-specific
    if rule == "main_or_env":
        if ":ref:refs/heads/main" not in sub_val and ":environment:" not in sub_val:
            issues.append(f"fix 1 must pin to :ref:refs/heads/main or :environment:... (got {sub_val})")
    elif rule == "tag":
        if ":ref:refs/tags/" not in sub_val:
            issues.append(f"fix 2 must pin to :ref:refs/tags/... (got {sub_val})")
    elif rule == "branch":
        if ":ref:refs/heads/" not in sub_val:
            issues.append(f"fix 3 must pin to :ref:refs/heads/... (got {sub_val})")
        if ":pull_request" in sub_val:
            issues.append(f"fix 3 must not include :pull_request (got {sub_val})")
    elif rule == "env_exact":
        if ":environment:" not in sub_val:
            issues.append(f"fix 4 must pin to :environment:... (got {sub_val})")
        # must not be environment:*
        if sub_val.endswith(":environment:*"):
            issues.append(f"fix 4 must pin to an exact environment, not wildcard: {sub_val}")
    found = True
    break

if not found and not issues:
    issues.append("no Allow + AssumeRoleWithWebIdentity + GitHub OIDC statement found")

if issues:
    for i in issues:
        print(f"ISSUE: {i}")
else:
    print("OK")
PY
)"
  if printf '%s' "$v" | grep -q '^PARSE_ERROR'; then
    bad "fixes/trust-policy-$n.json invalid JSON: $(printf '%s' "$v")"
  elif printf '%s' "$v" | grep -q '^OK$'; then
    ok "fixes/trust-policy-$n.json: rule '$rule' passed"
  else
    bad "fixes/trust-policy-$n.json issues: $(printf '%s' "$v" | tr '\n' '|')"
  fi
}

check_fix 1 main_or_env
check_fix 2 tag
check_fix 3 branch
check_fix 4 env_exact

# audit.md checks
if [ ! -f "$AUDIT" ]; then
  bad "audit.md missing"
else
  ok "audit.md exists"
  missing=""
  for n in 1 2 3 4; do
    grep -q "trust-policy-$n" "$AUDIT" || missing+=" trust-policy-$n"
  done
  grep -qi 'VULNERABLE' "$AUDIT" || missing+=" VULNERABLE"
  grep -qi 'SAFE_BUT_WEAK' "$AUDIT" || missing+=" SAFE_BUT_WEAK"
  if [ -z "$missing" ]; then
    ok "audit.md mentions all 4 files and both classifications"
  else
    bad "audit.md missing mentions:$missing"
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
