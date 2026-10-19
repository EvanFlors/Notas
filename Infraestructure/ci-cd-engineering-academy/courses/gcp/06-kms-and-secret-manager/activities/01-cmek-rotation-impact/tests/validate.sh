#!/usr/bin/env bash
# Structural + light-semantic validation for
# gcp-06-01-cmek-rotation-impact.
#
# Checks:
#   - main.tf parses as HCL-ish text and declares the 4 expected resources
#     with the required attributes.
#   - iam-binding-gcs-service-agent.json parses, carries the right role and
#     a well-formed GCS service agent member.
#   - envelope-demo.py runs locally and prints the ROTATION_IMPACT line.
#   - README-IMPACT.md has the 4 obligatory sections and mentions KEK, DEK,
#     envelope and CMEK.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness in a real GCP project — compare
# manually with solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/gcp-06-cmek}"
fail=0

echo "== Structural validation for $BASE =="

if ! command -v jq >/dev/null 2>&1; then
  echo "FAIL: 'jq' is required but not installed."
  exit 2
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: 'python3' is required but not installed."
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

check_grep() {
  local f="$1"
  local pattern="$2"
  local label="$3"
  if grep -qE "$pattern" "$f"; then
    echo "  OK   $f: ${label}"
  else
    echo "  FAIL $f: ${label} (pattern: $pattern)"
    fail=$((fail+1))
  fi
}

check_jq_contains() {
  local f="$1"
  local expr="$2"
  local label="$3"
  local val
  val=$(jq -r "$expr" "$f" 2>/dev/null || echo "")
  if [ "$val" = "true" ]; then
    echo "  OK   $f: ${label}"
  else
    echo "  FAIL $f: ${label} (expr: $expr)"
    fail=$((fail+1))
  fi
}

# --- main.tf -------------------------------------------------------------
TF="$BASE/main.tf"
if check_file_exists "$TF"; then
  check_grep "$TF" 'resource[[:space:]]+"google_kms_key_ring"' 'declares google_kms_key_ring'
  check_grep "$TF" 'resource[[:space:]]+"google_kms_crypto_key"' 'declares google_kms_crypto_key'
  check_grep "$TF" 'resource[[:space:]]+"google_kms_crypto_key_iam_member"' 'declares google_kms_crypto_key_iam_member'
  check_grep "$TF" 'resource[[:space:]]+"google_storage_bucket"' 'declares google_storage_bucket'

  check_grep "$TF" 'purpose[[:space:]]*=[[:space:]]*"ENCRYPT_DECRYPT"' 'CryptoKey purpose = ENCRYPT_DECRYPT'
  check_grep "$TF" 'rotation_period[[:space:]]*=[[:space:]]*"[0-9]+s"' 'CryptoKey has rotation_period in seconds'
  check_grep "$TF" 'algorithm[[:space:]]*=[[:space:]]*"GOOGLE_SYMMETRIC_ENCRYPTION"' 'version_template uses GOOGLE_SYMMETRIC_ENCRYPTION'
  check_grep "$TF" 'protection_level[[:space:]]*=[[:space:]]*"(SOFTWARE|HSM|EXTERNAL)"' 'version_template declares protection_level'
  check_grep "$TF" 'role[[:space:]]*=[[:space:]]*"roles/cloudkms\.cryptoKeyEncrypterDecrypter"' 'binding uses cryptoKeyEncrypterDecrypter'
  check_grep "$TF" 'serviceAccount:service-[^@"]+@gs-project-accounts\.iam\.gserviceaccount\.com' 'binding targets GCS service agent'
  check_grep "$TF" 'uniform_bucket_level_access[[:space:]]*=[[:space:]]*true' 'bucket has uniform_bucket_level_access=true'
  check_grep "$TF" 'default_kms_key_name[[:space:]]*=' 'bucket.encryption.default_kms_key_name present'
  check_grep "$TF" '"europe-[a-z0-9-]+"' 'uses an europe-* region literal'

  # No real project ids leaked (basic heuristic: must still contain the demo placeholder).
  check_grep "$TF" 'demo-cmek-example' 'uses demo project placeholder (no real project id)'
