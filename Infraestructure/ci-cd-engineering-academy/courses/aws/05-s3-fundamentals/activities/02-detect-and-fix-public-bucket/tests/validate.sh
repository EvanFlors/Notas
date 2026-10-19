#!/usr/bin/env bash
# Structural validation for aws-05-02-detect-and-fix-public-bucket.
#
# Checks:
#   - AUDIT.md exists with the required sections and keywords.
#   - policy-fixed.json: Version, at least one Deny with aws:SecureTransport,
#     no 'Allow' statement with 'Action': 's3:*' (or including 's3:*'),
#     no 'Allow' statement on bucket-wide '*' Resource without a prefix.
#   - bpa-fixed.json: PublicAccessBlockConfiguration with 4/4 true.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.

set -eu

BASE="${1:-/tmp/aws-05-audit}"
fail=0

echo "== Structural validation for $BASE =="

for f in AUDIT.md policy-fixed.json bpa-fixed.json; do
  if [ -f "$BASE/$f" ]; then
    echo "  OK   $f present"
  else
    echo "  FAIL $f missing"
    fail=$((fail+1))
  fi
done

if [ ! -f "$BASE/AUDIT.md" ] \
   || [ ! -f "$BASE/policy-fixed.json" ] \
   || [ ! -f "$BASE/bpa-fixed.json" ]; then
  echo
  echo "RESULT: $fail structural check(s) failed (missing required files)."
  exit 1
fi

# ---- AUDIT.md section headings and keywords.
DOC="$BASE/AUDIT.md"

if grep -qiE '^#+ *(Secci[oó]n +A|Hallazgos)' "$DOC"; then
  echo "  OK   AUDIT.md has Section A (Hallazgos)"
else
  echo "  FAIL AUDIT.md missing Section A / Hallazgos heading"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *(Secci[oó]n +B|Correcciones)' "$DOC"; then
  echo "  OK   AUDIT.md has Section B (Correcciones)"
else
  echo "  FAIL AUDIT.md missing Section B / Correcciones heading"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *(Secci[oó]n +C|Riesgos residuales)' "$DOC"; then
  echo "  OK   AUDIT.md has Section C (Riesgos residuales)"
else
  echo "  FAIL AUDIT.md missing Section C / Riesgos residuales heading"
  fail=$((fail+1))
fi

findings=0
for n in 1 2 3 4; do
  if grep -Eq "^[[:space:]]*${n}\\." "$DOC"; then
    findings=$((findings+1))
  fi
done
if [ "$findings" -ge 4 ]; then
  echo "  OK   AUDIT.md has at least 4 numbered findings"
else
  echo "  FAIL AUDIT.md has $findings numbered items (expected >=4)"
  fail=$((fail+1))
fi

for term in "block public access|bpa" "ownership|bucketowner" \
            "principal" "securetransport"; do
  if grep -qiE "$term" "$DOC"; then
    echo "  OK   AUDIT.md mentions '$term'"
  else
    echo "  FAIL AUDIT.md does not mention '$term'"
    fail=$((fail+1))
  fi
done

# ---- Deep JSON checks in Python
set +e
python3 - "$BASE" <<'PY'
import json, sys, pathlib
base = pathlib.Path(sys.argv[1])
problems = []

# ---- policy-fixed.json
try:
    pol = json.loads((base / "policy-fixed.json").read_text())
except Exception as e:
    problems.append(f"policy-fixed.json: invalid JSON: {e}")
else:
    if pol.get("Version") != "2012-10-17":
        problems.append("policy-fixed.json: Version must be '2012-10-17'")
    stmts = pol.get("Statement") or []
    if not isinstance(stmts, list) or not stmts:
        problems.append("policy-fixed.json: Statement must be non-empty")
    found_deny_tls = False
    for s in stmts:
        actions = s.get("Action")
        if isinstance(actions, str):
            actions = [actions]
        actions = actions or []
        effect = s.get("Effect")
        cond_blob = json.dumps(s.get("Condition", {}))

        if effect == "Deny" and ("s3:*" in actions or "*" in actions) \
                and "aws:SecureTransport" in cond_blob:
            found_deny_tls = True

        if effect == "Allow":
            if any(a == "s3:*" or a == "*" for a in actions):
                problems.append(
                    "policy-fixed.json: Allow with Action 's3:*' or '*' "
                    "is forbidden"
                )
            resources = s.get("Resource")
            if isinstance(resources, str):
                resources = [resources]
            resources = resources or []
            for r in resources:
                if r.endswith(":::") or r.endswith("*") and "/" not in r.split(":::")[-1]:
                    # bare bucket ARN or bucket/* without prefix
                    tail = r.split(":::")[-1]
                    if tail == "*" or "/" not in tail:
                        problems.append(
                            f"policy-fixed.json: Allow on unrestricted "
                            f"Resource '{r}' — must be prefix-scoped"
                        )

    if not found_deny_tls:
        problems.append(
            "policy-fixed.json: need Deny statement on s3:* with "
            "aws:SecureTransport condition"
        )

# ---- bpa-fixed.json
try:
    bpa = json.loads((base / "bpa-fixed.json").read_text())
except Exception as e:
    problems.append(f"bpa-fixed.json: invalid JSON: {e}")
else:
    cfg = bpa.get("PublicAccessBlockConfiguration") or {}
    if not cfg:
        # Accept a flat shape too.
        cfg = bpa
    for k in ("BlockPublicAcls", "IgnorePublicAcls",
              "BlockPublicPolicy", "RestrictPublicBuckets"):
        if cfg.get(k) is not True:
            problems.append(f"bpa-fixed.json: {k} must be true")

if problems:
    print("STRUCTURAL ISSUES:")
    for p in problems:
        print(f"  FAIL {p}")
    sys.exit(1)
print("  OK   JSON structural checks passed")
PY
struct_rc=$?
set -e
if [ "$struct_rc" -ne 0 ]; then
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: estructura valida. Compara con solution/REFERENCE.md para autoevaluarte."
exit 0
