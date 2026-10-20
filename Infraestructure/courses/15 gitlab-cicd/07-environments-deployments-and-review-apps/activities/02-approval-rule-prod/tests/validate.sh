#!/usr/bin/env bash
# Structural validation for gl-07-02-approval-rule-prod.
# Checks that protected-environment.yaml and approval-rules.yaml parse as
# YAML with the required keys, and that ADR-APPROVAL-PROD.md has the
# required sections and keywords.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness in a real GitLab project — compare
# manually with solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/gl-07-02-approval-prod}"
PE="$BASE/protected-environment.yaml"
AR="$BASE/approval-rules.yaml"
ADR="$BASE/ADR-APPROVAL-PROD.md"
fail=0

echo "== Structural validation for $BASE =="

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: 'python3' is required but not installed."
  exit 2
fi

if ! python3 -c 'import yaml' >/dev/null 2>&1; then
  echo "FAIL: python3 'yaml' module (pyyaml) is required. Install with: pip install pyyaml"
  exit 2
fi

# --- protected-environment.yaml ------------------------------------------

if [ ! -f "$PE" ]; then
  echo "  FAIL $PE does not exist"
  fail=$((fail+1))
else
  echo "  OK   $PE exists"

  if python3 -c "import yaml; yaml.safe_load(open('$PE'))" >/dev/null 2>&1; then
    echo "  OK   $PE parses as valid YAML"
  else
    echo "  FAIL $PE is not valid YAML"
    fail=$((fail+1))
  fi

  pe_ok=$(python3 - "$PE" <<'PY' 2>/dev/null || echo "FAIL"
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1]))
if not isinstance(doc, dict):
    print("FAIL"); sys.exit(0)
if doc.get("name") != "production":
    print("FAIL-name"); sys.exit(0)
if doc.get("deployment_tier") != "production":
    print("FAIL-tier"); sys.exit(0)
dal = doc.get("deploy_access_levels")
if not isinstance(dal, list) or len(dal) < 1:
    print("FAIL-dal-list"); sys.exit(0)
has_group = any(isinstance(x, dict) and "group" in x for x in dal)
if not has_group:
    print("FAIL-dal-group"); sys.exit(0)
print("OK")
PY
)
  if [ "$pe_ok" = "OK" ]; then
    echo "  OK   $PE: name=production, deployment_tier=production, deploy_access_levels has a group"
  else
    echo "  FAIL $PE: expected name=production, deployment_tier=production, deploy_access_levels with at least one group entry ($pe_ok)"
    fail=$((fail+1))
  fi
fi

# --- approval-rules.yaml -------------------------------------------------

if [ ! -f "$AR" ]; then
  echo "  FAIL $AR does not exist"
  fail=$((fail+1))
else
  echo "  OK   $AR exists"

  if python3 -c "import yaml; yaml.safe_load(open('$AR'))" >/dev/null 2>&1; then
    echo "  OK   $AR parses as valid YAML"
  else
    echo "  FAIL $AR is not valid YAML"
    fail=$((fail+1))
  fi

  ar_ok=$(python3 - "$AR" <<'PY' 2>/dev/null || echo "FAIL"
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1]))
if not isinstance(doc, dict):
    print("FAIL"); sys.exit(0)
if doc.get("environment") != "production":
    print("FAIL-env"); sys.exit(0)
rules = doc.get("approval_rules")
if not isinstance(rules, list) or len(rules) < 2:
    print("FAIL-rules-count"); sys.exit(0)
groups = {}
for r in rules:
    if not isinstance(r, dict):
        continue
    g = r.get("group")
    req = r.get("required_approvals")
    if isinstance(g, str) and isinstance(req, int) and req >= 1:
        groups[g] = req
if "sre" not in groups:
    print("FAIL-sre"); sys.exit(0)
if "security" not in groups:
    print("FAIL-security"); sys.exit(0)
print("OK")
PY
)
  if [ "$ar_ok" = "OK" ]; then
    echo "  OK   $AR: environment=production, approval_rules include sre (>=1) and security (>=1)"
  else
    echo "  FAIL $AR: expected environment=production and approval_rules with group=sre and group=security each required_approvals>=1 ($ar_ok)"
    fail=$((fail+1))
  fi
fi

# --- ADR-APPROVAL-PROD.md ------------------------------------------------

if [ ! -f "$ADR" ]; then
  echo "  FAIL $ADR does not exist"
  fail=$((fail+1))
else
  echo "  OK   $ADR exists"

  if grep -qiE '^#+ *ADR' "$ADR"; then
    echo "  OK   ADR heading present"
  else
    echo "  FAIL ADR heading missing (expected '# ADR ...')"
    fail=$((fail+1))
  fi

  for section in "Estado|Status" "Contexto|Context" "Decisi[oó]n|Decision" \
                 "Consecuencias|Consequences" "Alternativas|Alternatives"; do
    label="${section%%|*}"
    if grep -qiE "^#+ *(${section})\\b" "$ADR"; then
      echo "  OK   ADR has '${label}' section"
    else
      echo "  FAIL ADR missing '${label}' section"
      fail=$((fail+1))
    fi
  done

  fences=$(grep -cE '^```' "$ADR")
  if [ "$fences" -ge 2 ]; then
    echo "  OK   ADR has at least one fenced code block (${fences} fence lines)"
  else
    echo "  FAIL ADR has only ${fences} fence lines (expected >=2)"
    fail=$((fail+1))
  fi

  for kw in "protected environment" "approval rule" "deploy_access_levels" "sre" "security"; do
    if grep -qi "$kw" "$ADR"; then
      echo "  OK   ADR mentions '${kw}'"
    else
      echo "  FAIL ADR does not mention '${kw}'"
      fail=$((fail+1))
    fi
  done

  # Must contrast pipeline rules vs approval rules.
  if grep -qiE 'rules.*(pipeline|job)|pipeline.*rules|rules:.*vs' "$ADR"; then
    echo "  OK   ADR distinguishes pipeline rules from approval rules"
  else
    echo "  FAIL ADR does not clearly distinguish 'rules:' (pipeline) from approval rules"
    fail=$((fail+1))
  fi

  # Must mention GitHub Actions as comparison.
  if grep -qiE 'GitHub +Actions|GHA\b' "$ADR"; then
    echo "  OK   ADR compares against GitHub Actions / GHA"
  else
    echo "  FAIL ADR does not reference GitHub Actions / GHA as alternative"
    fail=$((fail+1))
  fi

  alt_items=$(grep -cEi '^#+ +(Alt|Opci[oó]n|Alternativa)' "$ADR" || true)
  alt_num=$(grep -cE '^[[:space:]]*[12]\. ' "$ADR" || true)
  if [ "$alt_items" -ge 2 ] || [ "$alt_num" -ge 2 ]; then
    echo "  OK   ADR has at least 2 alternatives listed"
  else
    echo "  FAIL ADR has fewer than 2 alternatives (expected >=2 sub-headings or numbered items)"
    fail=$((fail+1))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail issue(s) found."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: 0 issue(s). Compara con solution/REFERENCE.md para autoevaluarte."
exit 0
