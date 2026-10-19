#!/usr/bin/env bash
# Structural validation for gcp-03-01-shared-vpc-host-and-service.
# Checks that ADR-SHARED-VPC.md and firewall-rules.json exist and carry the
# minimum content required by the activity.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/gcp-03-shared-vpc}"
ADR="$BASE/ADR-SHARED-VPC.md"
FW="$BASE/firewall-rules.json"
fail=0

echo "== Structural validation for $BASE =="

if ! command -v jq >/dev/null 2>&1; then
  echo "FAIL: 'jq' is required but not installed."
  exit 2
fi

# --- ADR-SHARED-VPC.md ---------------------------------------------------
if [ ! -f "$ADR" ]; then
  echo "FAIL: $ADR does not exist. Student must produce it."
  fail=$((fail+1))
else
  echo "  OK   $ADR exists"

  if grep -qiE '^#+ *ADR' "$ADR"; then
    echo "  OK   ADR heading present"
  else
    echo "  FAIL ADR heading missing"
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

  # At least one fenced code block (diagram).
  fences=$(grep -cE '^```' "$ADR")
  if [ "$fences" -ge 2 ]; then
    echo "  OK   ADR has at least one fenced code block (${fences} fence lines)"
  else
    echo "  FAIL ADR has only ${fences} code-fence lines (expected >=2)"
    fail=$((fail+1))
  fi

  # Must mention Shared VPC and either Cloud NAT or Private Google Access.
  if grep -qiE 'Shared +VPC|xpnAdmin|networkUser' "$ADR"; then
    echo "  OK   ADR mentions Shared VPC (or xpnAdmin / networkUser)"
  else
    echo "  FAIL ADR does not mention Shared VPC / xpnAdmin / networkUser"
    fail=$((fail+1))
  fi

  if grep -qiE 'Cloud +NAT|Private +Google +Access|PGA\b' "$ADR"; then
    echo "  OK   ADR mentions Cloud NAT or Private Google Access"
  else
    echo "  FAIL ADR does not mention Cloud NAT nor Private Google Access"
    fail=$((fail+1))
  fi

  # Must mention 'service account' pattern explicitly.
  if grep -qiE 'service +account|serviceAccount|SA\b' "$ADR"; then
    echo "  OK   ADR mentions service account pattern"
  else
    echo "  FAIL ADR does not mention service account pattern"
    fail=$((fail+1))
  fi

  # Must mention at least 2 European regions.
  eu_regions=0
  for r in "europe-west1" "europe-west2" "europe-west3" "europe-west4" \
           "europe-west6" "europe-central2" "europe-north1" "europe-southwest1"; do
    if grep -qi "$r" "$ADR"; then
      eu_regions=$((eu_regions+1))
    fi
  done
  if [ "$eu_regions" -ge 2 ]; then
    echo "  OK   ADR mentions >=2 European regions (${eu_regions} tokens)"
  else
    echo "  FAIL ADR mentions only ${eu_regions} European region token(s) (expected >=2)"
    fail=$((fail+1))
  fi

  # Must mention at least one CIDR like 10.x.x.x/NN.
  if grep -qE '10\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+' "$ADR"; then
    echo "  OK   ADR mentions a CIDR (10.x.x.x/NN)"
  else
    echo "  FAIL ADR does not mention a CIDR"
    fail=$((fail+1))
  fi

  # Must name at least 3 project tokens (host + >=2 service projects).
  projs=0
  for p in "net-host" "host-prod" "checkout-prod" "checkout" "analytics-prod" \
           "analytics" "shared-vpc"; do
    if grep -qi "$p" "$ADR"; then
      projs=$((projs+1))
    fi
  done
  if [ "$projs" -ge 3 ]; then
    echo "  OK   ADR names >=3 project / workload tokens (${projs})"
  else
    echo "  FAIL ADR names only ${projs} project tokens (expected >=3)"
    fail=$((fail+1))
  fi

  # Must mention the 'firewall rule by SA vs tag' trade-off (one of the
  # keywords is enough).
  if grep -qiE 'targetServiceAccount|sourceServiceAccount|por +service +account|por +SA|vs +tag|frente +a +tag' "$ADR"; then
    echo "  OK   ADR discusses firewall-by-SA pattern"
  else
    echo "  FAIL ADR does not discuss firewall-by-SA pattern"
    fail=$((fail+1))
  fi

  # Alternatives: at least 2 subheadings or 2 numbered items.
  alt_items=$(grep -cEi '^#+ +(Alt|Opci[oó]n|Alternativa)' "$ADR" || true)
  alt_num=$(grep -cE '^[[:space:]]*[12]\. ' "$ADR" || true)
  if [ "$alt_items" -ge 2 ] || [ "$alt_num" -ge 2 ]; then
    echo "  OK   ADR lists >=2 alternatives"
  else
    echo "  FAIL ADR lists fewer than 2 alternatives"
    fail=$((fail+1))
  fi
fi

# --- firewall-rules.json -------------------------------------------------
if [ ! -f "$FW" ]; then
  echo "FAIL: $FW does not exist. Student must produce it."
  fail=$((fail+1))
else
  echo "  OK   $FW exists"

  if jq empty "$FW" >/dev/null 2>&1; then
    echo "  OK   $FW is valid JSON"
  else
    echo "  FAIL $FW is not valid JSON"
    fail=$((fail+1))
  fi

  # Must be an array with >=3 elements.
  n=$(jq 'if type == "array" then length else -1 end' "$FW" 2>/dev/null || echo "-1")
  if [ "$n" -ge 3 ]; then
    echo "  OK   $FW is an array with >=3 rules (${n})"
  else
    echo "  FAIL $FW is not an array with >=3 rules (got ${n})"
    fail=$((fail+1))
  fi

  # Every rule has 'name' and 'direction'.
  missing=$(jq '[.[] | select((has("name") | not) or (has("direction") | not))] | length' "$FW" 2>/dev/null || echo "99")
  if [ "$missing" = "0" ]; then
    echo "  OK   every rule has 'name' and 'direction'"
  else
    echo "  FAIL ${missing} rule(s) missing 'name' or 'direction'"
    fail=$((fail+1))
  fi

  # At least one rule with targetServiceAccounts (SA pattern practiced).
  has_sa=$(jq '[.[] | select(has("targetServiceAccounts"))] | length' "$FW" 2>/dev/null || echo "0")
  if [ "$has_sa" -ge 1 ]; then
    echo "  OK   at least one rule uses targetServiceAccounts (${has_sa})"
  else
    echo "  FAIL no rule uses targetServiceAccounts"
    fail=$((fail+1))
  fi

  # At least one rule references the LB health-check ranges.
  has_hc=$(jq '[.[] | select((.sourceRanges // []) | any(. == "35.191.0.0/16" or . == "130.211.0.0/22"))] | length' "$FW" 2>/dev/null || echo "0")
  if [ "$has_hc" -ge 1 ]; then
    echo "  OK   at least one rule references LB health-check ranges"
  else
    echo "  FAIL no rule references 35.191.0.0/16 or 130.211.0.0/22"
    fail=$((fail+1))
  fi

  # At least one EGRESS rule.
  has_eg=$(jq '[.[] | select(.direction == "EGRESS")] | length' "$FW" 2>/dev/null || echo "0")
  if [ "$has_eg" -ge 1 ]; then
    echo "  OK   at least one EGRESS rule (${has_eg})"
  else
    echo "  FAIL no EGRESS rule found"
    fail=$((fail+1))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail issue(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: 0 issue(s). Estructura valida. Compara con solution/REFERENCE.md para autoevaluarte."
exit 0
