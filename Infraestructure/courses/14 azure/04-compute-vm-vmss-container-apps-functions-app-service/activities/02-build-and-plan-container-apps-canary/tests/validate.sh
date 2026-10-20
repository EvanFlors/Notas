#!/usr/bin/env bash
# Mixed validation for az-04-02-build-and-plan-container-apps-canary.
#
# Verifies the four deliverables of the activity (Dockerfile, main.tf,
# variables.tf, app/main.py), then runs the real tooling:
#   - docker build  on the student's Dockerfile
#   - terraform init -backend=false + terraform validate on the student's
#     Terraform module
# and finally greps the required blocks (revision_mode Multiple,
# traffic_weight 90/10, SystemAssigned, no hardcoded secrets).
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# The validator NEVER talks to Azure. No tenant/subscription IDs required.

set -eu

BASE="${1:-/tmp/az-04-02}"
fail=0

echo "== Mixed validation for $BASE =="

# --- 1. Required files ---------------------------------------------------
for f in Dockerfile main.tf variables.tf app/main.py; do
  if [ -f "$BASE/$f" ]; then
    echo "  OK   $f exists"
  else
    echo "  FAIL $f missing"
    fail=$((fail+1))
  fi
done

# Must NOT contain ANALYSIS.md (naming convention clash).
if [ -e "$BASE/ANALYSIS.md" ]; then
  echo "  FAIL $BASE/ANALYSIS.md exists; this activity forbids that name"
  fail=$((fail+1))
else
  echo "  OK   no ANALYSIS.md present"
fi

if [ "$fail" -gt 0 ]; then
  echo
  echo "RESULT: $fail check(s) failed before tooling runs. Aborting."
  exit 1
fi

# --- 2. docker build -----------------------------------------------------
if command -v docker >/dev/null 2>&1; then
  echo "  .. running docker build (may take 30-120s on cold cache)"
  if (cd "$BASE" && docker build -q -t az04-canary:test . >/tmp/az04-docker.log 2>&1); then
    echo "  OK   docker build succeeds"
  else
    echo "  FAIL docker build failed; see /tmp/az04-docker.log (last 20 lines):"
    tail -20 /tmp/az04-docker.log | sed 's/^/      /'
    fail=$((fail+1))
  fi
else
  echo "  SKIP docker not installed; cannot verify Dockerfile builds"
fi

# --- 3. terraform validate -----------------------------------------------
if command -v terraform >/dev/null 2>&1; then
  TFTMP=$(mktemp -d)
  cp "$BASE"/main.tf "$BASE"/variables.tf "$TFTMP/"
  echo "  .. running terraform init -backend=false + validate in $TFTMP"
  if (cd "$TFTMP" && terraform init -backend=false -input=false -no-color >/tmp/az04-tf-init.log 2>&1); then
    echo "  OK   terraform init succeeds"
  else
    echo "  FAIL terraform init failed; see /tmp/az04-tf-init.log (last 20 lines):"
    tail -20 /tmp/az04-tf-init.log | sed 's/^/      /'
    fail=$((fail+1))
  fi
  if (cd "$TFTMP" && terraform validate -no-color >/tmp/az04-tf-validate.log 2>&1); then
    echo "  OK   terraform validate succeeds"
  else
    echo "  FAIL terraform validate failed; see /tmp/az04-tf-validate.log:"
    cat /tmp/az04-tf-validate.log | sed 's/^/      /'
    fail=$((fail+1))
  fi
  rm -rf "$TFTMP"
else
  echo "  SKIP terraform not installed; cannot verify .tf"
fi

# --- 4. Required Terraform blocks (grep) --------------------------------
TF="$BASE/main.tf"

check_grep() {
  local pattern="$1"
  local label="$2"
  if grep -qE "$pattern" "$TF"; then
    echo "  OK   main.tf contains ${label}"
  else
    echo "  FAIL main.tf missing ${label} (pattern: ${pattern})"
    fail=$((fail+1))
  fi
}

check_grep 'revision_mode[[:space:]]*=[[:space:]]*"Multiple"' 'revision_mode = "Multiple"'
check_grep 'type[[:space:]]*=[[:space:]]*"SystemAssigned"' 'identity SystemAssigned'
check_grep 'resource[[:space:]]+"azurerm_container_app"' 'resource azurerm_container_app'
check_grep 'resource[[:space:]]+"azurerm_container_app_environment"' 'resource azurerm_container_app_environment'
check_grep 'resource[[:space:]]+"azurerm_resource_group"' 'resource azurerm_resource_group'

