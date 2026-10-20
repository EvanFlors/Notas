#!/usr/bin/env bash
# Structural validation for ans-05-02-collection-eval-adr.
#
# Checks that ADR-COLLECTION-ADOPTION.md exists and contains the required
# ADR sections (Estado/Contexto/Decision/Consecuencias/Alternativas), a
# comparison table, mentions of amazon.aws + community.aws + ansible-core +
# Automation Hub + Galaxy, the 6 adoption criteria tokens, the rollback
# pattern, and at least 2 alternatives.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/ans-05-02}"
DOC="$BASE/ADR-COLLECTION-ADOPTION.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Must look like an ADR (title mentioning ADR).
if grep -qiE '^#+ *ADR' "$DOC"; then
  echo "  OK   ADR-COLLECTION-ADOPTION.md has an 'ADR' heading"
else
  echo "  FAIL ADR-COLLECTION-ADOPTION.md missing an 'ADR' heading"
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

# Must have at least one fenced code block OR a Markdown table.
fences=$(grep -cE '^```' "$DOC" || true)
pipes=$(grep -cE '^\|' "$DOC" || true)
if [ "$fences" -ge 2 ] || [ "$pipes" -ge 2 ]; then
  echo "  OK   has at least one fenced block or Markdown table (fences=${fences}, pipe-lines=${pipes})"
else
  echo "  FAIL has neither fenced code block nor Markdown table"
  fail=$((fail+1))
fi

# Must specifically have a comparison table (>=3 pipe lines — header, sep, >=1 row).
if [ "$pipes" -ge 3 ]; then
  echo "  OK   has a comparison table (${pipes} pipe lines)"
else
  echo "  FAIL does not have a comparison table (expected >=3 pipe lines, found ${pipes})"
  fail=$((fail+1))
fi

# Must mention both collections.
for coll in "amazon.aws" "community.aws"; do
  if grep -q "$coll" "$DOC"; then
    echo "  OK   mentions ${coll}"
  else
    echo "  FAIL does not mention ${coll}"
    fail=$((fail+1))
  fi
done

# Must mention ansible-core / ansible_core.
if grep -qiE 'ansible[-_ ]core' "$DOC"; then
  echo "  OK   mentions ansible-core"
else
  echo "  FAIL does not mention ansible-core"
  fail=$((fail+1))
fi

# Must mention Automation Hub (or AAP / Red Hat Automation Platform).
if grep -qiE 'Automation +Hub|\bAAP\b|Ansible +Automation +Platform' "$DOC"; then
  echo "  OK   mentions Automation Hub / AAP"
else
  echo "  FAIL does not mention Automation Hub / AAP"
  fail=$((fail+1))
fi

# Must mention Galaxy.
if grep -qiE '\bgalaxy\b' "$DOC"; then
  echo "  OK   mentions Galaxy"
else
  echo "  FAIL does not mention Galaxy"
  fail=$((fail+1))
fi

# 6 adoption criteria tokens (one of each pair).
check_pair() {
  local label="$1"; shift
  local found=0
  for tok in "$@"; do
    if grep -qiE "$tok" "$DOC"; then
      found=1
      break
    fi
  done
  if [ "$found" = "1" ]; then
    echo "  OK   criterion '${label}' present"
  else
    echo "  FAIL criterion '${label}' missing (expected one of: $*)"
    fail=$((fail+1))
  fi
}

check_pair "mantenimiento/maintenance" 'mantenimiento' 'maintenance'
check_pair "cobertura/coverage"        'cobertura' 'coverage'
check_pair "dependencias/dependencies" 'dependencias' 'dependencies'
check_pair "licencia/license"          'licencia' 'license'
check_pair "certificada/certified"     'certificad' 'certified'
check_pair "namespace/propietario/owner" 'namespace' 'propietario' '\bowner'

# Rollback pattern via pin.
if grep -qiE '\bpin(ned|ear|ar|eado)?\b|rollback|fijar +versi[oó]n|version +exacta' "$DOC"; then
  echo "  OK   mentions rollback / pin pattern"
else
  echo "  FAIL does not mention rollback / pin pattern"
  fail=$((fail+1))
fi

# Alternatives section must list at least 2 alternatives (subheadings or numbered).
alt_items=$(grep -cEi '^#+ +(Alt|Opci[oó]n|Alternativa)' "$DOC" || true)
alt_num=$(grep -cE '^[[:space:]]*[12]\. ' "$DOC" || true)
if [ "$alt_items" -ge 2 ] || [ "$alt_num" -ge 2 ]; then
  echo "  OK   has at least 2 alternatives listed"
else
  echo "  FAIL has fewer than 2 alternatives listed (alt_items=${alt_items}, numbered=${alt_num})"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail issue(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara ADR-COLLECTION-ADOPTION.md con solution/REFERENCE.md para autoevaluarte."
exit 0
