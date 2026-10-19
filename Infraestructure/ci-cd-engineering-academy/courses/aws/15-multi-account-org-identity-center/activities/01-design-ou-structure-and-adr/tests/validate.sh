#!/usr/bin/env bash
# Structural validation for aws-15-01-design-ou-structure-and-adr.
# Checks that ADR-ORG-STRUCTURE.md exists and contains the required ADR
# sections, the OU diagram, named accounts, SCPs, Permission Sets, and
# the explicit decision about one-account-per-app vs N-accounts-per-app.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/aws-15-ou-adr}"
DOC="$BASE/ADR-ORG-STRUCTURE.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Must look like an ADR (title mentioning ADR).
if grep -qiE '^#+ *ADR' "$DOC"; then
  echo "  OK   ADR-ORG-STRUCTURE.md has an 'ADR' heading"
else
  echo "  FAIL ADR-ORG-STRUCTURE.md missing an 'ADR' heading"
  fail=$((fail+1))
fi

# Required ADR sections.
for section in "Estado|Status" "Contexto|Context" "Decisi[oó]n|Decision" \
               "Consecuencias|Consequences" "Alternativas|Alternatives"; do
  label="${section%%|*}"
  if grep -qiE "^#+ *(${section})\\b" "$DOC"; then
    echo "  OK   ADR-ORG-STRUCTURE.md has '${label}' section"
  else
    echo "  FAIL ADR-ORG-STRUCTURE.md missing '${label}' section"
    fail=$((fail+1))
  fi
done

# Must have at least one fenced code block (the OU diagram).
fences=$(grep -cE '^```' "$DOC")
if [ "$fences" -ge 2 ]; then
  echo "  OK   has at least one fenced code block (${fences} fence lines)"
else
  echo "  FAIL has only ${fences} code-fence lines (expected >=2, a diagram block needs opening+closing)"
  fail=$((fail+1))
fi

# Diagram must mention 'Root' or 'OU' or 'Organization' (tree root cue).
if grep -qiE 'Root|OU|Organization' "$DOC"; then
  echo "  OK   mentions Root/OU/Organization"
else
  echo "  FAIL does not mention Root/OU/Organization"
  fail=$((fail+1))
fi

# Must mention AWS Organizations and IAM Identity Center (the two central
# services of the module).
if grep -qiE 'AWS +Organizations|Organizations\b' "$DOC"; then
  echo "  OK   mentions AWS Organizations"
else
  echo "  FAIL does not mention AWS Organizations"
  fail=$((fail+1))
fi

if grep -qiE 'Identity +Center|AWS +SSO|IdC\b' "$DOC"; then
  echo "  OK   mentions IAM Identity Center (or AWS SSO / IdC)"
else
  echo "  FAIL does not mention IAM Identity Center / AWS SSO / IdC"
  fail=$((fail+1))
fi

# Must name at least 4 accounts from a canonical set.
accts=0
for a in "management" "log-archive" "log archive" "audit" "checkout" \
         "analytics" "sandbox" "shared-services" "tools"; do
  if grep -qi "$a" "$DOC"; then
    accts=$((accts+1))
  fi
done
if [ "$accts" -ge 4 ]; then
  echo "  OK   names at least 4 accounts/roles (${accts} tokens found)"
else
  echo "  FAIL names only ${accts} account tokens (expected >=4)"
  fail=$((fail+1))
fi

# Must name at least 3 SCPs from the baseline (any wording).
scps=0
for s in "deny-regions" "deny regions" "deny-leave" "LeaveOrganization" \
         "disable-logging" "disable logging" "deny-all" "deny-root" \
         "StopLogging" "require-mfa" "deny-public"; do
  if grep -qi "$s" "$DOC"; then
    scps=$((scps+1))
  fi
done
if [ "$scps" -ge 3 ]; then
  echo "  OK   names at least 3 SCPs/baseline guardrails (${scps} tokens found)"
else
  echo "  FAIL names only ${scps} SCP tokens (expected >=3)"
  fail=$((fail+1))
fi

# Must name at least 3 Permission Sets from the canonical catalog.
ps=0
for p in "AdministratorAccess" "ReadOnlyAccess" "PowerUserAccess" \
         "Billing" "SecurityAudit" "BreakGlass"; do
  if grep -q "$p" "$DOC"; then
    ps=$((ps+1))
  fi
done
if [ "$ps" -ge 3 ]; then
  echo "  OK   names at least 3 Permission Sets (${ps} tokens found)"
else
  echo "  FAIL names only ${ps} Permission Set tokens (expected >=3)"
  fail=$((fail+1))
fi

# Must mention Europe / region constraint.
if grep -qiE 'europ|eu-west|eu-central|eu-south|eu-north' "$DOC"; then
  echo "  OK   mentions Europe / eu-* region constraint"
else
  echo "  FAIL does not mention Europe / eu-* region"
  fail=$((fail+1))
fi

# Must explicitly decide per workload (checkout and analytics mentioned).
if grep -qi 'checkout' "$DOC" && grep -qi 'analytics' "$DOC"; then
  echo "  OK   mentions both workloads (checkout and analytics)"
else
  echo "  FAIL does not mention both 'checkout' and 'analytics' workloads"
  fail=$((fail+1))
fi

# Alternatives section must list at least 2 alternatives (look for 2 subheadings
# under Alternativas or 2 numbered items).
alt_items=$(grep -cEi '^#+ +(Alt|Opci[oó]n|Alternativa)' "$DOC" \
            || true)
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
echo "OK: estructura valida. Compara ADR-ORG-STRUCTURE.md con solution/REFERENCE.md para autoevaluarte."
exit 0
