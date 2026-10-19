#!/usr/bin/env bash
# Structural validation for ans-09-02-tf-ansible-or-packer-ansible-adr.
# Checks that ADR-MUTABLE-VS-IMMUTABLE.md exists and contains the required
# ADR sections, the trade-offs table, the three named workloads, mentions
# of Packer / Terraform / Ansible / AWX|AAP, mutable + immutable vocabulary,
# a reference to secrets management, and a mention of EKS / Kubernetes.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/ans-09-02}"
DOC="$BASE/ADR-MUTABLE-VS-IMMUTABLE.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Must look like an ADR (title mentioning ADR).
if grep -qiE '^#+ *ADR' "$DOC"; then
  echo "  OK   ADR-MUTABLE-VS-IMMUTABLE.md has an 'ADR' heading"
else
  echo "  FAIL ADR-MUTABLE-VS-IMMUTABLE.md missing an 'ADR' heading"
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

# The three workloads must be named explicitly.
for wl in "legacy-billing" "checkout-api" "analytics-platform"; do
  if grep -q "$wl" "$DOC"; then
    echo "  OK   mentions workload '${wl}'"
  else
    echo "  FAIL does not mention workload '${wl}'"
    fail=$((fail+1))
  fi
done

# Must mention mutable AND immutable (or inmutable).
if grep -qiE '\bmutable\b' "$DOC"; then
  echo "  OK   mentions 'mutable'"
else
  echo "  FAIL does not mention 'mutable'"
  fail=$((fail+1))
fi
if grep -qiE '\binmutable\b|\bimmutable\b' "$DOC"; then
  echo "  OK   mentions 'immutable' (or 'inmutable')"
else
  echo "  FAIL does not mention 'immutable' (or 'inmutable')"
  fail=$((fail+1))
fi

# Must mention Packer, Terraform, Ansible.
for tool in "Packer" "Terraform" "Ansible"; do
  if grep -qi "$tool" "$DOC"; then
    echo "  OK   mentions ${tool}"
  else
    echo "  FAIL does not mention ${tool}"
    fail=$((fail+1))
  fi
done

# Must mention AWX or AAP.
if grep -qE '\bAWX\b|\bAAP\b|Automation +Platform' "$DOC"; then
  echo "  OK   mentions AWX or AAP"
else
  echo "  FAIL does not mention AWX or AAP"
  fail=$((fail+1))
fi

# Trade-offs table — must have at least one Markdown table (pipe-separated).
table_lines=$(grep -cE '^[[:space:]]*\|.+\|' "$DOC" || true)
if [ "$table_lines" -ge 3 ]; then
  echo "  OK   has a Markdown table (${table_lines} table-like lines)"
else
  echo "  FAIL has fewer than 3 Markdown table lines (need a trade-offs table)"
  fail=$((fail+1))
fi

# Trade-offs table must cover at least: drift, blast radius, rollback,
# build time / velocidad / iteracion.
for dim in "drift" "blast +radius|blast-radius" "rollback" "build +time|velocidad|iteraci[oó]n"; do
  label="${dim%%|*}"
  if grep -qiE "${dim}" "$DOC"; then
    echo "  OK   trade-offs cover '${label}'"
  else
    echo "  FAIL trade-offs must cover '${label}'"
    fail=$((fail+1))
  fi
done

# Secrets mention + Secrets Manager / Vault.
if grep -qiE 'secrets +manager|hashi[^ ]*vault|vault' "$DOC" \
   || grep -qi 'secret' "$DOC"; then
  echo "  OK   mentions secrets handling (Secrets Manager / Vault / secrets)"
else
  echo "  FAIL does not mention secrets handling"
  fail=$((fail+1))
fi

# EKS / Kubernetes mention (why Ansible loses relevance there).
if grep -qiE '\bEKS\b|\bK8s\b|Kubernetes' "$DOC"; then
  echo "  OK   mentions EKS / Kubernetes"
else
  echo "  FAIL does not mention EKS / Kubernetes"
  fail=$((fail+1))
fi

# Alternatives section must list at least 2 alternatives.
alt_items=$(grep -cEi '^#+ +(Alt|Opci[oó]n|Alternativa)' "$DOC" || true)
alt_num=$(grep -cE '^[[:space:]]*[12]\. ' "$DOC" || true)
if [ "$alt_items" -ge 2 ] || [ "$alt_num" -ge 2 ]; then
  echo "  OK   lists at least 2 alternatives"
else
  echo "  FAIL fewer than 2 alternatives (expected >=2 sub-headings or numbered items)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara ADR-MUTABLE-VS-IMMUTABLE.md con solution/REFERENCE.md para autoevaluarte."
exit 0
