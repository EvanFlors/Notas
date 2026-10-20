#!/usr/bin/env bash
# Structural + light-semantic validation for
# gcp-06-02-secret-rotation-pattern.
#
# Checks:
#   - main.tf declares the 4 expected resources with required attributes.
#   - All secret_data literals start with 'fake-' (no real secrets leaked).
#   - iam-binding-secret-accessor.json parses, carries the right role and
#     a well-formed consumer service account member.
#   - rotator.py runs locally and prints the ROTATION_OK line; its stdout
#     does not contain patterns typical of real secrets.
#   - README-ROTATION.md has the 4 obligatory sections and mentions
#     Pub/Sub, rotation_period, secretAccessor, latest.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness in a real GCP project — compare
# manually with solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/gcp-06-secret}"
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

# Common forbidden patterns (prefixes of real secrets we must NEVER see).
check_no_real_secrets() {
  local f="$1"
  local bad=0
  if grep -qE 'sk_live_[A-Za-z0-9]{10,}' "$f"; then
    echo "  FAIL $f contains Stripe live key prefix (sk_live_...)"
    bad=1
  fi
  if grep -qE 'sk_test_[A-Za-z0-9]{10,}' "$f"; then
    echo "  FAIL $f contains Stripe test key prefix (sk_test_...)"
    bad=1
  fi
  if grep -qE 'AKIA[0-9A-Z]{16}' "$f"; then
    echo "  FAIL $f contains AWS Access Key ID (AKIA...)"
    bad=1
  fi
  if grep -qE 'ghp_[A-Za-z0-9]{30,}' "$f"; then
    echo "  FAIL $f contains GitHub PAT (ghp_...)"
    bad=1
  fi
  if grep -qE 'xoxb-[0-9A-Za-z-]{10,}' "$f"; then
    echo "  FAIL $f contains Slack bot token (xoxb-...)"
    bad=1
  fi
  if grep -qE 'AIza[0-9A-Za-z_-]{30,}' "$f"; then
    echo "  FAIL $f contains Google API key (AIza...)"
    bad=1
  fi
  if [ "$bad" -eq 0 ]; then
    echo "  OK   $f contains no known real-secret prefixes"
  else
    fail=$((fail+bad))
  fi
}

# --- main.tf -------------------------------------------------------------
TF="$BASE/main.tf"
if check_file_exists "$TF"; then
  check_grep "$TF" 'resource[[:space:]]+"google_pubsub_topic"' 'declares google_pubsub_topic'
  check_grep "$TF" 'resource[[:space:]]+"google_secret_manager_secret"[[:space:]]+"api_key"' 'declares google_secret_manager_secret "api_key"'
  check_grep "$TF" 'resource[[:space:]]+"google_secret_manager_secret_version"' 'declares google_secret_manager_secret_version'
  check_grep "$TF" 'resource[[:space:]]+"google_secret_manager_secret_iam_member"' 'declares google_secret_manager_secret_iam_member'

  check_grep "$TF" 'secret_id[[:space:]]*=[[:space:]]*"external-api-key"' 'secret_id = "external-api-key"'
  check_grep "$TF" 'replication[[:space:]]*\{' 'has replication block'
  check_grep "$TF" 'auto[[:space:]]*\{' 'replication.auto {} present'
  check_grep "$TF" 'rotation_period[[:space:]]*=[[:space:]]*"[0-9]+s"' 'rotation_period in seconds'
  check_grep "$TF" 'next_rotation_time[[:space:]]*=[[:space:]]*"20[0-9]{2}-' 'next_rotation_time in RFC3339'
  check_grep "$TF" 'role[[:space:]]*=[[:space:]]*"roles/secretmanager\.secretAccessor"' 'binding uses secretAccessor'
  check_grep "$TF" 'serviceAccount:[A-Za-z0-9_-]+@[^"]+\.iam\.gserviceaccount\.com' 'binding targets a user-managed SA'
  check_grep "$TF" 'demo-secret-example' 'uses demo project placeholder (no real project id)'

  # Every secret_data literal must start with 'fake-'.
  bad_values=$(grep -nE 'secret_data[[:space:]]*=[[:space:]]*"' "$TF" | grep -vE 'secret_data[[:space:]]*=[[:space:]]*"fake-' || true)
  if [ -z "$bad_values" ]; then
    echo "  OK   $TF: every secret_data literal starts with 'fake-'"
  else
    echo "  FAIL $TF: some secret_data literal does NOT start with 'fake-':"
    echo "$bad_values" | sed 's/^/      /'
    fail=$((fail+1))
  fi

  check_no_real_secrets "$TF"
