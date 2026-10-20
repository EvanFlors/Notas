#!/usr/bin/env bash
# Structural + optional dynamic validation for aws-05-01.
#
# Checks:
#   - lifecycle.json / bucket-policy.json / event-notification.json are
#     parseable and contain the required structural keys (via Python).
#   - NOTES.md and bucket-name.txt exist.
#   - If LocalStack is reachable and the bucket named in bucket-name.txt
#     exists, verifies BPA = 4/4 true, versioning Enabled, lifecycle and
#     policy present. Otherwise prints SKIP for dynamic checks.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.

set -eu

BASE="${1:-/tmp/aws-05-upload}"
fail=0

echo "== Structural validation for $BASE =="

for f in lifecycle.json bucket-policy.json event-notification.json \
         bucket-name.txt NOTES.md; do
  if [ -f "$BASE/$f" ]; then
    echo "  OK   $f present"
  else
    echo "  FAIL $f missing"
    fail=$((fail+1))
  fi
done

# Short-circuit: without the JSONs there is nothing structural to check.
if [ ! -f "$BASE/lifecycle.json" ] || \
   [ ! -f "$BASE/bucket-policy.json" ] || \
   [ ! -f "$BASE/event-notification.json" ]; then
  echo
  echo "RESULT: $fail structural check(s) failed (missing required files)."
  exit 1
fi

set +e
python3 - "$BASE" <<'PY'
import json, sys, pathlib
base = pathlib.Path(sys.argv[1])
problems = []

ALLOWED_CLASSES = {
    "STANDARD", "STANDARD_IA", "ONEZONE_IA", "INTELLIGENT_TIERING",
    "GLACIER", "GLACIER_IR", "DEEP_ARCHIVE", "REDUCED_REDUNDANCY",
}

# ---- lifecycle.json
try:
    lc = json.loads((base / "lifecycle.json").read_text())
except Exception as e:
    problems.append(f"lifecycle.json: invalid JSON: {e}")
else:
    rules = lc.get("Rules")
    if not isinstance(rules, list) or not rules:
        problems.append("lifecycle.json: Rules must be a non-empty list")
    else:
        r0 = rules[0]
        if not r0.get("ID"):
            problems.append("lifecycle.json: Rules[0].ID required")
        if r0.get("Status") != "Enabled":
            problems.append("lifecycle.json: Rules[0].Status must be 'Enabled'")
        if "Filter" not in r0:
            problems.append("lifecycle.json: Rules[0].Filter required")
        has_action = any(k in r0 for k in ("Transitions", "Expiration"))
        if not has_action:
            problems.append("lifecycle.json: need Transitions or Expiration")
        if "NoncurrentVersionExpiration" not in r0:
            problems.append("lifecycle.json: NoncurrentVersionExpiration required")
        if "AbortIncompleteMultipartUpload" not in r0:
            problems.append("lifecycle.json: AbortIncompleteMultipartUpload required")
        for t in r0.get("Transitions", []) or []:
            sc = t.get("StorageClass")
            if sc not in ALLOWED_CLASSES:
                problems.append(f"lifecycle.json: invalid StorageClass '{sc}'")

# ---- bucket-policy.json
try:
    pol = json.loads((base / "bucket-policy.json").read_text())
except Exception as e:
    problems.append(f"bucket-policy.json: invalid JSON: {e}")
else:
    if pol.get("Version") != "2012-10-17":
        problems.append("bucket-policy.json: Version must be '2012-10-17'")
    stmts = pol.get("Statement")
    if not isinstance(stmts, list) or not stmts:
        problems.append("bucket-policy.json: Statement must be a non-empty list")
    else:
        found_deny_tls = False
        for s in stmts:
            if (s.get("Effect") == "Deny"
                and s.get("Action") in ("s3:*", ["s3:*"])
                and "aws:SecureTransport" in json.dumps(s.get("Condition", {}))):
                found_deny_tls = True
                break
        if not found_deny_tls:
            problems.append(
                "bucket-policy.json: need a Deny statement on s3:* "
                "with aws:SecureTransport condition"
            )

