#!/usr/bin/env bash
# Structural validation for aws-02-01-write-least-privilege-policy.
# Checks that POLICY.json parses as JSON and has the expected shape
# (version, statements, no dangerous wildcards, mentions the right bucket
# and prefix), and that JUSTIFICATION.md has the required sections.
#
# If AWS credentials are present (AWS_PROFILE or AWS_ACCESS_KEY_ID),
# tries `aws iam simulate-custom-policy` as a best-effort sanity check.
# Lack of credentials or permission is SKIPPED, not failed.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/aws-02-lpp}"
POLICY="$BASE/POLICY.json"
DOC="$BASE/JUSTIFICATION.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$POLICY" ]; then
  echo "FAIL: $POLICY does not exist. Student must produce it."
  exit 1
fi
if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# --- JSON parse + structure (via python3) ---
if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: python3 is required but not found in PATH."
  exit 1
fi

python3 - "$POLICY" <<'PY'
import json, sys
path = sys.argv[1]
issues = []
try:
    with open(path) as f:
        doc = json.load(f)
except Exception as e:
    print(f"FAIL  POLICY.json does not parse as JSON: {e}")
    sys.exit(2)

if not isinstance(doc, dict):
    print("FAIL  POLICY.json root is not an object")
    sys.exit(2)

if doc.get("Version") != "2012-10-17":
    issues.append("Version must be '2012-10-17'")

stmts = doc.get("Statement")
if not isinstance(stmts, list) or len(stmts) < 2:
    issues.append("Statement must be a list with at least 2 items")
    stmts = []

def as_list(x):
    if x is None: return []
    return x if isinstance(x, list) else [x]

all_actions = []
all_resources = []
for i, s in enumerate(stmts):
    if not isinstance(s, dict):
        issues.append(f"Statement[{i}] is not an object"); continue
    for k in ("Effect", "Action", "Resource"):
        if k not in s:
            issues.append(f"Statement[{i}] missing '{k}'")
    all_actions.extend(as_list(s.get("Action")))
    all_resources.extend(as_list(s.get("Resource")))

# Dangerous wildcards.
dangerous_actions = {"*", "s3:*"}
if any(a in dangerous_actions for a in all_actions):
    issues.append("Policy contains a dangerous Action wildcard ('*' or 's3:*')")
if "*" in all_resources:
    issues.append("Policy contains Resource '*' which is overly broad")

# Required actions present.
if not any(a == "s3:ListBucket" for a in all_actions):
    issues.append("Policy must include s3:ListBucket action")
if not any(a == "s3:GetObject" for a in all_actions):
    issues.append("Policy must include s3:GetObject action")

# Bucket + prefix mentioned.
res_blob = " ".join(all_resources)
if "acme-reports" not in res_blob:
    issues.append("Policy must reference bucket 'acme-reports' in Resource ARNs")
if "monthly" not in res_blob:
    issues.append("Policy must reference prefix 'monthly' in object-level ARN")

# A ListBucket statement should have a prefix Condition.
has_prefix_cond = False
for s in stmts:
    if not isinstance(s, dict): continue
    acts = as_list(s.get("Action"))
    cond = s.get("Condition") or {}
    if "s3:ListBucket" in acts and isinstance(cond, dict):
        for op, kv in cond.items():
            if isinstance(kv, dict) and any("s3:prefix" == k for k in kv.keys()):
                has_prefix_cond = True
if not has_prefix_cond:
    issues.append("ListBucket statement should have a Condition on s3:prefix")

if issues:
    for msg in issues:
        print(f"FAIL  {msg}")
    sys.exit(2)

print("OK    POLICY.json parses and structural checks pass")
sys.exit(0)
PY
py_rc=$?
if [ "$py_rc" -ne 0 ]; then
  fail=$((fail+1))
fi

# --- JUSTIFICATION.md sections ---
for section_regex in \
  '^#+ *Qu[eé] conced[ií]a la original' \
  '^#+ *Decisiones de la nueva policy' \
  '^#+ *Lo que deliberadamente dej[eé] fuera' \
  '^#+ *C[óo]mo lo validar[ií]a contra el motor real' \
; do
  if grep -qiE "$section_regex" "$DOC"; then
    echo "  OK   JUSTIFICATION.md has section matching: $section_regex"
  else
    echo "  FAIL JUSTIFICATION.md missing section matching: $section_regex"
    fail=$((fail+1))
  fi
done

# Must mention 'simulate' (simulator) somewhere.
if grep -qi 'simulate' "$DOC"; then
  echo "  OK   JUSTIFICATION.md mentions simulate / simulator"
else
  echo "  FAIL JUSTIFICATION.md does not mention 'simulate' / policy simulator"
  fail=$((fail+1))
fi

# --- Optional: aws iam simulate-custom-policy if creds available ---
have_creds=0
if [ "${AWS_ACCESS_KEY_ID:-}" != "" ] || [ "${AWS_PROFILE:-}" != "" ]; then
  have_creds=1
fi
if [ "$have_creds" -eq 1 ] && command -v aws >/dev/null 2>&1; then
  echo "  INFO AWS credentials detected, attempting simulate-custom-policy..."
  if aws iam simulate-custom-policy \
       --policy-input-list "file://$POLICY" \
       --action-names s3:GetObject s3:PutObject \
       --resource-arns arn:aws:s3:::acme-reports/monthly/x.pdf \
       >/dev/null 2>&1; then
    echo "  OK   simulate-custom-policy call succeeded"
  else
    echo "  SKIP simulate-custom-policy failed (no permission or offline); not counted as failure"
  fi
else
  echo "  SKIP no AWS credentials in env; skipping simulate-custom-policy"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara POLICY.json / JUSTIFICATION.md con solution/REFERENCE.md para autoevaluarte."
exit 0