fi

# --- iam-binding-secret-accessor.json ------------------------------------
BIND="$BASE/iam-binding-secret-accessor.json"
if check_file_exists "$BIND"; then
  if jq empty "$BIND" >/dev/null 2>&1; then
    echo "  OK   $BIND is valid JSON"
  else
    echo "  FAIL $BIND is not valid JSON"
    fail=$((fail+1))
  fi
  check_jq_contains "$BIND" \
    '[.bindings[].role] | any(. == "roles/secretmanager.secretAccessor")' \
    'contains role secretAccessor'
  check_jq_contains "$BIND" \
    '[.bindings[].members[]?] | any(test("^serviceAccount:[A-Za-z0-9_-]+@[A-Za-z0-9_-]+\\.iam\\.gserviceaccount\\.com$"))' \
    'has well-formed consumer service account'
  check_jq_contains "$BIND" '(.version | type) == "number"' 'version is a number'
  check_no_real_secrets "$BIND"
fi

# --- rotator.py ----------------------------------------------------------
ROT="$BASE/rotator.py"
if check_file_exists "$ROT"; then
  out=$(python3 "$ROT" 2>&1) && rc=0 || rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "  FAIL $ROT exited with code $rc"
    echo "$out" | sed 's/^/      /'
    fail=$((fail+1))
  else
    echo "  OK   $ROT ran successfully"
    if printf '%s\n' "$out" | grep -qE '^ROTATION_OK: new=[0-9]+ previous=DISABLED$'; then
      echo "  OK   $ROT printed the ROTATION_OK confirmation"
    else
      echo "  FAIL $ROT did not print the expected ROTATION_OK line"
      echo "$out" | sed 's/^/      /'
      fail=$((fail+1))
    fi
    # The stdout itself must not contain real-secret prefixes.
    tmp_out=$(mktemp)
    printf '%s\n' "$out" > "$tmp_out"
    check_no_real_secrets "$tmp_out"
    rm -f "$tmp_out"
  fi
  check_no_real_secrets "$ROT"
fi

# --- README-ROTATION.md --------------------------------------------------
DOC="$BASE/README-ROTATION.md"
if check_file_exists "$DOC"; then
  for section in "Ventana de solape" "Replicaci[oó]n" "Modelo de acceso" "Rotaci[oó]n en el proveedor externo"; do
    if grep -qiE "^#+ *${section}" "$DOC"; then
      echo "  OK   README-ROTATION.md has section matching '${section}'"
    else
      echo "  FAIL README-ROTATION.md missing section matching '${section}'"
      fail=$((fail+1))
    fi
  done
  for term in "Pub/Sub" "rotation_period" "secretAccessor" "latest"; do
    if grep -q "$term" "$DOC"; then
      echo "  OK   README-ROTATION.md mentions ${term}"
    else
      echo "  FAIL README-ROTATION.md does not mention ${term}"
      fail=$((fail+1))
    fi
  done
  check_no_real_secrets "$DOC"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  echo "        (Semantic correctness against a real GCP project is NOT verified here.)"
  exit 1
fi
echo "OK: plan Terraform, IAM binding, rotator y README-ROTATION.md pasan validacion estructural."
echo "    Compara con solution/REFERENCE.md para autoevaluacion semantica."
exit 0