fi

# --- iam-binding-gcs-service-agent.json ----------------------------------
BIND="$BASE/iam-binding-gcs-service-agent.json"
if check_file_exists "$BIND"; then
  if jq empty "$BIND" >/dev/null 2>&1; then
    echo "  OK   $BIND is valid JSON"
  else
    echo "  FAIL $BIND is not valid JSON"
    fail=$((fail+1))
  fi
  check_jq_contains "$BIND" \
    '[.bindings[].role] | any(. == "roles/cloudkms.cryptoKeyEncrypterDecrypter")' \
    'contains role cryptoKeyEncrypterDecrypter'
  check_jq_contains "$BIND" \
    '[.bindings[].members[]?] | any(test("^serviceAccount:service-[0-9]+@gs-project-accounts\\.iam\\.gserviceaccount\\.com$"))' \
    'has well-formed GCS service agent member'
  check_jq_contains "$BIND" '(.version | type) == "number"' 'version is a number'
fi

# --- envelope-demo.py ----------------------------------------------------
DEMO="$BASE/envelope-demo.py"
if check_file_exists "$DEMO"; then
  if ! python3 -c "import cryptography" >/dev/null 2>&1; then
    echo "  FAIL cannot import 'cryptography' — install with: pip install cryptography"
    fail=$((fail+1))
  else
    out=$(python3 "$DEMO" 2>&1) && rc=0 || rc=$?
    if [ "$rc" -ne 0 ]; then
      echo "  FAIL $DEMO exited with code $rc"
      echo "$out" | sed 's/^/      /'
      fail=$((fail+1))
    else
      echo "  OK   $DEMO ran successfully"
      if printf '%s\n' "$out" | grep -q '^ROTATION_IMPACT: ciphertext unchanged, both KEK versions decrypt$'; then
        echo "  OK   $DEMO printed the ROTATION_IMPACT confirmation"
      else
        echo "  FAIL $DEMO did not print the expected ROTATION_IMPACT line"
        fail=$((fail+1))
      fi
      if printf '%s\n' "$out" | grep -q '^WRAPPED_DEK_V1=' && \
         printf '%s\n' "$out" | grep -q '^WRAPPED_DEK_V2='; then
        echo "  OK   $DEMO printed WRAPPED_DEK_V1 and WRAPPED_DEK_V2"
      else
        echo "  FAIL $DEMO missing WRAPPED_DEK_V1 or WRAPPED_DEK_V2 in stdout"
        fail=$((fail+1))
      fi
    fi
  fi
fi

# --- README-IMPACT.md ----------------------------------------------------
DOC="$BASE/README-IMPACT.md"
if check_file_exists "$DOC"; then
  for section in "Decisiones de dise[ñn]o" "Impacto de la rotaci[oó]n" "Service agent" "Costos"; do
    if grep -qiE "^#+ *${section}" "$DOC"; then
      echo "  OK   README-IMPACT.md has section matching '${section}'"
    else
      echo "  FAIL README-IMPACT.md missing section matching '${section}'"
      fail=$((fail+1))
    fi
  done
  for term in "KEK" "DEK" "envelope" "CMEK"; do
    if grep -qi "$term" "$DOC"; then
      echo "  OK   README-IMPACT.md mentions ${term}"
    else
      echo "  FAIL README-IMPACT.md does not mention ${term}"
      fail=$((fail+1))
    fi
  done
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  echo "        (Semantic correctness against a real GCP project is NOT verified here.)"
  exit 1
fi
echo "OK: plan Terraform, IAM binding, demo Python y README-IMPACT.md pasan validacion estructural."
echo "    Compara con solution/REFERENCE.md para autoevaluacion semantica."
exit 0
