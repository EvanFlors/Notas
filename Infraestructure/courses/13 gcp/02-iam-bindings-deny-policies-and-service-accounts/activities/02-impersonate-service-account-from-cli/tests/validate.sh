#!/usr/bin/env bash
# Structural validation for gcp-02-02-impersonate-service-account-from-cli.
#
# Checks that:
#   - token-creator-binding.yaml exists, parses as YAML (via python3), has a
#     binding with role=roles/iam.serviceAccountTokenCreator and the
#     platform-eng group as member (no user:... directly).
#   - IMPERSONATION-WALKTHROUGH.md exists with sections for flow, "NO SA key"
#     and audit; mentions the required gcloud commands, API names and audit
#     fields; does NOT contain SA key creation commands.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.

set -eu

BASE="${1:-/tmp/gcp-02-impersonate}"
fail=0

echo "== Structural validation for $BASE =="

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: 'python3' is required but not installed."
  exit 2
fi

if ! python3 -c "import yaml" >/dev/null 2>&1; then
  echo "FAIL: python3 'yaml' module (PyYAML) is required. Install with: pip install pyyaml"
  exit 2
fi

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

py_eval() {
  local f="$1"
  local expr="$2"
  local label="$3"
  local out
  out=$(python3 - "$f" <<PY 2>/dev/null || echo "ERROR"
import sys, yaml
with open(sys.argv[1]) as fh:
    data = yaml.safe_load(fh)
try:
    print("True" if (${expr}) else "False")
except Exception as e:
    print("ERROR")
PY
)
  if [ "$out" = "True" ]; then
    echo "  OK   $f: ${label}"
  else
    echo "  FAIL $f: ${label} (got: $out)"
    fail=$((fail+1))
  fi
}

# --- token-creator-binding.yaml -----------------------------------------
F1="$BASE/token-creator-binding.yaml"
if check_file_exists "$F1"; then
  py_eval "$F1" \
    'isinstance(data, dict) and isinstance(data.get("bindings"), list) and len(data["bindings"]) >= 1' \
    'top-level "bindings" is a non-empty list'

  py_eval "$F1" \
    'any(b.get("role") == "roles/iam.serviceAccountTokenCreator" for b in data["bindings"])' \
    'includes role roles/iam.serviceAccountTokenCreator'

  py_eval "$F1" \
    'any(any(isinstance(m,str) and m.startswith("group:") for m in (b.get("members") or [])) for b in data["bindings"] if b.get("role") == "roles/iam.serviceAccountTokenCreator")' \
    'tokenCreator binding uses a group: member (not user:)'

  py_eval "$F1" \
    'not any(any(isinstance(m,str) and m.startswith("user:") for m in (b.get("members") or [])) for b in data["bindings"])' \
    'no raw user:... members in bindings'
fi

# --- IMPERSONATION-WALKTHROUGH.md ---------------------------------------
DOC="$BASE/IMPERSONATION-WALKTHROUGH.md"
if check_file_exists "$DOC"; then
  # Section 1: flow / impersonation
  if grep -qiE '^#+ .*(flujo|flow).*(impersonation|impersonaci)' "$DOC" \
     || grep -qiE '^#+ .*impersonation' "$DOC"; then
    echo "  OK   has a 'flujo/flow of impersonation' section"
  else
    echo "  FAIL missing a flow / impersonation section"
    fail=$((fail+1))
  fi

  # Section 2: NO SA key
  if grep -qiE '^#+ .*(no +sa +key|no +sa-key|anti.?patron|anti.?pattern|por +qu[eé] +no)' "$DOC"; then
    echo "  OK   has a 'why NO SA key' section"
  else
    echo "  FAIL missing a 'why NO SA key / anti-patron' section"
    fail=$((fail+1))
  fi

  # Section 3: auditoria
  if grep -qiE '^#+ .*(auditor[ií]a|audit)' "$DOC"; then
    echo "  OK   has an 'auditoria' section"
  else
    echo "  FAIL missing an 'auditoria / audit' section"
    fail=$((fail+1))
  fi

  # Required mentions
  for token in \
    "gcloud auth login" \
    "impersonate-service-account" \
    "roles/iam.serviceAccountTokenCreator" \
    "iamcredentials.googleapis.com" \
    "iam.disableServiceAccountKeyCreation" \
    "Workload Identity Federation" \
    "serviceAccountDelegationInfo" \
    "principalEmail"
  do
    if grep -qF "$token" "$DOC"; then
      echo "  OK   mentions '$token'"
    else
      echo "  FAIL does not mention '$token'"
      fail=$((fail+1))
    fi
  done

  # Must NOT contain SA key creation commands (anti-pattern must not be taught).
  if grep -qE 'gcloud +iam +service-accounts +keys +create' "$DOC"; then
    echo "  FAIL contains 'gcloud iam service-accounts keys create' (SA key creation is an anti-pattern and must not appear as an instruction)"
    fail=$((fail+1))
  else
    echo "  OK   does not contain SA key creation command (good — this is an anti-pattern)"
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  echo "        (Semantic correctness in a real GCP project is NOT verified here.)"
  exit 1
fi
echo "OK: YAML + IMPERSONATION-WALKTHROUGH.md pasan validacion estructural."
echo "    Compara con solution/IMPERSONATION-WALKTHROUGH.md para autoevaluacion."
exit 0
