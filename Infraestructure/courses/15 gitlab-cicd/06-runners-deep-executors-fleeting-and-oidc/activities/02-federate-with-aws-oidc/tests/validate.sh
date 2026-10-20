#!/usr/bin/env bash
# Structural + light-semantic validation for gl-06-02-federate-with-aws-oidc.
# Checks that trust-policy.json, .gitlab-ci.yml and README-INTENT.md exist,
# parse, and encode the minimum pinning signals expected by the lesson
# (project_path + ref + aud in trust policy; id_tokens + assume-role-with-
# web-identity in pipeline; no static AWS creds; justification sections in
# the Markdown).
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness in a real AWS account.

set -eu

BASE="${1:-/tmp/gl-06-oidc}"
fail=0

echo "== Structural validation for $BASE =="

for cmd in jq python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "FAIL: '$cmd' is required but not installed."
    exit 2
  fi
done

check_file_exists() {
  local f="$1"
  if [ -f "$f" ]; then
    echo "  OK   $f exists"
    return 0
  else
    echo "  FAIL $f does not exist"
    fail=$((fail+1))
    return 1
  fi
}

check_jq() {
  local f="$1" expr="$2" label="$3"
  local val
  val=$(jq -r "$expr" "$f" 2>/dev/null || echo "")
  if [ "$val" = "true" ]; then
    echo "  OK   $f: ${label}"
  else
    echo "  FAIL $f: ${label} (expr: $expr)"
    fail=$((fail+1))
  fi
}

# --- trust-policy.json ---------------------------------------------------
TP="$BASE/trust-policy.json"
if check_file_exists "$TP"; then
  if jq empty "$TP" >/dev/null 2>&1; then
    echo "  OK   $TP is valid JSON"
  else
    echo "  FAIL $TP is not valid JSON"
    fail=$((fail+1))
  fi

  check_jq "$TP" '.Version == "2012-10-17"' 'Version == "2012-10-17"'
  check_jq "$TP" \
    '[.Statement[].Effect] | any(. == "Allow")' \
    'at least one Statement with Effect=Allow'
  check_jq "$TP" \
    '[.Statement[].Action // [] | if type=="string" then [.] else . end | .[]] | any(. == "sts:AssumeRoleWithWebIdentity")' \
    'denies/allows sts:AssumeRoleWithWebIdentity'
  check_jq "$TP" \
    '[.Statement[].Principal.Federated // [] | if type=="string" then [.] else . end | .[]] | any(test("oidc-provider/gitlab"; "i"))' \
    'Principal.Federated references a gitlab oidc-provider'
  # aud condition
  check_jq "$TP" \
    '[.Statement[].Condition // {} | .StringEquals // {} | to_entries[] | select(.key|test("aud";"i")) | .value] | length > 0' \
    'has StringEquals on a *:aud key'
  # sub condition — must contain project_path:acme/web AND ref:main
  check_jq "$TP" \
    '[.Statement[].Condition // {} | .StringLike // {} | to_entries[] | select(.key|test("sub";"i")) | .value | if type=="string" then [.] else . end | .[]] | any(test("project_path:acme/web"))' \
    'StringLike on sub pins project_path:acme/web'
  check_jq "$TP" \
    '[.Statement[].Condition // {} | .StringLike // {} | to_entries[] | select(.key|test("sub";"i")) | .value | if type=="string" then [.] else . end | .[]] | any(test("ref:main"))' \
    'StringLike on sub pins ref:main'
  # Reject bare wildcard
  if jq -r '[.Statement[].Condition // {} | .. | strings] | .[]' "$TP" 2>/dev/null | grep -Fxq "*"; then
    echo "  FAIL trust-policy.json contains a bare '*' value in a Condition (overly permissive)"
    fail=$((fail+1))
  else
    echo "  OK   trust-policy.json has no bare '*' Condition value"
  fi
fi

# --- .gitlab-ci.yml ------------------------------------------------------
CI="$BASE/.gitlab-ci.yml"
if check_file_exists "$CI"; then
  if python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" "$CI" 2>/dev/null; then
    echo "  OK   $CI is valid YAML"
  else
    echo "  FAIL $CI is not valid YAML"
    fail=$((fail+1))
  fi

  if python3 -c "
import yaml,sys
d=yaml.safe_load(open(sys.argv[1])) or {}
jobs=[v for k,v in d.items() if isinstance(v,dict) and 'script' in v]
assert jobs, 'no jobs'
oidc=[j for j in jobs if isinstance(j.get('id_tokens'), dict) and j['id_tokens']]
assert oidc, 'no job declares id_tokens'
# at least one id_token has aud
auds=[t.get('aud') for j in oidc for t in j['id_tokens'].values() if isinstance(t,dict)]
assert any(auds), 'no id_token declares aud'
# at least one job declares environment.name=production
envs=[j.get('environment') for j in oidc]
assert any(isinstance(e,dict) and e.get('name')=='production' for e in envs), 'no job declares environment.name=production'
" "$CI" 2>/dev/null; then
    echo "  OK   .gitlab-ci.yml declares id_tokens with aud and environment=production"
  else
    echo "  FAIL .gitlab-ci.yml missing id_tokens/aud/environment=production"
    fail=$((fail+1))
  fi

  if grep -qE 'assume-role-with-web-identity' "$CI"; then
    echo "  OK   .gitlab-ci.yml invokes assume-role-with-web-identity"
  else
    echo "  FAIL .gitlab-ci.yml does not invoke assume-role-with-web-identity"
    fail=$((fail+1))
  fi

  # Reject static credentials declared in variables:
  if grep -qE '^\s*AWS_ACCESS_KEY_ID\s*:' "$CI" || \
     grep -qE '^\s*AWS_SECRET_ACCESS_KEY\s*:' "$CI"; then
    echo "  FAIL .gitlab-ci.yml declares static AWS credentials in variables:"
    fail=$((fail+1))
  else
    echo "  OK   .gitlab-ci.yml does not declare static AWS credentials"
  fi
fi

# --- README-INTENT.md ----------------------------------------------------
DOC="$BASE/README-INTENT.md"
if check_file_exists "$DOC"; then
  for section in "Trust +policy" "Antipatrones" "Pipeline +consumidor"; do
    if grep -qiE "^#+ +.*${section}" "$DOC"; then
      echo "  OK   README-INTENT.md has section matching '${section}'"
    else
      echo "  FAIL README-INTENT.md missing section matching '${section}'"
      fail=$((fail+1))
    fi
  done
  if grep -qE 'StringLike' "$DOC" && grep -qE 'StringEquals' "$DOC"; then
    echo "  OK   README-INTENT.md discusses StringLike vs StringEquals"
  else
    echo "  FAIL README-INTENT.md does not discuss StringLike vs StringEquals"
    fail=$((fail+1))
  fi
  if grep -qE 'AssumeRoleWithWebIdentity' "$DOC"; then
    echo "  OK   README-INTENT.md mentions AssumeRoleWithWebIdentity"
  else
    echo "  FAIL README-INTENT.md does not mention AssumeRoleWithWebIdentity"
    fail=$((fail+1))
  fi
  if grep -qiE 'protected +environment|approval +rules?' "$DOC"; then
    echo "  OK   README-INTENT.md mentions protected environments or approval rules"
  else
    echo "  FAIL README-INTENT.md does not mention protected environments / approval rules"
    fail=$((fail+1))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  echo "        (Semantic correctness in a real AWS account is NOT verified here.)"
  exit 1
fi
echo "OK: OIDC artifacts pass structural validation."
echo "    Compara con solution/ para autoevaluarte."
exit 0
