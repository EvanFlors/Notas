#!/usr/bin/env bash
# Structural validation for ans-06-02-migrate-vault-to-sm.
# Checks ADR-SECRETS-MIGRATION.md exists, has the required ADR sections,
# compares the right tools, maps the three secrets, includes a lookup
# snippet with no_log, and lists at least 2 alternatives.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare with solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/ans-06-sm}"
DOC="$BASE/ADR-SECRETS-MIGRATION.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# ADR heading.
if grep -qiE '^#+ *ADR' "$DOC"; then
  echo "  OK   has 'ADR' heading"
else
  echo "  FAIL missing 'ADR' heading"
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

# Tool comparison: ansible-vault, SOPS, External Secrets / ESO, SM / Vault.
for tool in "ansible-vault" "SOPS" "External +Secrets|ESO" \
            "Secrets +Manager|HashiCorp +Vault|hashi_vault"; do
  if grep -qiE "$tool" "$DOC"; then
    echo "  OK   mentions '${tool%%|*}'"
  else
    echo "  FAIL does not mention '${tool%%|*}'"
    fail=$((fail+1))
  fi
done

# Lookup snippet: amazon.aws.aws_secret or community.hashi_vault inside a code fence.
if grep -qE 'amazon\.aws\.aws_secret|community\.hashi_vault' "$DOC"; then
  echo "  OK   includes lookup plugin reference"
else
  echo "  FAIL does not reference amazon.aws.aws_secret or community.hashi_vault"
  fail=$((fail+1))
fi

# no_log mentioned.
if grep -qE 'no_log' "$DOC"; then
  echo "  OK   mentions no_log"
else
  echo "  FAIL does not mention no_log"
  fail=$((fail+1))
fi

# Rotation.
if grep -qiE 'rotaci[oó]n|rotation|rekey|rotator' "$DOC"; then
  echo "  OK   addresses rotation"
else
  echo "  FAIL does not address rotation"
  fail=$((fail+1))
fi

# Mapa de los 3 secretos.
for sec in "rds_master_password" "api_token_stripe" "ssh_deploy_key"; do
  if grep -q "$sec" "$DOC"; then
    echo "  OK   maps secret '$sec'"
  else
    echo "  FAIL does not map secret '$sec'"
    fail=$((fail+1))
  fi
done

# Tabla comparativa — al menos un bloque de tabla Markdown con 3 columnas.
if grep -cE '^\|.*\|.*\|' "$DOC" | awk '{ if ($1 >= 3) exit 0; else exit 1 }'; then
  echo "  OK   has a Markdown table with 3+ rows"
else
  echo "  FAIL no Markdown table with 3+ rows found"
  fail=$((fail+1))
fi

# At least one fenced code block (snippet YAML).
fences=$(grep -cE '^```' "$DOC")
if [ "$fences" -ge 2 ]; then
  echo "  OK   has at least one fenced code block (${fences} fence lines)"
else
  echo "  FAIL has only ${fences} code-fence lines (expected >=2)"
  fail=$((fail+1))
fi

# At least 2 alternatives listed (sub-headings or numbered items).
alt_items=$(grep -cEi '^#+ +(Alt|Opci[oó]n|Alternativa)' "$DOC" || true)
alt_num=$(grep -cE '^[[:space:]]*[12]\. ' "$DOC" || true)
if [ "$alt_items" -ge 2 ] || [ "$alt_num" -ge 2 ]; then
  echo "  OK   has at least 2 alternatives"
else
  echo "  FAIL has fewer than 2 alternatives"
  fail=$((fail+1))
fi

# Lab discipline: fake placeholder present.
if grep -qi 'fake' "$DOC"; then
  echo "  OK   uses fake placeholders (no real secrets)"
else
  echo "  FAIL does not mark values as fake — real secrets must never appear"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara ADR-SECRETS-MIGRATION.md con solution/REFERENCE.md."
exit 0
