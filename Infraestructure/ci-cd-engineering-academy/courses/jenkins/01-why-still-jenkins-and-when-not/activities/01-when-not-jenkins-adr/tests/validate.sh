#!/usr/bin/env bash
# Structural validation for jk-01-01-when-not-jenkins-adr.
# Checks that ADR-JENKINS-DECISION.md exists and contains the required ADR
# sections, a code-fenced diagram, mention of Jenkins + at least 3 alternative
# tools, the migration framework steps, the on-prem / compliance constraint,
# freestyle vs pipeline, and the CVE/plugin surface.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/jk-01-adr}"
DOC="$BASE/ADR-JENKINS-DECISION.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Must look like an ADR (title mentioning ADR).
if grep -qiE '^#+ *ADR' "$DOC"; then
  echo "  OK   ADR-JENKINS-DECISION.md has an 'ADR' heading"
else
  echo "  FAIL ADR-JENKINS-DECISION.md missing an 'ADR' heading"
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

# Must have at least one fenced code block (the diagram).
fences=$(grep -cE '^```' "$DOC")
if [ "$fences" -ge 2 ]; then
  echo "  OK   has at least one fenced code block (${fences} fence lines)"
else
  echo "  FAIL has only ${fences} code-fence lines (expected >=2, a diagram block needs opening+closing)"
  fail=$((fail+1))
fi

# Must mention Jenkins explicitly.
if grep -qi 'jenkins' "$DOC"; then
  echo "  OK   mentions Jenkins"
else
  echo "  FAIL does not mention Jenkins"
  fail=$((fail+1))
fi

# Must compare against at least 3 alternatives (from a canonical set).
alt_count=0
for tool in "GitHub Actions" "GHA" "GitLab CI" "GitLab-CI" "Argo Workflows" \
            "Argo" "Tekton" "CloudBees"; do
  if grep -qi "$tool" "$DOC"; then
    alt_count=$((alt_count+1))
  fi
done
if [ "$alt_count" -ge 3 ]; then
  echo "  OK   mentions at least 3 alternative tools (${alt_count} tokens found)"
else
  echo "  FAIL mentions only ${alt_count} alternative tools (expected >=3 of GHA/GitLab CI/Argo/Tekton/CloudBees)"
  fail=$((fail+1))
fi

# Must name at least 3 migration framework steps.
mig_count=0
for step in "inventario" "inventory" "clasificaci" "classificat" "dual-run" \
            "dual run" "OIDC" "retirada" "retire" "decommission"; do
  if grep -qi "$step" "$DOC"; then
    mig_count=$((mig_count+1))
  fi
done
if [ "$mig_count" -ge 3 ]; then
  echo "  OK   names at least 3 migration-framework steps (${mig_count} tokens found)"
else
  echo "  FAIL names only ${mig_count} migration-framework tokens (expected >=3)"
  fail=$((fail+1))
fi

# Must mention on-prem / air-gapped constraint of the scenario.
if grep -qiE 'on-prem|on prem|self-hosted|self-managed|air[- ]gapped|datacenter|data center' "$DOC"; then
  echo "  OK   mentions on-prem / self-hosted / air-gapped constraint"
else
  echo "  FAIL does not mention on-prem / self-hosted / air-gapped"
  fail=$((fail+1))
fi

# Must mention compliance / GDPR / Solvency / audit.
if grep -qiE 'compliance|GDPR|solvency|audit' "$DOC"; then
  echo "  OK   mentions compliance / GDPR / Solvency / audit"
else
  echo "  FAIL does not mention compliance / GDPR / Solvency / audit"
  fail=$((fail+1))
fi

# Must mention freestyle AND pipeline / Jenkinsfile.
if grep -qi 'freestyle' "$DOC" && grep -qiE 'pipeline|Jenkinsfile' "$DOC"; then
  echo "  OK   mentions both freestyle and pipeline / Jenkinsfile"
else
  echo "  FAIL does not mention both 'freestyle' and 'pipeline' / 'Jenkinsfile'"
  fail=$((fail+1))
fi

# Must mention CVE / plugin / sandbox / script approval (security surface).
if grep -qiE 'CVE|vulnerab|plugin|sandbox|script +approval' "$DOC"; then
  echo "  OK   mentions CVE / plugin / sandbox / script-approval surface"
else
  echo "  FAIL does not mention CVE / plugin / sandbox / script-approval surface"
  fail=$((fail+1))
fi

# Alternatives section must list at least 2 alternatives.
alt_items=$(grep -cEi '^#+ +(Alt|Opci[oó]n|Alternativa)' "$DOC" || true)
alt_num=$(grep -cE '^[[:space:]]*[12]\. ' "$DOC" || true)
if [ "$alt_items" -ge 2 ] || [ "$alt_num" -ge 2 ]; then
  echo "  OK   has at least 2 alternatives listed"
else
  echo "  FAIL has fewer than 2 alternatives listed (expected >=2 sub-headings or numbered items)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara ADR-JENKINS-DECISION.md con solution/REFERENCE.md para autoevaluarte."
exit 0
