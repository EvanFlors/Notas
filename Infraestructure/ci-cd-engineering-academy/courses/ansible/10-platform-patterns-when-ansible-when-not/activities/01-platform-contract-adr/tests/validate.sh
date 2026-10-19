#!/usr/bin/env bash
# Structural validation for ans-10-01-platform-contract-adr.
# Checks that ADR-ANSIBLE-CONTRACT.md exists and contains the required ADR
# sections, named domains (si/no), alternative tools, immutable-first stance,
# CODEOWNERS mention, lint/CI and operational control plane (AWX/EDA).
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/ans-10-contract}"
DOC="$BASE/ADR-ANSIBLE-CONTRACT.md"
issues=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Must look like an ADR (title mentioning ADR).
if grep -qiE '^#+ *ADR' "$DOC"; then
  echo "  OK   ADR-ANSIBLE-CONTRACT.md has an 'ADR' heading"
else
  echo "  FAIL ADR-ANSIBLE-CONTRACT.md missing an 'ADR' heading"
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

# Must mention Ansible explicitly.
if grep -qi 'ansible' "$DOC"; then
  echo "  OK   mentions Ansible"
else
  echo "  FAIL does not mention Ansible"
  issues=$((issues+1))
fi

# At least 3 alternative tools named.
alt=0
for t in "Terraform" "OpenTofu" "Helm" "Argo" "Flux" "Packer" \
         "Kubernetes operator" "operador K8s" "operator SDK" "Kubebuilder"; do
  if grep -qi "$t" "$DOC"; then
    alt=$((alt+1))
  fi
done
if [ "$alt" -ge 3 ]; then
  echo "  OK   names at least 3 alternative tools (${alt} tokens found)"
else
  echo "  FAIL names only ${alt} alternative-tool tokens (expected >=3)"
  issues=$((issues+1))
fi

# At least 5 "yes" domains from the canonical list.
yes_domains=0
for d in "Day-2" "Day 2" "bare metal" "bare-metal" "network" "red\\b" \
         "Cisco" "Arista" "Juniper" "kubeadm" "incident" "runbook" \
         "CIS" "STIG" "hardening" "bootstrap"; do
  if grep -qiE "$d" "$DOC"; then
    yes_domains=$((yes_domains+1))
  fi
done
if [ "$yes_domains" -ge 5 ]; then
  echo "  OK   names at least 5 'yes' domains (${yes_domains} tokens found)"
else
  echo "  FAIL names only ${yes_domains} 'yes' domain tokens (expected >=5)"
  issues=$((issues+1))
fi

# At least 3 "no" domains / anti-patterns.
no_domains=0
for d in "Kubernetes" "K8s" "aprovisionamiento" "provisioning" \
         "contenedor" "container" "reconcili" "service mesh" \
         "secret rotation" "rotaci[oó]n de secret" "build" "compilar"; do
  if grep -qiE "$d" "$DOC"; then
    no_domains=$((no_domains+1))
  fi
done
if [ "$no_domains" -ge 3 ]; then
  echo "  OK   names at least 3 'no' domain tokens (${no_domains} found)"
else
  echo "  FAIL names only ${no_domains} 'no' domain tokens (expected >=3)"
  issues=$((issues+1))
fi

# Immutable-first stance and Packer.
if grep -qiE 'immutable|inmutable' "$DOC"; then
  echo "  OK   mentions immutable/inmutable mindset"
else
  echo "  FAIL does not mention immutable/inmutable"
  issues=$((issues+1))
fi

if grep -qi 'Packer' "$DOC"; then
  echo "  OK   mentions Packer"
else
  echo "  FAIL does not mention Packer"
  issues=$((issues+1))
fi

# Ownership: CODEOWNERS.
if grep -qiE 'CODEOWNERS|code *owners|ownership' "$DOC"; then
  echo "  OK   mentions CODEOWNERS / ownership"
else
  echo "  FAIL does not mention CODEOWNERS / ownership"
  issues=$((issues+1))
fi

# CI gating: ansible-lint and molecule.
if grep -qi 'ansible-lint' "$DOC"; then
  echo "  OK   mentions ansible-lint"
else
  echo "  FAIL does not mention ansible-lint"
  issues=$((issues+1))
fi

if grep -qi 'molecule' "$DOC"; then
  echo "  OK   mentions Molecule"
else
  echo "  FAIL does not mention Molecule"
  issues=$((issues+1))
fi

# Operational control plane: AWX or AAP.
if grep -qiE 'AWX|AAP|Automation Platform' "$DOC"; then
  echo "  OK   mentions AWX / AAP"
else
  echo "  FAIL does not mention AWX / AAP"
  issues=$((issues+1))
fi

# Event-Driven Ansible.
if grep -qiE 'Event-?Driven|EDA\b|rulebook' "$DOC"; then
  echo "  OK   mentions Event-Driven Ansible / EDA / rulebook"
else
  echo "  FAIL does not mention Event-Driven Ansible / EDA / rulebook"
  issues=$((issues+1))
fi

# At least one fenced code block (table / diagram / snippet).
fences=$(grep -cE '^```' "$DOC")
if [ "$fences" -ge 2 ]; then
  echo "  OK   has at least one fenced code block (${fences} fence lines)"
else
  echo "  FAIL has only ${fences} code-fence lines (expected >=2)"
  issues=$((issues+1))
fi

# Alternatives: at least 2 sub-headings or numbered items under Alternativas.
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
echo "OK: estructura valida — 0 issue(s). Compara ADR-ANSIBLE-CONTRACT.md con solution/REFERENCE.md para autoevaluarte."
exit 0
