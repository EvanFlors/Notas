#!/usr/bin/env bash
# Structural + light-semantic validation for gcp-01-01-bootstrap-safe-project.
#
# Checks that the 3 artifacts exist, parse cleanly, and contain the minimum
# content required by the activity README: ADR-ish sections in the plan,
# minimal APIs in the enable script, well-formed budget YAML.
#
# Nota: deliberadamente NO usamos `set -o pipefail` porque los chequeos
# posteriores con `... | grep -q ...` pueden producir SIGPIPE (exit 141)
# cuando grep encuentra una coincidencia temprano; pipefail marcaria esos
# como fallos espurios.
#
# Does NOT grade semantic correctness in a real GCP account — compare
# manually with solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/gcp-01-bootstrap}"
fail=0

echo "== Structural validation for $BASE =="

PLAN="$BASE/bootstrap-plan.md"
SCRIPT="$BASE/enable-apis.sh"
BUDGET="$BASE/budget.yaml"

# ---------- bootstrap-plan.md ----------
if [ ! -f "$PLAN" ]; then
  echo "  FAIL $PLAN does not exist"
  fail=$((fail+1))
else
  echo "  OK   bootstrap-plan.md exists"

  for section in "Contexto" "Jerarquia" "Project" "APIs" "Billing" "Budget" "Labels" "Siguientes +pasos"; do
    label="${section% *}"
    if grep -qiE "^#+ +${section}\\b" "$PLAN"; then
      echo "  OK   plan has '${label}' section"
    else
      echo "  FAIL plan missing '${label}' section"
      fail=$((fail+1))
    fi
  done

  # Must mention AWS -> GCP mapping.
  if grep -qiE 'AWS|account|OU' "$PLAN"; then
    echo "  OK   plan mentions AWS mapping"
  else
    echo "  FAIL plan does not mention AWS mapping"
    fail=$((fail+1))
  fi

  # Must mention a European region.
  if grep -qiE 'europe-west1|europe-west4|europ' "$PLAN"; then
    echo "  OK   plan mentions a European region"
  else
    echo "  FAIL plan does not mention a European region"
    fail=$((fail+1))
  fi

  # Must mention Cloud Identity or MFA (human access).
  if grep -qiE 'Cloud +Identity|MFA|Multi-?Factor' "$PLAN"; then
    echo "  OK   plan mentions Cloud Identity / MFA"
  else
    echo "  FAIL plan does not mention Cloud Identity / MFA"
    fail=$((fail+1))
  fi

  # Must mention impersonation or iamcredentials (no-keys pattern).
  if grep -qiE 'impersonat|iamcredentials' "$PLAN"; then
    echo "  OK   plan mentions impersonation / iamcredentials"
  else
    echo "  FAIL plan does not mention impersonation / iamcredentials"
    fail=$((fail+1))
  fi

  # Must use placeholder my-project-123 (and NOT a real-looking projectId).
  if grep -q 'my-project-123' "$PLAN"; then
    echo "  OK   plan uses placeholder my-project-123"
  else
    echo "  FAIL plan does not use placeholder my-project-123"
    fail=$((fail+1))
  fi

  # Must name at least 3 obligatory labels.
  labels=0
  for l in "env" "app" "owner" "cost-center" "data-classification"; do
    if grep -qw "$l" "$PLAN"; then
      labels=$((labels+1))
    fi
  done
  if [ "$labels" -ge 3 ]; then
    echo "  OK   plan names at least 3 obligatory labels (${labels} found)"
  else
    echo "  FAIL plan names only ${labels} obligatory labels (expected >=3)"
    fail=$((fail+1))
  fi

  # Must mention a billing account placeholder.
  if grep -qE 'billingAccounts/' "$PLAN"; then
    echo "  OK   plan mentions billingAccounts/ placeholder"
  else
    echo "  FAIL plan does not mention billingAccounts/ placeholder"
    fail=$((fail+1))
  fi
fi

# ---------- enable-apis.sh ----------
if [ ! -f "$SCRIPT" ]; then
  echo "  FAIL $SCRIPT does not exist"
  fail=$((fail+1))
