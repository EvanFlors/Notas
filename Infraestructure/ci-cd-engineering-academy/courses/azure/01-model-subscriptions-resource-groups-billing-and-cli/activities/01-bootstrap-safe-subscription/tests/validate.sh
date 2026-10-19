#!/usr/bin/env bash
# Structural validation for az-01-01-bootstrap-safe-subscription.
# Checks that ADR-SUBSCRIPTION-BOOTSTRAP.md and bootstrap.sh exist, contain
# the required ADR sections, placeholder GUIDs, resource providers, budget
# anatomy, hierarchy mentions, and that bootstrap.sh is executable, has a
# shebang, and does NOT run destructive Azure commands.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness against a real Azure tenant — compare
# manually with solution/REFERENCE.md and solution/bootstrap.sh.

set -eu

BASE="${1:-/tmp/az-01-bootstrap}"
DOC="$BASE/ADR-SUBSCRIPTION-BOOTSTRAP.md"
SCRIPT="$BASE/bootstrap.sh"
fail=0

echo "== Structural validation for $BASE =="

# --- ADR file -----------------------------------------------------------------
if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

if grep -qiE '^#+ *ADR' "$DOC"; then
  echo "  OK   ADR has an 'ADR' heading"
else
  echo "  FAIL ADR missing an 'ADR' heading"
  fail=$((fail+1))
fi

for section in "Estado|Status" "Contexto|Context" "Decisi[oó]n|Decision" \
               "Consecuencias|Consequences" "Alternativas|Alternatives"; do
  label="${section%%|*}"
  if grep -qiE "^#+ *(${section})\\b" "$DOC"; then
    echo "  OK   ADR has '${label}' section"
  else
    echo "  FAIL ADR missing '${label}' section"
    fail=$((fail+1))
  fi
done

fences=$(grep -cE '^```' "$DOC")
if [ "$fences" -ge 2 ]; then
  echo "  OK   ADR has at least one fenced code block (${fences} fence lines)"
else
  echo "  FAIL ADR has only ${fences} fence lines (expected >=2 for a diagram)"
  fail=$((fail+1))
fi

# Must mention each hierarchy level.
for level in "Tenant|Entra" "Management +Group|MG\\b" "Subscription" "Resource +Group|RG\\b"; do
  label="${level%%|*}"
  if grep -qiE "${level}" "$DOC"; then
    echo "  OK   ADR mentions '${label}'"
  else
    echo "  FAIL ADR does not mention '${label}'"
    fail=$((fail+1))
  fi
done

# Must mention az CLI and az config / az account.
if grep -qiE '\baz +(config|account|login|group|provider)\b' "$DOC"; then
  echo "  OK   ADR mentions az CLI command(s)"
else
  echo "  FAIL ADR does not mention az CLI commands"
  fail=$((fail+1))
fi

# European region constraint.
if grep -qiE 'europ|westeurope|northeurope|eu-west|eu-central' "$DOC"; then
  echo "  OK   ADR mentions European region"
else
  echo "  FAIL ADR does not mention European region"
  fail=$((fail+1))
fi

# At least 3 placeholder GUIDs (00000000-..., 11111111-..., 22222222-...).
guids=0
for g in "00000000-0000-0000-0000-000000000000" \
         "11111111-1111-1111-1111-111111111111" \
         "22222222-2222-2222-2222-222222222222"; do
  if grep -q "$g" "$DOC"; then
    guids=$((guids+1))
  fi
done
if [ "$guids" -ge 3 ]; then
  echo "  OK   ADR uses at least 3 placeholder GUIDs (${guids} found)"
else
  echo "  FAIL ADR uses only ${guids} placeholder GUIDs (expected >=3)"
  fail=$((fail+1))
fi

# At least 2 Resource Groups named with rg-* convention.
rgs=$(grep -cE 'rg-[a-z0-9-]+' "$DOC" || true)
if [ "$rgs" -ge 2 ]; then
  echo "  OK   ADR names at least 2 Resource Groups (${rgs} 'rg-*' tokens found)"
else
  echo "  FAIL ADR names only ${rgs} 'rg-*' tokens (expected >=2)"
  fail=$((fail+1))
fi

# At least 3 Microsoft.* resource providers.
providers=0
for p in "Microsoft.Compute" "Microsoft.Network" "Microsoft.Storage" \
         "Microsoft.KeyVault" "Microsoft.ManagedIdentity" \
         "Microsoft.OperationalInsights" "Microsoft.Insights" \
         "Microsoft.App" "Microsoft.ContainerRegistry" \
         "Microsoft.ContainerService" "Microsoft.DBforPostgreSQL" \
         "Microsoft.Sql" "Microsoft.DocumentDB"; do
  if grep -q "$p" "$DOC"; then
    providers=$((providers+1))
  fi
done
if [ "$providers" -ge 3 ]; then
  echo "  OK   ADR names at least 3 resource providers (${providers} found)"
else
  echo "  FAIL ADR names only ${providers} resource providers (expected >=3)"
  fail=$((fail+1))
fi

# Subscription type explicit choice.
if grep -qiE 'Dev/Test|Dev-Test|Pay-?As-?You-?Go|PAYG|Enterprise Agreement|\bEA\b|MCA|Microsoft Customer Agreement|\bFree\b|CSP' "$DOC"; then
  echo "  OK   ADR picks a subscription type explicitly"
