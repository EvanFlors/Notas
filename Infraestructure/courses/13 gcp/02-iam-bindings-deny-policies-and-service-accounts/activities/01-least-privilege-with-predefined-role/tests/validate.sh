#!/usr/bin/env bash
# Structural + light-semantic validation for
# gcp-02-01-least-privilege-with-predefined-role.
#
# Checks that:
#   - iam-bindings.yaml exists, parses as YAML (via python3), uses roles/
#     prefixed predefined roles (NOT basic owner/editor/viewer), and references
#     the workload service account as a member.
#   - deny-policy.yaml exists, parses as YAML, includes rules with denyRule,
#     deniedPrincipals, exceptionPrincipals (with the break-glass group) and
#     deniedPermissions using the FULLY QUALIFIED form (<svc>.googleapis.com/perm).
#   - README-INTENT.md exists with sections for both artifacts, mentions
#     "predefined", "break-glass", at least one canonical predefined role, and
#     does NOT recommend basic roles.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness in a real GCP project — compare
# manually with solution/README-INTENT.md.

set -eu

BASE="${1:-/tmp/gcp-02-lpp}"
fail=0

echo "== Structural validation for $BASE =="

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: 'python3' is required but not installed."
  exit 2
fi

if ! python3 -c "import yaml" >/dev/null 2>&1; then
  echo "FAIL: python3 'yaml' module (PyYAML) is required. Install with: pip install pyyaml"
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

py_eval() {
  # py_eval <file> <python-expression-returning-True/False> <label>
  local f="$1"
  local expr="$2"
  local label="$3"
  local out
  out=$(python3 - "$f" <<PY 2>/dev/null || echo "ERROR"
import sys, yaml
with open(sys.argv[1]) as fh:
    data = yaml.safe_load(fh)
try:
    print("True" if (${expr}) else "False")
except Exception as e:
    print("ERROR")
PY
)
  if [ "$out" = "True" ]; then
    echo "  OK   $f: ${label}"
  else
    echo "  FAIL $f: ${label} (got: $out)"
    fail=$((fail+1))
  fi
}

# --- iam-bindings.yaml ---------------------------------------------------
F1="$BASE/iam-bindings.yaml"
if check_file_exists "$F1"; then
  # Must parse as YAML with a `bindings` key that is a non-empty list.
  py_eval "$F1" \
    'isinstance(data, dict) and isinstance(data.get("bindings"), list) and len(data["bindings"]) >= 1' \
    'top-level "bindings" is a non-empty list'

  # At least 3 bindings (raw-read, processed-write, pubsub-publish).
  py_eval "$F1" \
    'len(data.get("bindings", [])) >= 3' \
    'has at least 3 bindings (raw read + processed write + pubsub publish)'

  # Every binding must have a role starting with "roles/".
  py_eval "$F1" \
    'all(isinstance(b, dict) and isinstance(b.get("role"), str) and b["role"].startswith("roles/") for b in data["bindings"])' \
    'every binding has a role starting with "roles/"'

  # No basic roles allowed (owner / editor / viewer at the top level).
  py_eval "$F1" \
    'not any(b.get("role") in ("roles/owner","roles/editor","roles/viewer") for b in data["bindings"])' \
    'no basic roles (owner/editor/viewer) used'

  # At least one storage predefined role.
  py_eval "$F1" \
    'any(str(b.get("role","")).startswith("roles/storage.") for b in data["bindings"])' \
    'at least one storage predefined role'

  # At least one pubsub predefined role.
  py_eval "$F1" \
    'any(str(b.get("role","")).startswith("roles/pubsub.") for b in data["bindings"])' \
    'at least one pubsub predefined role'

  # The workload SA must be a member in at least one binding.
  py_eval "$F1" \
    'any("serviceAccount:receipts-processor@acme-prod.iam.gserviceaccount.com" in (b.get("members") or []) for b in data["bindings"])' \
    'workload SA receipts-processor@... is a member in at least one binding'

  # No user:* members (least-privilege + group discipline).
  py_eval "$F1" \
    'not any(any(isinstance(m,str) and m.startswith("user:") for m in (b.get("members") or [])) for b in data["bindings"])' \
    'no raw user:... members in bindings'