else
  echo "  OK   enable-apis.sh exists"

  # Shebang
  if head -n1 "$SCRIPT" | grep -qE '^#!.*(bash|sh)'; then
    echo "  OK   enable-apis.sh has a shebang"
  else
    echo "  FAIL enable-apis.sh missing shebang"
    fail=$((fail+1))
  fi

  # Executable
  if [ -x "$SCRIPT" ]; then
    echo "  OK   enable-apis.sh is executable (chmod +x)"
  else
    echo "  FAIL enable-apis.sh is not executable (chmod +x missing)"
    fail=$((fail+1))
  fi

  # Syntactically valid bash
  if bash -n "$SCRIPT" 2>/dev/null; then
    echo "  OK   enable-apis.sh is syntactically valid bash"
  else
    echo "  FAIL enable-apis.sh has bash syntax errors"
    fail=$((fail+1))
  fi

  # set -eu (and NOT pipefail)
  if grep -qE '^set +-eu' "$SCRIPT"; then
    echo "  OK   enable-apis.sh uses 'set -eu'"
  else
    echo "  FAIL enable-apis.sh does not use 'set -eu'"
    fail=$((fail+1))
  fi
  if grep -qE '^[[:space:]]*set +-o +pipefail|^[[:space:]]*set +-[a-z]*o +pipefail|^[[:space:]]*set +-[a-z]*e[a-z]*u[a-z]*o +pipefail' "$SCRIPT"; then
    echo "  FAIL enable-apis.sh enables pipefail (should NOT; SIGPIPE risk)"
    fail=$((fail+1))
  else
    echo "  OK   enable-apis.sh does not enable pipefail"
  fi

  # Must use gcloud services enable
  if grep -qE 'gcloud +services +enable' "$SCRIPT"; then
    echo "  OK   enable-apis.sh calls 'gcloud services enable'"
  else
    echo "  FAIL enable-apis.sh does not call 'gcloud services enable'"
    fail=$((fail+1))
  fi

  # Minimal APIs
  for api in \
      "cloudresourcemanager.googleapis.com" \
      "iam.googleapis.com" \
      "iamcredentials.googleapis.com" \
      "serviceusage.googleapis.com" \
      "cloudbilling.googleapis.com" \
      "logging.googleapis.com" \
      "monitoring.googleapis.com"; do
    if grep -qF "$api" "$SCRIPT"; then
      echo "  OK   enable-apis.sh references ${api}"
    else
      echo "  FAIL enable-apis.sh missing ${api}"
      fail=$((fail+1))
    fi
  done

  # Must use my-project-123 placeholder (not a different numeric suffix like my-project-456)
  if grep -q 'my-project-123' "$SCRIPT"; then
    echo "  OK   enable-apis.sh uses placeholder my-project-123"
  else
    echo "  FAIL enable-apis.sh does not use placeholder my-project-123"
    fail=$((fail+1))
  fi
  if grep -qE 'my-project-[0-9]+' "$SCRIPT" \
      && grep -qE 'my-project-[0-9]+' "$SCRIPT" \
      | grep -vqE 'my-project-123'; then
    # The above awkward check is a safety net; a cleaner guard:
    other=$(grep -oE 'my-project-[0-9]+' "$SCRIPT" | sort -u | grep -v '^my-project-123$' | head -n1 || true)
    if [ -n "$other" ]; then
      echo "  FAIL enable-apis.sh uses a non-placeholder projectId: ${other}"
      fail=$((fail+1))
    fi
  fi
fi

# ---------- budget.yaml ----------
if [ ! -f "$BUDGET" ]; then
  echo "  FAIL $BUDGET does not exist"
  fail=$((fail+1))
else
  echo "  OK   budget.yaml exists"

  if ! command -v python3 >/dev/null 2>&1; then
    echo "  FAIL python3 required for YAML validation"
    fail=$((fail+1))
  else
    # Validate YAML + semantic checks via a single python invocation.
    out=$(python3 - "$BUDGET" <<'PY'
import sys, yaml
path = sys.argv[1]
try:
    with open(path) as f:
        d = yaml.safe_load(f)
except Exception as e:
    print(f"PARSE_FAIL: {e}")
    sys.exit(0)
if not isinstance(d, dict):
    print("ROOT_FAIL: budget.yaml root is not a mapping")
    sys.exit(0)
def ok(cond, msg):
    print(("OK:" if cond else "FAIL:") + " " + msg)
ok(isinstance(d.get("displayName"), str) and d["displayName"].strip(),
   "displayName is a non-empty string")
bf = d.get("budgetFilter") or {}
projects = bf.get("projects") or []
ok("projects/my-project-123" in projects,
   "budgetFilter.projects contains 'projects/my-project-123'")
amt = (d.get("amount") or {}).get("specifiedAmount") or {}
ok(amt.get("currencyCode") == "USD",
   "amount.specifiedAmount.currencyCode == 'USD'")
ok(str(amt.get("units")) == "100",
   "amount.specifiedAmount.units == '100'")
rules = d.get("thresholdRules") or []
ok(isinstance(rules, list) and len(rules) >= 3,
   f"thresholdRules has at least 3 entries (found {len(rules)})")
bases = {r.get("spendBasis") for r in rules if isinstance(r, dict)}
ok("CURRENT_SPEND" in bases,
   "at least one thresholdRule with spendBasis=CURRENT_SPEND")
ok("FORECASTED_SPEND" in bases,
   "at least one thresholdRule with spendBasis=FORECASTED_SPEND")
nr = d.get("notificationsRule") or {}
topic = nr.get("pubsubTopic") or ""
ok(topic.startswith("projects/my-project-123/topics/"),
   f"notificationsRule.pubsubTopic looks like projects/my-project-123/topics/* (got '{topic}')")
PY
)
    printf '%s\n' "$out" | while IFS= read -r line; do
      case "$line" in
        OK:*)   echo "  OK   ${line#OK: }" ;;
        FAIL:*|PARSE_FAIL:*|ROOT_FAIL:*) echo "  FAIL ${line#*: }" ;;
      esac
    done
    if printf '%s\n' "$out" | grep -qE '^(FAIL|PARSE_FAIL|ROOT_FAIL):'; then
      count=$(printf '%s\n' "$out" | grep -cE '^(FAIL|PARSE_FAIL|ROOT_FAIL):')
      fail=$((fail+count))
    fi
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  echo "        (Semantic correctness in GCP is NOT verified here. Compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: bootstrap-plan.md + enable-apis.sh + budget.yaml pasan validacion estructural."
echo "    Compara con solution/REFERENCE.md para autoevaluacion semantica."
exit 0