else
  echo "  FAIL ADR does not pick a subscription type explicitly"
  fail=$((fail+1))
fi

# Budget with amount + at least one Actual and one Forecasted threshold.
if grep -qiE 'budget' "$DOC"; then
  echo "  OK   ADR mentions a budget"
else
  echo "  FAIL ADR does not mention a budget"
  fail=$((fail+1))
fi
if grep -qiE 'Actual' "$DOC" && grep -qiE 'Forecast' "$DOC"; then
  echo "  OK   ADR covers Actual and Forecasted thresholds"
else
  echo "  FAIL ADR does not cover both Actual and Forecasted thresholds"
  fail=$((fail+1))
fi

# Alternatives: at least 2 subheadings or numbered items.
alt_items=$(grep -cEi '^#+ +(Alt|Opci[oó]n|Alternativa)' "$DOC" || true)
alt_num=$(grep -cE '^[[:space:]]*[12]\. ' "$DOC" || true)
if [ "$alt_items" -ge 2 ] || [ "$alt_num" -ge 2 ]; then
  echo "  OK   ADR lists at least 2 alternatives"
else
  echo "  FAIL ADR has fewer than 2 alternatives listed"
  fail=$((fail+1))
fi

# --- bootstrap.sh -------------------------------------------------------------
if [ ! -f "$SCRIPT" ]; then
  echo "FAIL: $SCRIPT does not exist."
  fail=$((fail+1))
else
  echo "  OK   bootstrap.sh exists"

  if [ -x "$SCRIPT" ]; then
    echo "  OK   bootstrap.sh is executable"
  else
    echo "  FAIL bootstrap.sh is not executable (run: chmod +x bootstrap.sh)"
    fail=$((fail+1))
  fi

  if head -1 "$SCRIPT" | grep -qE '^#!/.*(bash|sh)'; then
    echo "  OK   bootstrap.sh has a shebang"
  else
    echo "  FAIL bootstrap.sh missing shebang on first line"
    fail=$((fail+1))
  fi

  if grep -qE '^set -eu' "$SCRIPT" || grep -qE '^set -e' "$SCRIPT"; then
    echo "  OK   bootstrap.sh uses 'set -e' / 'set -eu'"
  else
    echo "  FAIL bootstrap.sh does not use 'set -e' / 'set -eu'"
    fail=$((fail+1))
  fi

  # Reject enabling pipefail (we want to avoid SIGPIPE false positives).
  if grep -qE 'pipefail' "$SCRIPT"; then
    if grep -qiE 'SIGPIPE|do +NOT|pipefail.*false' "$SCRIPT"; then
      echo "  OK   bootstrap.sh references pipefail only in a comment / disabling note"
    else
      echo "  FAIL bootstrap.sh enables pipefail; drop it to avoid SIGPIPE false positives (document why in a comment)"
      fail=$((fail+1))
    fi
  else
    echo "  OK   bootstrap.sh does not enable pipefail"
  fi

  # Must mention each pivotal az subcommand (either as --help, a comment, or a read-only call).
  for cmd in "az login" "az account" "az group" "az provider" "az consumption"; do
    if grep -qE "${cmd}" "$SCRIPT"; then
      echo "  OK   bootstrap.sh references '${cmd}'"
    else
      echo "  FAIL bootstrap.sh does not reference '${cmd}'"
      fail=$((fail+1))
    fi
  done

  # Safety: no destructive uncommented az commands.
  # A line is destructive if it starts (ignoring leading whitespace) with 'az ...'
  # and the subcommand is one of: create/update/delete/set with a resource target
  # (NOT just `az config set defaults...` because that is CLI-local, no API call,
  # but we flag it anyway to be conservative — the student can leave it commented).
  # Lines that look destructive AND are not clearly `--help` / `--dry-run` / `what-if`.
  destructive_lines=$(grep -nE '^[[:space:]]*az +(group|resource|storage|keyvault|network|vm|aks|acr|monitor|consumption|deployment|provider|account) +(create|delete|update|set|register|unregister|lock)' "$SCRIPT" \
    | grep -v '^[[:space:]]*[0-9]*:[[:space:]]*#' \
    | grep -vE -- '--help|--dry-run|what-if' || true)
  if [ -z "$destructive_lines" ]; then
    echo "  OK   bootstrap.sh has no destructive 'az' commands active"
  else
    echo "  FAIL bootstrap.sh has active (uncommented) destructive 'az' commands:"
    printf '%s\n' "$destructive_lines" | sed 's/^/       /'
    fail=$((fail+1))
  fi

  # Must contain at least one placeholder GUID.
  if grep -qE '00000000-0000-0000-0000-000000000000|11111111-1111-1111-1111-111111111111|22222222-2222-2222-2222-222222222222' "$SCRIPT"; then
    echo "  OK   bootstrap.sh uses a placeholder GUID"
  else
    echo "  FAIL bootstrap.sh does not include a placeholder GUID"
    fail=$((fail+1))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara con solution/REFERENCE.md y solution/bootstrap.sh para autoevaluarte."
exit 0
