#!/usr/bin/env bash
# Structural + light-semantic validation for
# gcp-09-02-write-org-policy-baseline-and-validate.
#
# Checks that the 4 Org Policy YAMLs and the VPC-SC perimeter YAML exist,
# parse as YAML (via python3 + pyyaml), carry the right name/constraint,
# use enforce/denyAll/allowedValues as appropriate, and include the minimum
# fields expected. Also checks README-INTENT.md has one section per file.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness in a real GCP organization — compare
# manually with solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/gcp-09-org-policy}"
fail=0

echo "== Structural validation for $BASE =="

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: 'python3' is required but not installed."
  exit 2
fi

if ! python3 -c "import yaml" >/dev/null 2>&1; then
  echo "FAIL: python3 'yaml' module (pyyaml) is required. Install with: pip install pyyaml"
  exit 2
fi

check_file_exists() {
  local f="$1"
  if [ -f "$f" ]; then
    echo "  OK   $f exists"
    return 0
  else
    echo "  FAIL $f does not exist"
    fail=$((fail+1))
    return 1
  fi
}

check_yaml_valid() {
  local f="$1"
  if python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" "$f" >/dev/null 2>&1; then
    echo "  OK   $f is valid YAML"
    return 0
  else
    echo "  FAIL $f is not valid YAML"
    fail=$((fail+1))
    return 1
  fi
}

# Run a python expression against the parsed YAML; expression must print 'OK'
# for success. Any other output / exception is a failure.
yaml_assert() {
  local f="$1"
  local expr="$2"
  local label="$3"
  local out
  out=$(python3 - "$f" <<PY 2>/dev/null || true
import sys, yaml
with open(sys.argv[1]) as fh:
    doc = yaml.safe_load(fh)
try:
    if ${expr}:
        print("OK")
    else:
        print("FAIL")
except Exception as exc:
    print("FAIL:" + repr(exc))
PY
)
  if [ "$out" = "OK" ]; then
    echo "  OK   $f: ${label}"
  else
    echo "  FAIL $f: ${label} (python expr: ${expr}; got: ${out})"
    fail=$((fail+1))
  fi
}

# --- org-policy-disable-sa-key-creation.yaml -----------------------------
F1="$BASE/org-policy-disable-sa-key-creation.yaml"
if check_file_exists "$F1"; then
  check_yaml_valid "$F1" || true
  yaml_assert "$F1" \
    "isinstance(doc, dict) and str(doc.get('name','')).startswith('organizations/') and 'iam.disableServiceAccountKeyCreation' in str(doc.get('name',''))" \
    "name targets organizations/.../policies/iam.disableServiceAccountKeyCreation"
  yaml_assert "$F1" \
    "doc.get('spec',{}).get('rules',[{}])[0].get('enforce') is True" \
    "spec.rules[0].enforce == true"
fi

# --- org-policy-vm-external-ip.yaml --------------------------------------
F2="$BASE/org-policy-vm-external-ip.yaml"
if check_file_exists "$F2"; then
  check_yaml_valid "$F2" || true
  yaml_assert "$F2" \
    "'compute.vmExternalIpAccess' in str(doc.get('name',''))" \
    "name targets .../policies/compute.vmExternalIpAccess"
  yaml_assert "$F2" \
    "any(r.get('denyAll') is True or r.get('values',{}).get('deniedValues') or r.get('values',{}).get('allValues')=='DENY' for r in doc.get('spec',{}).get('rules',[]))" \
    "has a rule with denyAll=true or values.deniedValues or allValues=DENY"
fi

# --- org-policy-storage-public-access-prevention.yaml --------------------
F3="$BASE/org-policy-storage-public-access-prevention.yaml"
if check_file_exists "$F3"; then
  check_yaml_valid "$F3" || true
  yaml_assert "$F3" \
    "'storage.publicAccessPrevention' in str(doc.get('name',''))" \
    "name targets .../policies/storage.publicAccessPrevention"
  yaml_assert "$F3" \
    "doc.get('spec',{}).get('rules',[{}])[0].get('enforce') is True" \
    "spec.rules[0].enforce == true"
fi

# --- org-policy-allowed-member-domains.yaml ------------------------------
F4="$BASE/org-policy-allowed-member-domains.yaml"
if check_file_exists "$F4"; then
  check_yaml_valid "$F4" || true
  yaml_assert "$F4" \
    "'iam.allowedPolicyMemberDomains' in str(doc.get('name',''))" \
    "name targets .../policies/iam.allowedPolicyMemberDomains"
  yaml_assert "$F4" \
    "len(doc.get('spec',{}).get('rules',[{}])[0].get('values',{}).get('allowedValues',[])) >= 1" \
    "spec.rules[0].values.allowedValues has at least one customer ID"
