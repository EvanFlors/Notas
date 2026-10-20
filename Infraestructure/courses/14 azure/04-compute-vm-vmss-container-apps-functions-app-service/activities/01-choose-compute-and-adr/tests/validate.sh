#!/usr/bin/env bash
# Structural validation for az-04-01-choose-compute-and-adr.
# Checks that ADR-COMPUTE-CHOICE.md exists, has the ADR sections,
# names the 5 compute families and the 3 workloads, discusses the
# required trade-offs, and lists at least 2 discarded alternatives.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many
# checks use `... | grep -q ...` which can produce SIGPIPE (exit 141)
# when grep finds a match early. pipefail would spuriously mark those
# as failures.
#
# Does NOT grade semantic correctness — compare with solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/az-04-01}"
DOC="$BASE/ADR-COMPUTE-CHOICE.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Must look like an ADR.
if grep -qiE '^#+ *ADR' "$DOC"; then
  echo "  OK   ADR-COMPUTE-CHOICE.md has an 'ADR' heading"
else
  echo "  FAIL ADR-COMPUTE-CHOICE.md missing an 'ADR' heading"
  fail=$((fail+1))
fi

# Required ADR sections.
for section in "Estado|Status" "Contexto|Context" "Decisi[oó]n|Decision" \
               "Consecuencias|Consequences" "Alternativas|Alternatives"; do
  label="${section%%|*}"
  if grep -qiE "^#+ *(${section})\\b" "$DOC"; then
    echo "  OK   has '${label}' section"
  else
    echo "  FAIL missing '${label}' section"
    fail=$((fail+1))
  fi
done

# At least one fenced code block (table or diagram).
fences=$(grep -cE '^```' "$DOC")
if [ "$fences" -ge 2 ]; then
  echo "  OK   has at least one fenced block (${fences} fence lines)"
else
  echo "  FAIL has only ${fences} code-fence lines (expected >=2)"
  fail=$((fail+1))
fi

# Must name at least 5 compute families from the catalog.
families=0
for f in "VM" "VMSS" "App Service" "Container Apps" "Functions" "ACI" "Container Instances"; do
  if grep -qi "$f" "$DOC"; then
    families=$((families+1))
  fi
done
if [ "$families" -ge 5 ]; then
  echo "  OK   names at least 5 compute families (${families} tokens found)"
else
  echo "  FAIL names only ${families} compute families (expected >=5)"
  fail=$((fail+1))
fi

# Must name the 3 workloads.
missing_workload=0
for w in "checkout-api" "etl-nightly" "billing-worker"; do
  if grep -qi "$w" "$DOC"; then
    echo "  OK   mentions workload '${w}'"
  else
    echo "  FAIL does not mention workload '${w}'"
    missing_workload=$((missing_workload+1))
  fi
done
fail=$((fail+missing_workload))

# Must mention trade-off keywords.
for tradeoff in "cold.start|cold-start|cold start" "cost|coste|precio" \
                "portabil|portability"; do
  label="${tradeoff%%|*}"
  if grep -qiE "${tradeoff}" "$DOC"; then
    echo "  OK   discusses trade-off '${label}'"
  else
    echo "  FAIL does not discuss trade-off '${label}'"
    fail=$((fail+1))
  fi
done

# Must mention Managed Identity.
if grep -qiE 'Managed +Identity|MI\b' "$DOC"; then
  echo "  OK   mentions Managed Identity"
else
  echo "  FAIL does not mention Managed Identity"
  fail=$((fail+1))
fi

# Must mention Europe / region constraint.
if grep -qiE 'europ|westeurope|northeurope|eu-west|eu-central' "$DOC"; then
  echo "  OK   mentions Europe / eu-* region"
else
  echo "  FAIL does not mention Europe"
  fail=$((fail+1))
fi

# Markdown table (at least one row with pipes besides the header separator).
pipes=$(grep -cE '^\|.*\|' "$DOC")
if [ "$pipes" -ge 3 ]; then
  echo "  OK   has a Markdown table (${pipes} pipe-rows)"
else
  echo "  FAIL has no Markdown table (expected >=3 pipe-rows)"
  fail=$((fail+1))
fi

# At least one AWS <-> Azure mapping cue.
if grep -qiE 'ECS|Fargate|Lambda|EC2|App *Runner|CodeDeploy' "$DOC"; then
  echo "  OK   mentions at least one AWS service for mapping"
else
  echo "  FAIL does not reference any AWS service for mapping"
  fail=$((fail+1))
fi

# Alternatives section must list at least 2 alternatives
# (sub-headings OR numbered items).
alt_items=$(grep -cEi '^#+ +(Alt|Opci[oó]n|Alternativa)' "$DOC" || true)
alt_num=$(grep -cE '^[[:space:]]*[12]\. ' "$DOC" || true)
alt_hnum=$(grep -cE '^#+[[:space:]]+[12][.)]' "$DOC" || true)
if [ "$alt_items" -ge 2 ] || [ "$alt_num" -ge 2 ] || [ "$alt_hnum" -ge 2 ]; then
  echo "  OK   has at least 2 alternatives listed"
else
  echo "  FAIL has fewer than 2 alternatives listed (expected >=2)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara ADR-COMPUTE-CHOICE.md con solution/REFERENCE.md para autoevaluarte."
exit 0
