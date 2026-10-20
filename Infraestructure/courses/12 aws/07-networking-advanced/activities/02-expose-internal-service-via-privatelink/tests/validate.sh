#!/usr/bin/env bash
# Structural validation for aws-07-02-expose-internal-service-via-privatelink.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/aws-07-privatelink}"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -d "$BASE" ]; then
  echo "FAIL $BASE does not exist."
  exit 1
fi

# --- Producer module -------------------------------------------------------
if [ -d "$BASE/producer" ]; then
  echo "  OK   producer/ exists"
  PROD_HCL=$(mktemp)
  trap 'rm -f "$PROD_HCL" "${CONS_HCL:-}"' EXIT
  cat "$BASE"/producer/*.tf > "$PROD_HCL" 2>/dev/null || true

  for pat in '"aws_lb"' 'load_balancer_type[[:space:]]*=[[:space:]]*"network"' \
             '"aws_vpc_endpoint_service"' '"aws_vpc_endpoint_service_allowed_principal"' \
             'network_load_balancer_arns'; do
    if grep -qE "$pat" "$PROD_HCL"; then
      echo "  OK   producer HCL contains $pat"
    else
      echo "  FAIL producer HCL missing $pat"
      fail=$((fail+1))
    fi
  done

  if grep -qE 'acceptance_required[[:space:]]*=' "$PROD_HCL"; then
    echo "  OK   producer declares acceptance_required"
  else
    echo "  FAIL producer missing acceptance_required declaration"
    fail=$((fail+1))
  fi

  if grep -q 'skip_credentials_validation' "$PROD_HCL"; then
    echo "  OK   producer provider is offline-safe"
  else
    echo "  FAIL producer provider not configured for offline plan"
    fail=$((fail+1))
  fi
else
  echo "  FAIL $BASE/producer missing"
  fail=$((fail+1))
fi

# --- Consumer module -------------------------------------------------------
if [ -d "$BASE/consumer" ]; then
  echo "  OK   consumer/ exists"
  CONS_HCL=$(mktemp)
  cat "$BASE"/consumer/*.tf > "$CONS_HCL" 2>/dev/null || true

  for pat in '"aws_vpc_endpoint"' 'vpc_endpoint_type[[:space:]]*=[[:space:]]*"Interface"' \
             'service_name' 'private_dns_enabled'; do
    if grep -qE "$pat" "$CONS_HCL"; then
      echo "  OK   consumer HCL contains $pat"
    else
      echo "  FAIL consumer HCL missing $pat"
      fail=$((fail+1))
    fi
  done

  if grep -q 'skip_credentials_validation' "$CONS_HCL"; then
    echo "  OK   consumer provider is offline-safe"
  else
    echo "  FAIL consumer provider not configured for offline plan"
    fail=$((fail+1))
  fi
else
  echo "  FAIL $BASE/consumer missing"
  fail=$((fail+1))
fi

# No real-looking Account IDs across all .tf (allow the placeholder 012345678901).
ALL_HCL=$(mktemp)
cat "$BASE"/producer/*.tf "$BASE"/consumer/*.tf > "$ALL_HCL" 2>/dev/null || true
if grep -oE '[^0-9]([0-9]{12})[^0-9]' "$ALL_HCL" | grep -vE '012345678901' | grep -qE '[0-9]{12}'; then
  echo "  FAIL HCL seems to contain a 12-digit AWS Account ID that is not the placeholder 012345678901"
  fail=$((fail+1))
else
  echo "  OK   no suspicious real AWS Account IDs"
fi
rm -f "$ALL_HCL"

# --- DECISIONS.md ----------------------------------------------------------
DOC="$BASE/DECISIONS.md"
if [ -f "$DOC" ]; then
  echo "  OK   DECISIONS.md exists"
  for n in 001 002; do
    if grep -qiE "^#+ *ADR-$n" "$DOC"; then
      echo "  OK   DECISIONS.md has ADR-$n"
    else
      echo "  FAIL DECISIONS.md missing ADR-$n"
      fail=$((fail+1))
    fi
  done
  if grep -qi 'acceptance_required' "$DOC" && grep -qi 'private_dns_enabled' "$DOC"; then
    echo "  OK   DECISIONS.md discusses acceptance_required and private_dns_enabled"
  else
    echo "  FAIL DECISIONS.md must discuss acceptance_required and private_dns_enabled"
    fail=$((fail+1))
  fi
else
  echo "  FAIL $DOC missing"
  fail=$((fail+1))
fi

# --- cost-tradeoff.csv -----------------------------------------------------
CSV="$BASE/cost-tradeoff.csv"
if [ -f "$CSV" ]; then
  echo "  OK   cost-tradeoff.csv exists"
  head1=$(head -n1 "$CSV")
  if [ "$head1" = "services,option,fixed_usd,data_usd,total_usd" ]; then
    echo "  OK   CSV header is exact"
  else
    echo "  FAIL CSV header mismatch. Got: $head1"
    fail=$((fail+1))
  fi

  # 1 header + 6 data rows = 7 non-empty lines.
  rows=$(grep -cE '^[0-9]+,(nat_only|nat_plus_endpoints),' "$CSV")
  if [ "$rows" -eq 6 ]; then
    echo "  OK   CSV has exactly 6 data rows"
  else
    echo "  FAIL CSV should have 6 data rows (3 services * 2 options); got $rows"
    fail=$((fail+1))
  fi

  for n in 1 5 10; do
    hit=$(grep -cE "^${n}," "$CSV" || true)
    if [ "$hit" -eq 2 ]; then
      echo "  OK   CSV has 2 rows for services=$n"
    else
      echo "  FAIL CSV should have 2 rows for services=$n; got $hit"
      fail=$((fail+1))
    fi
  done
else
  echo "  FAIL $CSV missing"
  fail=$((fail+1))
fi

# --- cost-tradeoff.md ------------------------------------------------------
MD="$BASE/cost-tradeoff.md"
if [ -f "$MD" ]; then
  echo "  OK   cost-tradeoff.md exists"
  if grep -qiE 'f[óo]rmula' "$MD"; then
    echo "  OK   cost-tradeoff.md documents the formula"
  else
    echo "  FAIL cost-tradeoff.md must document the formula"
    fail=$((fail+1))
  fi
  if grep -qi 'ganador' "$MD"; then
    echo "  OK   cost-tradeoff.md names a winner per tramo"
  else
    echo "  FAIL cost-tradeoff.md must name a ganador per tramo"
    fail=$((fail+1))
  fi
  if grep -qiE 'seguridad|regulado|compliance|no-coste|no coste' "$MD"; then
    echo "  OK   cost-tradeoff.md cites a non-cost factor"
  else
    echo "  FAIL cost-tradeoff.md must cite at least one non-cost factor"
    fail=$((fail+1))
  fi
else
  echo "  FAIL $MD missing"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  exit 1
fi
echo "OK: estructura valida. Compara con solution/REFERENCE.md para autoevaluarte."
exit 0