fi

# --- vpc-sc-perimeter.yaml -----------------------------------------------
F5="$BASE/vpc-sc-perimeter.yaml"
if check_file_exists "$F5"; then
  check_yaml_valid "$F5" || true
  yaml_assert "$F5" \
    "str(doc.get('name','')).startswith('accessPolicies/') and '/servicePerimeters/' in str(doc.get('name',''))" \
    "name is accessPolicies/.../servicePerimeters/..."
  yaml_assert "$F5" \
    "len(doc.get('status',{}).get('resources',[])) >= 2" \
    "status.resources has at least 2 projects"
  yaml_assert "$F5" \
    "all(str(r).startswith('projects/') for r in doc.get('status',{}).get('resources',[]))" \
    "every resource is in 'projects/<...>' form"
  yaml_assert "$F5" \
    "len(doc.get('status',{}).get('restrictedServices',[])) >= 3" \
    "status.restrictedServices has at least 3 entries"
  yaml_assert "$F5" \
    "all(str(s).endswith('.googleapis.com') for s in doc.get('status',{}).get('restrictedServices',[]))" \
    "every restrictedService is a *.googleapis.com name"
  yaml_assert "$F5" \
    "len(doc.get('status',{}).get('accessLevels',[])) >= 1" \
    "status.accessLevels has at least 1 entry"
fi

# --- Guard: no real project numbers (12-digit numeric) in perimeter resources.
# Placeholders must be used (e.g. projects/<project-number-of-...>).
if [ -f "$F5" ]; then
  if python3 - "$F5" <<'PY' | grep -q "LEAK"
import sys, yaml, re
with open(sys.argv[1]) as fh:
    doc = yaml.safe_load(fh) or {}
for r in doc.get('status',{}).get('resources',[]):
    s = str(r)
    tail = s.split('/',1)[1] if '/' in s else s
    if re.fullmatch(r'\d{10,16}', tail):
        print("LEAK:" + s)
PY
  then
    echo "  FAIL vpc-sc-perimeter.yaml: appears to leak a real project number (use placeholders like <project-number-of-...>)"
    fail=$((fail+1))
  else
    echo "  OK   vpc-sc-perimeter.yaml: resources use placeholder project numbers"
  fi
fi

# --- README-INTENT.md ----------------------------------------------------
DOC="$BASE/README-INTENT.md"
if check_file_exists "$DOC"; then
  for section in "org-policy-disable-sa-key-creation" \
                 "org-policy-vm-external-ip" \
                 "org-policy-storage-public-access-prevention" \
                 "org-policy-allowed-member-domains" \
                 "vpc-sc-perimeter"; do
    if grep -qE "^#+ .*${section}" "$DOC"; then
      echo "  OK   README-INTENT.md has section for ${section}"
    else
      echo "  FAIL README-INTENT.md missing section for ${section}"
      fail=$((fail+1))
    fi
  done
  # Must mention dry-run (VPC-SC adoption best practice).
  if grep -qiE 'dry[- ]?run' "$DOC"; then
    echo "  OK   README-INTENT.md mentions dry-run (VPC-SC)"
  else
    echo "  FAIL README-INTENT.md does not mention dry-run mode for VPC-SC"
    fail=$((fail+1))
  fi
  # Must mention Access Context Manager (access levels source).
  if grep -qiE 'Access +Context +Manager|access +level' "$DOC"; then
    echo "  OK   README-INTENT.md mentions Access Context Manager / access level"
  else
    echo "  FAIL README-INTENT.md does not mention Access Context Manager / access level"
    fail=$((fail+1))
  fi
  # Must mention customer ID (needed for allowed member domains).
  if grep -qiE 'customer +ID|customerId|C0[A-Za-z0-9]{8}' "$DOC"; then
    echo "  OK   README-INTENT.md mentions customer ID"
  else
    echo "  FAIL README-INTENT.md does not mention customer ID"
    fail=$((fail+1))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  echo "        (Semantic correctness in a real GCP organization is NOT verified here.)"
  exit 1
fi
echo "OK: YAMLs y README-INTENT.md pasan validacion estructural."
echo "    Compara con solution/REFERENCE.md para autoevaluacion semantica."
exit 0
