#!/usr/bin/env bash
# Structural validation for gl-09-02-governance-adr.
# Checks that ADR-GOVERNANCE-BASELINE.md exists and contains the required ADR
# sections, the end-to-end diagram, named approval rules, push rules, mentions
# of Compliance Framework, CODEOWNERS, protected branches, SSO/SCIM, audit
# events, a SIEM, a tier decision (Premium/Ultimate), the two workloads and
# an ISO 27001 or SOC2 mapping.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks use
# `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep finds a
# match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/gl-09-governance}"
DOC="$BASE/ADR-GOVERNANCE-BASELINE.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Must look like an ADR.
if grep -qiE '^#+ *ADR' "$DOC"; then
  echo "  OK   ADR-GOVERNANCE-BASELINE.md has an 'ADR' heading"
else
  echo "  FAIL ADR-GOVERNANCE-BASELINE.md missing an 'ADR' heading"
  fail=$((fail+1))
fi

# Required ADR sections.
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

# At least one fenced code block (the end-to-end diagram).
fences=$(grep -cE '^```' "$DOC")
if [ "$fences" -ge 2 ]; then
  echo "  OK   has at least one fenced code block (${fences} fence lines)"
else
  echo "  FAIL has only ${fences} code-fence lines (expected >=2)"
  fail=$((fail+1))
fi

# Diagram must mention the end-to-end chain.
if grep -qiE '(push.*pipeline|pipeline.*approval|approval.*merge|merge.*audit)' "$DOC"; then
  echo "  OK   diagram mentions the push→pipeline→approvals→merge→audit chain"
else
  echo "  FAIL diagram does not mention the end-to-end chain"
  fail=$((fail+1))
fi

# Compliance Framework (central concept).
if grep -qiE 'Compliance +Framework|Compliance +Pipeline' "$DOC"; then
  echo "  OK   mentions Compliance Framework / Compliance Pipeline"
else
  echo "  FAIL does not mention Compliance Framework / Pipeline"
  fail=$((fail+1))
fi

# CODEOWNERS.
if grep -qE 'CODEOWNERS|Code +Owners' "$DOC"; then
  echo "  OK   mentions CODEOWNERS / Code Owners"
else
  echo "  FAIL does not mention CODEOWNERS / Code Owners"
  fail=$((fail+1))
fi

# Protected branches.
if grep -qiE 'protected +branch(es)?' "$DOC"; then
  echo "  OK   mentions protected branches"
else
  echo "  FAIL does not mention protected branches"
  fail=$((fail+1))
fi

# SSO / SAML.
if grep -qiE 'SAML|SSO\b'  "$DOC"; then
  echo "  OK   mentions SAML / SSO"
else
  echo "  FAIL does not mention SAML / SSO"
  fail=$((fail+1))
fi

# SCIM.
if grep -qi 'SCIM' "$DOC"; then
  echo "  OK   mentions SCIM"
else
  echo "  FAIL does not mention SCIM"
  fail=$((fail+1))
fi

# Audit events / stream.
if grep -qiE 'audit +(event|log|stream)' "$DOC"; then
  echo "  OK   mentions audit events / log / stream"
else
  echo "  FAIL does not mention audit events / log / stream"
  fail=$((fail+1))
fi

# SIEM (Splunk, Elastic, Datadog, or the word SIEM).
if grep -qiE 'SIEM|Splunk|Elastic|Datadog' "$DOC"; then
  echo "  OK   mentions a SIEM (SIEM/Splunk/Elastic/Datadog)"
else
  echo "  FAIL does not mention a SIEM / Splunk / Elastic / Datadog"
  fail=$((fail+1))
fi

# Tier decision (Premium or Ultimate).
if grep -qiE 'Premium|Ultimate' "$DOC"; then
  echo "  OK   mentions tier (Premium/Ultimate)"
else
  echo "  FAIL does not mention tier Premium/Ultimate"
  fail=$((fail+1))
fi

# Both workloads mentioned.
if grep -qi 'checkout' "$DOC" && grep -qi 'internal-tools' "$DOC"; then
  echo "  OK   mentions both workloads (checkout and internal-tools)"
else
  echo "  FAIL does not mention both 'checkout' and 'internal-tools'"
  fail=$((fail+1))
fi

# Approval rule concepts: at least 3 distinct tokens.
appr=0
for a in "approvals_required" "code_owner_approval_required" "prevent_author_approval" \
         "prevent_committers_approval" "security_findings" "security-high" \
         "security approval" "report_type" "severity_levels" "reset_on_push" \
         "default-two-approvers"; do
  if grep -qi "$a" "$DOC"; then
    appr=$((appr+1))
  fi
done
if [ "$appr" -ge 3 ]; then
  echo "  OK   mentions >=3 approval rule concepts (${appr} tokens)"
else
  echo "  FAIL mentions only ${appr} approval rule concepts (expected >=3)"
  fail=$((fail+1))
fi

# Push rules: at least 3 distinct tokens.
pr=0
for p in "commit message" "commit msg" "regex" "deny .*secret" "secret files" \
         "unsigned commit" "signed commit" "author email" "author domain" \
         "branch name" "file size" "max.*size" "push rule"; do
  if grep -qiE "$p" "$DOC"; then
    pr=$((pr+1))
  fi
done
if [ "$pr" -ge 3 ]; then
  echo "  OK   mentions >=3 push rule concepts (${pr} tokens)"
else
  echo "  FAIL mentions only ${pr} push rule concepts (expected >=3)"
  fail=$((fail+1))
fi

# ISO 27001 or SOC2 mapping.
if grep -qiE 'ISO +27001|SOC2|SOC +2' "$DOC"; then
  echo "  OK   maps to ISO 27001 or SOC2"
else
  echo "  FAIL does not map to ISO 27001 / SOC2"
  fail=$((fail+1))
fi

# Alternatives section must list at least 2 alternatives.
alt_items=$(grep -cEi '^#+ +(Alt|Opci[oó]n|Alternativa)' "$DOC" || true)
alt_num=$(grep -cE '^[[:space:]]*[12]\. ' "$DOC" || true)
if [ "$alt_items" -ge 2 ] || [ "$alt_num" -ge 2 ]; then
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
echo "OK: estructura valida. Compara ADR-GOVERNANCE-BASELINE.md con solution/REFERENCE.md para autoevaluarte."
exit 0