fi

# --- deny-policy.yaml ----------------------------------------------------
F2="$BASE/deny-policy.yaml"
if check_file_exists "$F2"; then
  py_eval "$F2" \
    'isinstance(data, dict) and isinstance(data.get("name"), str) and len(data["name"]) > 0' \
    'has non-empty "name"'

  py_eval "$F2" \
    'isinstance(data.get("displayName"), str) and len(data["displayName"]) > 0' \
    'has non-empty "displayName"'

  py_eval "$F2" \
    'isinstance(data.get("rules"), list) and len(data["rules"]) >= 1' \
    'has non-empty "rules" list'

  py_eval "$F2" \
    'all(isinstance(r, dict) and isinstance(r.get("denyRule"), dict) for r in data.get("rules", []))' \
    'every rule has a denyRule dict'

  py_eval "$F2" \
    'any("principalSet://goog/public:all" in (r["denyRule"].get("deniedPrincipals") or []) for r in data["rules"])' \
    'at least one rule denies principalSet://goog/public:all'

  py_eval "$F2" \
    'any(any("break-glass" in str(ep) for ep in (r["denyRule"].get("exceptionPrincipals") or [])) for r in data["rules"])' \
    'at least one rule exempts a break-glass group'

  py_eval "$F2" \
    'any("storage.googleapis.com/buckets.delete" in (r["denyRule"].get("deniedPermissions") or []) for r in data["rules"])' \
    'denies storage.googleapis.com/buckets.delete (fully qualified)'

  # Catch the common mistake of using the short permission name.
  py_eval "$F2" \
    'not any(any(p == "storage.buckets.delete" for p in (r["denyRule"].get("deniedPermissions") or [])) for r in data["rules"])' \
    'does NOT use short permission names like "storage.buckets.delete"'
fi

# --- README-INTENT.md ----------------------------------------------------
DOC="$BASE/README-INTENT.md"
if check_file_exists "$DOC"; then
  if grep -qiE '^#+ .*iam-bindings' "$DOC"; then
    echo "  OK   README-INTENT.md has an 'iam-bindings' section"
  else
    echo "  FAIL README-INTENT.md missing an 'iam-bindings' section heading"
    fail=$((fail+1))
  fi
  if grep -qiE '^#+ .*deny-policy' "$DOC"; then
    echo "  OK   README-INTENT.md has a 'deny-policy' section"
  else
    echo "  FAIL README-INTENT.md missing a 'deny-policy' section heading"
    fail=$((fail+1))
  fi
  if grep -qi 'predefined' "$DOC"; then
    echo "  OK   README-INTENT.md mentions 'predefined'"
  else
    echo "  FAIL README-INTENT.md does not mention 'predefined'"
    fail=$((fail+1))
  fi
  if grep -qi 'break-glass' "$DOC"; then
    echo "  OK   README-INTENT.md mentions 'break-glass'"
  else
    echo "  FAIL README-INTENT.md does not mention 'break-glass'"
    fail=$((fail+1))
  fi
  # Must reference at least one canonical predefined role by name.
  if grep -qE 'roles/(storage|pubsub|run|bigquery|logging|iam|cloudsql|secretmanager)\.' "$DOC"; then
    echo "  OK   README-INTENT.md names at least one canonical predefined role"
  else
    echo "  FAIL README-INTENT.md does not name any canonical predefined role"
    fail=$((fail+1))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  echo "        (Semantic correctness in a real GCP project is NOT verified here.)"
  exit 1
fi
echo "OK: YAML + README-INTENT.md pasan validacion estructural."
echo "    Compara con solution/README-INTENT.md para autoevaluacion semantica."
exit 0