# Must have at least two traffic_weight blocks summing 100.
tw_count=$(grep -cE '^[[:space:]]*traffic_weight[[:space:]]*\{' "$TF" || true)
if [ "$tw_count" -ge 2 ]; then
  echo "  OK   main.tf has ${tw_count} traffic_weight blocks"
else
  echo "  FAIL main.tf has only ${tw_count} traffic_weight blocks (expected >=2)"
  fail=$((fail+1))
fi

# Sum of percentages must be 100 (grep all percentage = N and add).
pct_sum=$(grep -E 'percentage[[:space:]]*=' "$TF" \
          | sed -E 's/.*=[[:space:]]*([0-9]+).*/\1/' \
          | awk '{s+=$1} END {print s+0}')
if [ "$pct_sum" = "100" ]; then
  echo "  OK   traffic_weight percentages sum to 100"
else
  echo "  FAIL traffic_weight percentages sum to ${pct_sum} (expected 100)"
  fail=$((fail+1))
fi

# target_port = 8000 (matches FastAPI uvicorn default of the Dockerfile).
check_grep 'target_port[[:space:]]*=[[:space:]]*8000' 'ingress target_port = 8000'

# --- 5. Anti-patterns ----------------------------------------------------

# No real-looking subscription or tenant ID. Allow the all-zeros placeholder.
if grep -qiE 'subscription_id[[:space:]]*=[[:space:]]*"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"' "$TF" \
   && ! grep -qiE 'subscription_id[[:space:]]*=[[:space:]]*"00000000-0000-0000-0000-000000000000"' "$TF"; then
  echo "  FAIL main.tf hardcodes a non-placeholder subscription_id GUID"
  fail=$((fail+1))
else
  echo "  OK   no non-placeholder subscription_id GUID in main.tf"
fi

if grep -qiE 'tenant_id[[:space:]]*=[[:space:]]*"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"' "$TF" \
   && ! grep -qiE 'tenant_id[[:space:]]*=[[:space:]]*"00000000-0000-0000-0000-000000000000"' "$TF"; then
  echo "  FAIL main.tf hardcodes a non-placeholder tenant_id GUID"
  fail=$((fail+1))
else
  echo "  OK   no non-placeholder tenant_id GUID in main.tf"
fi

# No obvious secrets in env vars.
if grep -qiE 'AZURE_CLIENT_SECRET|CLIENT_SECRET[[:space:]]*=[[:space:]]*"[^"$]' "$TF"; then
  echo "  FAIL main.tf contains a hardcoded CLIENT_SECRET"
  fail=$((fail+1))
else
  echo "  OK   no hardcoded CLIENT_SECRET in main.tf"
fi

# --- 6. Dockerfile sanity -----------------------------------------------
DF="$BASE/Dockerfile"

if grep -qE '^FROM .*AS ' "$DF" || grep -ciE '^FROM ' "$DF" | grep -qxE '[2-9]|[0-9]{2,}'; then
  echo "  OK   Dockerfile is multistage"
else
  # Try again: count FROMs
  from_count=$(grep -cE '^FROM ' "$DF" || true)
  if [ "$from_count" -ge 2 ]; then
    echo "  OK   Dockerfile is multistage (${from_count} FROM lines)"
  else
    echo "  FAIL Dockerfile is not multistage (only ${from_count} FROM line)"
    fail=$((fail+1))
  fi
fi

if grep -qE '^USER ' "$DF" && ! grep -qE '^USER[[:space:]]+root[[:space:]]*$' "$DF"; then
  echo "  OK   Dockerfile sets a non-root USER"
else
  echo "  FAIL Dockerfile does not set a non-root USER"
  fail=$((fail+1))
fi

if grep -qE '^EXPOSE[[:space:]]+8000' "$DF"; then
  echo "  OK   Dockerfile EXPOSE 8000"
else
  echo "  FAIL Dockerfile does not EXPOSE 8000"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  echo "        (Semantic correctness in a real Azure subscription is NOT verified here.)"
  exit 1
fi
echo "OK: Dockerfile + Terraform module pasan validacion."
echo "    Compara con solution/ para autoevaluacion."
exit 0
