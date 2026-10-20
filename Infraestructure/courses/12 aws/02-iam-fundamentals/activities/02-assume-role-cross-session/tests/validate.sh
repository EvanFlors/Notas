#!/usr/bin/env bash
# Structural validation for aws-02-02-assume-role-cross-session.
# Checks that the three JSON policies parse and have the expected shape,
# that SESSION.md has the required sections, and that NO real-looking
# account IDs are leaked (only 111111111111 / 222222222222 / 123456789012
# are allowed as 12-digit numbers).
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/aws-02-chain}"
TRUST_OP="$BASE/TRUST_OPERATOR.json"
TRUST_PR="$BASE/TRUST_PROD.json"
PERM_PR="$BASE/PERM_PROD.json"
DOC="$BASE/SESSION.md"
fail=0

echo "== Structural validation for $BASE =="

for f in "$TRUST_OP" "$TRUST_PR" "$PERM_PR" "$DOC"; do
  if [ ! -f "$f" ]; then
    echo "FAIL: $f does not exist. Student must produce it."
    exit 1
  fi
done

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: python3 is required but not found in PATH."
  exit 1
fi

python3 - "$TRUST_OP" "$TRUST_PR" "$PERM_PR" <<'PY'
import json, re, sys
trust_op, trust_pr, perm_pr = sys.argv[1], sys.argv[2], sys.argv[3]
issues = []

def load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception as e:
        issues.append(f"{path}: does not parse as JSON: {e}")
        return None

def as_list(x):
    if x is None: return []
    return x if isinstance(x, list) else [x]

docs = {p: load(p) for p in (trust_op, trust_pr, perm_pr)}
if any(d is None for d in docs.values()):
    for msg in issues: print(f"FAIL  {msg}")
    sys.exit(2)

# Basic shape: Version + Statement list.
for path, d in docs.items():
    if not isinstance(d, dict) or d.get("Version") != "2012-10-17":
        issues.append(f"{path}: must have Version 2012-10-17")
    if not isinstance(d.get("Statement"), list) or len(d["Statement"]) < 1:
        issues.append(f"{path}: Statement must be a non-empty list")

d_op = docs[trust_op]
d_pr = docs[trust_pr]
d_perm = docs[perm_pr]

# --- TRUST_OPERATOR.json ---
op_blob = json.dumps(d_op)
op_actions = []
op_has_mfa = False
for s in (d_op.get("Statement") or []):
    op_actions.extend(as_list(s.get("Action")))
    cond = s.get("Condition") or {}
    if isinstance(cond, dict):
        for op, kv in cond.items():
            if isinstance(kv, dict) and any("aws:MultiFactorAuthPresent" == k for k in kv.keys()):
                op_has_mfa = True
if "sts:AssumeRole" not in op_actions:
    issues.append("TRUST_OPERATOR.json: Action must include sts:AssumeRole")
if "111111111111" not in op_blob:
    issues.append("TRUST_OPERATOR.json: must reference hub account 111111111111 in Principal")
if not op_has_mfa:
    issues.append("TRUST_OPERATOR.json: Condition must require aws:MultiFactorAuthPresent")

# --- TRUST_PROD.json ---
pr_blob = json.dumps(d_pr)
pr_actions = []
pr_has_external_id = False
for s in (d_pr.get("Statement") or []):
    pr_actions.extend(as_list(s.get("Action")))
    cond = s.get("Condition") or {}
    if isinstance(cond, dict):
        for op, kv in cond.items():
            if isinstance(kv, dict) and any("sts:ExternalId" == k for k in kv.keys()):
                pr_has_external_id = True
if "sts:AssumeRole" not in pr_actions:
    issues.append("TRUST_PROD.json: Action must include sts:AssumeRole")
if "OperatorRole" not in pr_blob:
    issues.append("TRUST_PROD.json: Principal must reference OperatorRole")
if "111111111111" not in pr_blob:
    issues.append("TRUST_PROD.json: Principal must reference hub account 111111111111")
if not pr_has_external_id:
    issues.append("TRUST_PROD.json: Condition must include sts:ExternalId")

# --- PERM_PROD.json ---
perm_blob = json.dumps(d_perm)
perm_actions = []
perm_resources = []
for s in (d_perm.get("Statement") or []):
    perm_actions.extend(as_list(s.get("Action")))
    perm_resources.extend(as_list(s.get("Resource")))
if "*" in perm_actions or "s3:*" in perm_actions:
    issues.append("PERM_PROD.json: Action must not be '*' nor 's3:*'")
if "*" in perm_resources:
    issues.append("PERM_PROD.json: Resource must not be '*'")
if "s3:ListBucket" not in perm_actions:
    issues.append("PERM_PROD.json: Action must include s3:ListBucket")
if "s3:GetObject" not in perm_actions:
    issues.append("PERM_PROD.json: Action must include s3:GetObject")
if "acme-prod" not in " ".join(perm_resources):
    issues.append("PERM_PROD.json: Resource ARNs must reference 'acme-prod' prefix")

# --- Leak check: any 12-digit number that is not a known placeholder. ---
ALLOWED_IDS = {"111111111111", "222222222222", "123456789012"}
all_blob = op_blob + " " + pr_blob + " " + perm_blob
for match in re.findall(r"\b\d{12}\b", all_blob):
    if match not in ALLOWED_IDS:
        issues.append(f"Possible real AWS account ID leak in JSON: {match}. "
                      "Use 111111111111 / 222222222222 / 123456789012 instead.")

if issues:
    for msg in issues: print(f"FAIL  {msg}")
    sys.exit(2)
print("OK    All three policies parse and structural checks pass")
sys.exit(0)
PY
py_rc=$?
if [ "$py_rc" -ne 0 ]; then
  fail=$((fail+1))
fi

# --- SESSION.md sections ---
for section_regex in \
  '^#+ *Cadena' \
  '^#+ *Qu[eé] hace STS en cada salto' \
  '^#+ *Trazas en CloudTrail' \
  '^#+ *Por qu[eé] este dise[ñn]o' \
  '^#+ *Rol del ExternalId' \
; do
  if grep -qiE "$section_regex" "$DOC"; then
    echo "  OK   SESSION.md has section matching: $section_regex"
  else
    echo "  FAIL SESSION.md missing section matching: $section_regex"
    fail=$((fail+1))
  fi
done

for kw in 'STS' 'CloudTrail' 'ExternalId' 'MFA'; do
  if grep -q "$kw" "$DOC"; then
    echo "  OK   SESSION.md mentions $kw"
  else
    echo "  FAIL SESSION.md does not mention $kw"
    fail=$((fail+1))
  fi
done

# Leak check also on SESSION.md.
leaks=$(grep -oE '\b[0-9]{12}\b' "$DOC" | grep -vE '^(111111111111|222222222222|123456789012)$' || true)
if [ -n "$leaks" ]; then
  echo "  FAIL SESSION.md contains possible real account ID(s): $leaks"
  fail=$((fail+1))
else
  echo "  OK   SESSION.md has no leaked account IDs"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara los JSON / SESSION.md con solution/REFERENCE.md para autoevaluarte."
exit 0
