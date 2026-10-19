#!/usr/bin/env bash
# Structural validation for az-09-01-design-mg-structure-and-adr.
# Checks that ADR-MG-STRUCTURE.md exists and contains the required ADR
# sections, the MG diagram, named subscriptions, Azure Policies, roles,
# the explicit decision about one-sub-per-app vs N-subs-per-app for
# `checkout` and `analytics`, mention of PIM, Entra ID, Management Groups,
# CAF/ALZ/Enterprise Scale, and Europe.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/az-09-mg-adr}"
DOC="$BASE/ADR-MG-STRUCTURE.md"
issues=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Must look like an ADR (title mentioning ADR).
if grep -qiE '^#+ *ADR' "$DOC"; then
  echo "  OK   ADR-MG-STRUCTURE.md has an 'ADR' heading"
else
  echo "  FAIL ADR-MG-STRUCTURE.md missing an 'ADR' heading"
  issues=$((issues+1))
fi

# Required ADR sections.
for section in "Estado|Status" "Contexto|Context" "Decisi[oó]n|Decision" \
               "Consecuencias|Consequences" "Alternativas|Alternatives"; do
  label="${section%%|*}"
  if grep -qiE "^#+ *(${section})\\b" "$DOC"; then
    echo "  OK   ADR-MG-STRUCTURE.md has '${label}' section"
  else
    echo "  FAIL ADR-MG-STRUCTURE.md missing '${label}' section"
    issues=$((issues+1))
  fi
done

# Must have at least one fenced code block (the MG diagram).
fences=$(grep -cE '^```' "$DOC")
if [ "$fences" -ge 2 ]; then
  echo "  OK   has at least one fenced code block (${fences} fence lines)"
else
  echo "  FAIL has only ${fences} code-fence lines (expected >=2, a diagram block needs opening+closing)"
  issues=$((issues+1))
fi

# Diagram must mention 'Root' or 'MG' or 'Management Group' or 'Tenant' (tree root cue).
if grep -qiE 'Root|Management +Group|\bMG\b|Tenant' "$DOC"; then
  echo "  OK   mentions Root/MG/Management Group/Tenant"
else
  echo "  FAIL does not mention Root/MG/Management Group/Tenant"
  issues=$((issues+1))
fi

# Must mention Management Groups and Entra ID (or Azure AD).
if grep -qiE 'Management +Groups?|\bMGs?\b' "$DOC"; then
  echo "  OK   mentions Management Groups"
else
  echo "  FAIL does not mention Management Groups"
  issues=$((issues+1))
fi

if grep -qiE 'Entra +ID|Azure +AD|Microsoft +Entra' "$DOC"; then
  echo "  OK   mentions Microsoft Entra ID (or Azure AD)"
else
  echo "  FAIL does not mention Microsoft Entra ID / Azure AD"
  issues=$((issues+1))
fi

# Must mention PIM.
if grep -qiE 'PIM|Privileged +Identity +Management' "$DOC"; then
  echo "  OK   mentions PIM (Privileged Identity Management)"
else
  echo "  FAIL does not mention PIM / Privileged Identity Management"
  issues=$((issues+1))
fi

# Must mention CAF / ALZ / Enterprise Scale / Landing Zone.
if grep -qiE 'CAF|Enterprise +Scale|\bALZ\b|Landing +Zone' "$DOC"; then
  echo "  OK   mentions CAF / Enterprise Scale / ALZ / Landing Zone"
else
  echo "  FAIL does not mention CAF / Enterprise Scale / ALZ / Landing Zone"
  issues=$((issues+1))
fi

# Must name at least 4 subscriptions / platform-roles from a canonical set.
subs=0
for a in "management" "connectivity" "identity" "checkout" "analytics" \
         "sandbox" "platform" "corp" "online" "decommissioned"; do
  if grep -qi "$a" "$DOC"; then
    subs=$((subs+1))
  fi
done
if [ "$subs" -ge 4 ]; then
  echo "  OK   names at least 4 subscription/MG tokens (${subs} tokens found)"
else
  echo "  FAIL names only ${subs} subscription/MG tokens (expected >=4)"
  issues=$((issues+1))
fi

# Must name at least 3 Azure Policies from the baseline (any wording).
pols=0
for s in "deny-locations" "deny locations" "allowed-locations" \
         "deny-public-ip" "deny public ip" "public-ip" \
         "audit-diagnostic-settings" "diagnostic settings" "diagnosticSettings" \
         "require-tags" "require tags" "deny-rdp" "deny-nsg" \
         "deny-all" "require-waf"; do
  if grep -qi "$s" "$DOC"; then
    pols=$((pols+1))
  fi
done
if [ "$pols" -ge 3 ]; then
  echo "  OK   names at least 3 Azure Policies / baseline guardrails (${pols} tokens found)"
else
  echo "  FAIL names only ${pols} Azure Policy tokens (expected >=3)"
  issues=$((issues+1))
fi

# Must name at least 3 built-in roles from the canonical catalog.
roles=0
for p in "Owner" "Contributor" "Reader" "Network Contributor" \
         "Key Vault" "Monitoring Reader" "User Access Administrator" \
         "Storage Blob Data"; do
  if grep -q "$p" "$DOC"; then
    roles=$((roles+1))
  fi
done
if [ "$roles" -ge 3 ]; then
  echo "  OK   names at least 3 built-in roles (${roles} tokens found)"
else
  echo "  FAIL names only ${roles} role tokens (expected >=3)"
  issues=$((issues+1))
fi

# Must mention Europe / westeurope / northeurope / eu-* region constraint.
if grep -qiE 'europ|westeurope|northeurope|eu-west|eu-central|eu-south|eu-north' "$DOC"; then
  echo "  OK   mentions Europe / westeurope / northeurope / eu-* region constraint"
else
  echo "  FAIL does not mention Europe / westeurope / northeurope"
  issues=$((issues+1))
fi

# Must explicitly decide per workload (checkout and analytics mentioned).
if grep -qi 'checkout' "$DOC" && grep -qi 'analytics' "$DOC"; then
  echo "  OK   mentions both workloads (checkout and analytics)"
else
  echo "  FAIL does not mention both 'checkout' and 'analytics' workloads"
  issues=$((issues+1))
fi

# Alternatives section must list at least 2 alternatives (look for 2 subheadings
# or 2 numbered items).
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
  echo "RESULT: $issues issue(s) found."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "RESULT: 0 issue(s). Estructura valida."
echo "Compara ADR-MG-STRUCTURE.md con solution/REFERENCE.md para autoevaluarte."
exit 0
