#!/usr/bin/env bash
# Structural validation for ans-10-02-deprecation-plan.
# Checks that ADR-DEPRECATION-PLAN.md exists and contains the required ADR
# sections, named target playbook, replacement, phases, owners, rollback and
# communication channel.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/ans-10-deprecation}"
DOC="$BASE/ADR-DEPRECATION-PLAN.md"
issues=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Must look like an ADR.
if grep -qiE '^#+ *ADR' "$DOC"; then
  echo "  OK   has an 'ADR' heading"
else
  echo "  FAIL missing an 'ADR' heading"
  issues=$((issues+1))
fi

# Required ADR sections.
for section in "Estado|Status" "Contexto|Context" "Decisi[oó]n|Decision" \
               "Consecuencias|Consequences" "Alternativas|Alternatives"; do
  label="${section%%|*}"
  if grep -qiE "^#+ *(${section})\\b" "$DOC"; then
    echo "  OK   has '${label}' section"
  else
    echo "  FAIL missing '${label}' section"
    issues=$((issues+1))
  fi
done

# Must name the target playbook.
if grep -qi 'deploy-checkout-to-eks' "$DOC"; then
  echo "  OK   names target playbook (deploy-checkout-to-eks)"
else
  echo "  FAIL does not name target playbook (deploy-checkout-to-eks)"
  issues=$((issues+1))
fi

# Replacement: Argo CD or Flux.
if grep -qiE 'Argo *CD|ArgoCD|Flux\b' "$DOC"; then
  echo "  OK   names replacement (Argo CD / Flux)"
else
  echo "  FAIL does not name replacement (Argo CD / Flux)"
  issues=$((issues+1))
fi

# At least 2 deprecation criteria.
crit=0
for c in "dominio" "domain" "drift" "uso bajo" "low +use" "riesgo" "risk" \
         "contrato" "contract" "dependencia abandonada" "unmaintained"; do
  if grep -qiE "$c" "$DOC"; then
    crit=$((crit+1))
  fi
done
if [ "$crit" -ge 2 ]; then
  echo "  OK   names at least 2 deprecation criteria (${crit} tokens found)"
else
  echo "  FAIL names only ${crit} deprecation-criteria tokens (expected >=2)"
  issues=$((issues+1))
fi

# At least 4 phases named: anuncio/announce, freeze, canary, corte/cutoff/removal.
phases=0
for p in "anuncio" "announce" "freeze" "canary" "corte" "cutoff" \
         "removal" "post-?mortem" "follow-?up"; do
  if grep -qiE "$p" "$DOC"; then
    phases=$((phases+1))
  fi
done
if [ "$phases" -ge 4 ]; then
  echo "  OK   names at least 4 phase tokens (${phases} found)"
else
  echo "  FAIL names only ${phases} phase tokens (expected >=4)"
  issues=$((issues+1))
fi

# Owner / team mentioned.
if grep -qiE 'owner|DRI|platform-?sre|team *checkout|@' "$DOC"; then
  echo "  OK   mentions owner / team"
else
  echo "  FAIL does not mention owner / team / DRI"
  issues=$((issues+1))
fi

# Rollback plan mentioned.
if grep -qi 'rollback' "$DOC"; then
  echo "  OK   mentions rollback"
else
  echo "  FAIL does not mention rollback"
  issues=$((issues+1))
fi

# Communication channel mentioned.
if grep -qiE 'Slack|email|canal|channel|#platform|#team' "$DOC"; then
  echo "  OK   mentions communication channel"
else
  echo "  FAIL does not mention communication channel (Slack/email/#channel)"
  issues=$((issues+1))
fi

# At least one fenced code block (calendar/table/diagram).
fences=$(grep -cE '^```' "$DOC")
if [ "$fences" -ge 2 ]; then
  echo "  OK   has at least one fenced code block (${fences} fence lines)"
else
  echo "  FAIL has only ${fences} code-fence lines (expected >=2)"
  issues=$((issues+1))
fi

# Alternatives: at least 2 sub-headings or numbered items.
alt_items=$(grep -cEi '^#+ +(Alt|Opci[oó]n|Alternativa)' "$DOC" || true)
alt_num=$(grep -cE '^[[:space:]]*[12]\. ' "$DOC" || true)
if [ "$alt_items" -ge 2 ] || [ "$alt_num" -ge 2 ]; then
  echo "  OK   has at least 2 alternatives listed"
else
  echo "  FAIL has fewer than 2 alternatives listed (expected >=2 sub-headings or numbered items)"
  issues=$((issues+1))
fi

echo
if [ "$issues" -gt 0 ]; then
  echo "RESULT: $issues issue(s)."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida — 0 issue(s). Compara ADR-DEPRECATION-PLAN.md con solution/REFERENCE.md para autoevaluarte."
exit 0
