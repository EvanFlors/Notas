#!/usr/bin/env bash
# Structural validation for gcp-09-01-design-folder-structure-and-adr.
# Checks that ADR-ORG-STRUCTURE.md exists and contains the required ADR
# sections, the folder diagram, named projects, Org Policies, Cloud Identity
# groups, the VPC-SC mention and the explicit decision about one-project-per-app
# vs one-project-per-env.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/gcp-09-folder-adr}"
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

# Must have at least one fenced code block (the folder diagram).
fences=$(grep -cE '^```' "$DOC")
if [ "$fences" -ge 2 ]; then
  echo "  OK   has at least one fenced code block (${fences} fence lines)"
else
  echo "  FAIL has only ${fences} code-fence lines (expected >=2, a diagram block needs opening+closing)"
  fail=$((fail+1))
fi

# Diagram must mention 'Organization' or 'Folder' or 'Resource Manager'.
if grep -qiE 'Organization|Folder|Resource +Manager'  "$DOC"; then
  echo "  OK   mentions Organization/Folder/Resource Manager"
else
  echo "  FAIL does not mention Organization/Folder/Resource Manager"
  fail=$((fail+1))
fi

# Must mention Cloud Identity (central identity source of the module).
if grep -qiE 'Cloud +Identity' "$DOC"; then
  echo "  OK   mentions Cloud Identity"
else
  echo "  FAIL does not mention Cloud Identity"
  fail=$((fail+1))
fi

# Must mention VPC Service Controls / VPC-SC (perimeter design is required).
if grep -qiE 'VPC +Service +Controls|VPC-SC|service +perimeter' "$DOC"; then
  echo "  OK   mentions VPC Service Controls / VPC-SC / service perimeter"
else
  echo "  FAIL does not mention VPC Service Controls / VPC-SC"
  fail=$((fail+1))
fi

# Must name at least 4 projects from a canonical set.
projs=0
for p in "org-admin" "logging-prod" "security-audit" "shared-vpc-host" \
         "artifact-registry" "tools-shared" "checkout-prod" "checkout-stg" \
         "checkout-dev" "analytics-prod" "analytics-dev" "analytics-stg" \
         "sandbox-shared"; do
  if grep -qi "$p" "$DOC"; then
    projs=$((projs+1))
  fi
done
if [ "$projs" -ge 4 ]; then
  echo "  OK   names at least 4 projects (${projs} tokens found)"
else
  echo "  FAIL names only ${projs} project tokens (expected >=4)"
  fail=$((fail+1))
fi

# Must name at least 3 Org Policies from the baseline (constraint IDs).
ops=0
for c in "iam.disableServiceAccountKeyCreation" "compute.vmExternalIpAccess" \
         "storage.publicAccessPrevention" "iam.allowedPolicyMemberDomains" \
         "compute.restrictVpcPeering" "compute.requireOsLogin" \
         "sql.restrictPublicIp" "compute.restrictSharedVpcHostProjects"; do
  if grep -q "$c" "$DOC"; then
    ops=$((ops+1))
  fi
done
if [ "$ops" -ge 3 ]; then
  echo "  OK   names at least 3 Org Policy constraints (${ops} tokens found)"
else
  echo "  FAIL names only ${ops} Org Policy constraints (expected >=3)"
  fail=$((fail+1))
fi

# Must name at least 3 Cloud Identity groups from a canonical set.
grps=0
for g in "gcp-org-admins" "gcp-billing-admins" "gcp-security" "gcp-platform" \
         "gcp-dev-engineers" "gcp-prod-sre" "gcp-breakglass" "gcp-sandbox"; do
  if grep -qi "$g" "$DOC"; then
    grps=$((grps+1))
  fi
done
if [ "$grps" -ge 3 ]; then
  echo "  OK   names at least 3 Cloud Identity groups (${grps} tokens found)"
else
  echo "  FAIL names only ${grps} Cloud Identity group tokens (expected >=3)"
  fail=$((fail+1))
fi

# Must mention Europe / region constraint.
if grep -qiE 'europ|europe-west|europe-central|europe-north|europe-south' "$DOC"; then
  echo "  OK   mentions Europe / europe-* region constraint"
else
  echo "  FAIL does not mention Europe / europe-* region"
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