# ---- event-notification.json
try:
    ev = json.loads((base / "event-notification.json").read_text())
except Exception as e:
    problems.append(f"event-notification.json: invalid JSON: {e}")
else:
    kinds = ["QueueConfigurations", "TopicConfigurations",
             "LambdaFunctionConfigurations", "EventBridgeConfiguration"]
    present = [k for k in kinds if k in ev]
    if not present:
        problems.append(
            "event-notification.json: need at least one of "
            + ", ".join(kinds)
        )
    else:
        # If a list-based configuration is used, require at least one Events entry.
        for k in ("QueueConfigurations", "TopicConfigurations",
                  "LambdaFunctionConfigurations"):
            if k in ev:
                items = ev[k] or []
                if not items:
                    problems.append(f"event-notification.json: {k} is empty")
                    continue
                evs = items[0].get("Events") or []
                if not any(e.startswith("s3:") for e in evs):
                    problems.append(
                        f"event-notification.json: {k}[0].Events must list "
                        "at least one s3:* event"
                    )

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

# ---- Dynamic (LocalStack) checks, best-effort
echo
echo "== Dynamic validation (LocalStack) =="

HEALTH_URL="${AWS_ENDPOINT_URL:-http://localhost:4566}/_localstack/health"
if ! command -v curl >/dev/null 2>&1; then
  echo "  SKIP curl not available"
elif ! curl -sf "$HEALTH_URL" >/dev/null 2>&1; then
  echo "  SKIP LocalStack not reachable at ${HEALTH_URL%/_localstack/health}"
elif ! command -v aws >/dev/null 2>&1; then
  echo "  SKIP aws CLI not available"
else
  BUCKET="$(head -n1 "$BASE/bucket-name.txt" 2>/dev/null || true)"
  if [ -z "$BUCKET" ]; then
    echo "  SKIP bucket-name.txt is empty"
  else
    export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
    export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
    export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
    export AWS_ENDPOINT_URL="${AWS_ENDPOINT_URL:-http://localhost:4566}"

    if aws s3api head-bucket --bucket "$BUCKET" >/dev/null 2>&1; then
      echo "  OK   bucket '$BUCKET' exists"

      bpa=$(aws s3api get-public-access-block --bucket "$BUCKET" \
            --output json 2>/dev/null || echo '{}')
      if echo "$bpa" | grep -q '"BlockPublicAcls": true' \
         && echo "$bpa" | grep -q '"IgnorePublicAcls": true' \
         && echo "$bpa" | grep -q '"BlockPublicPolicy": true' \
         && echo "$bpa" | grep -q '"RestrictPublicBuckets": true'; then
        echo "  OK   Block Public Access = 4/4 true"
      else
        echo "  FAIL BPA is not 4/4 true"
        fail=$((fail+1))
      fi

      ver=$(aws s3api get-bucket-versioning --bucket "$BUCKET" \
            --output text 2>/dev/null || true)
      if echo "$ver" | grep -q 'Enabled'; then
        echo "  OK   versioning Enabled"
      else
        echo "  FAIL versioning not Enabled"
        fail=$((fail+1))
      fi

      if aws s3api get-bucket-lifecycle-configuration \
           --bucket "$BUCKET" >/dev/null 2>&1; then
        echo "  OK   lifecycle configuration present"
      else
        echo "  FAIL lifecycle configuration missing on bucket"
        fail=$((fail+1))
      fi

      if aws s3api get-bucket-policy --bucket "$BUCKET" >/dev/null 2>&1; then
        echo "  OK   bucket policy present"
      else
        echo "  FAIL bucket policy missing"
        fail=$((fail+1))
      fi
    else
      echo "  SKIP bucket '$BUCKET' not found on LocalStack"
    fi
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: estructura valida. Compara con solution/REFERENCE.md para autoevaluarte."
exit 0
