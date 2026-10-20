#!/usr/bin/env bash
# Structural validation for aws-09-01-store-and-fetch-secret-from-app.
# Checks the artifacts produced in the scratch dir:
#   - key-policy.json  (4 required Sids, valid JSON)
#   - cmk.json / secret.json / param.json  (status OK or SKIP, well-formed)
#   - envelope.json    (required fields, valid b64)
#   - app.log          (startup markers, no leaked secret)
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness beyond basic structural shape —
# compare manually with solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/aws-09-store-fetch}"
fail=0

echo "== Structural validation for $BASE =="

check_file() {
  local path="$1"
  if [ -f "$path" ]; then
    echo "  OK   file exists: $path"
    return 0
  fi
  echo "  FAIL missing file: $path"
  fail=$((fail+1))
  return 1
}

if [ ! -d "$BASE" ]; then
  echo "FAIL: scratch dir $BASE does not exist."
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "FAIL: 'jq' is required to run this validator."
  exit 2
fi

# ---- key-policy.json ----
KP="$BASE/key-policy.json"
if check_file "$KP"; then
  if jq empty "$KP" >/dev/null 2>&1; then
    echo "  OK   key-policy.json is valid JSON"
  else
    echo "  FAIL key-policy.json is not valid JSON"
    fail=$((fail+1))
  fi
  for sid in EnableIAMDelegation AllowKeyAdministration \
             AllowCheckoutAppDecrypt AllowSecretsManagerUse; do
    if jq -e --arg s "$sid" '[.Statement[].Sid] | index($s)' "$KP" >/dev/null 2>&1; then
      echo "  OK   key-policy.json contains Sid: $sid"
    else
      echo "  FAIL key-policy.json missing Sid: $sid"
      fail=$((fail+1))
    fi
  done
  if jq -e '.Statement[] | select(.Principal.Service=="secretsmanager.amazonaws.com") | .Condition.StringEquals["kms:ViaService"]' "$KP" >/dev/null 2>&1; then
    echo "  OK   secretsmanager statement has kms:ViaService condition"
  else
    echo "  FAIL secretsmanager statement missing kms:ViaService condition"
    fail=$((fail+1))
  fi
fi

# ---- cmk.json / secret.json / param.json ----
for f in cmk.json secret.json param.json; do
  P="$BASE/$f"
  if check_file "$P"; then
    if jq empty "$P" >/dev/null 2>&1; then
      status=$(jq -r '.status // "MISSING"' "$P")
      if [ "$status" = "OK" ] || [ "$status" = "SKIP" ]; then
        echo "  OK   $f has status=$status"
      else
        echo "  FAIL $f status=$status (expected OK or SKIP)"
        fail=$((fail+1))
      fi
    else
      echo "  FAIL $f is not valid JSON"
      fail=$((fail+1))
    fi
  fi
done

# ---- envelope.json ----
ENV="$BASE/envelope.json"
if check_file "$ENV"; then
  if jq empty "$ENV" >/dev/null 2>&1; then
    echo "  OK   envelope.json is valid JSON"
  else
    echo "  FAIL envelope.json is not valid JSON"
    fail=$((fail+1))
  fi
  for key in mode cmk_id wrapped_key_b64 nonce_b64 ciphertext_b64 tag_b64 payload_sha256; do
    if jq -e --arg k "$key" 'has($k)' "$ENV" >/dev/null 2>&1; then
      echo "  OK   envelope.json has field: $key"
    else
      echo "  FAIL envelope.json missing field: $key"
      fail=$((fail+1))
    fi
  done
  mode=$(jq -r '.mode' "$ENV")
  case "$mode" in
    online|offline)
      echo "  OK   envelope.json mode=$mode"
      ;;
    *)
      echo "  FAIL envelope.json mode must be 'online' or 'offline' (got '$mode')"
      fail=$((fail+1))
      ;;
  esac
  sha=$(jq -r '.payload_sha256' "$ENV")
  if printf '%s' "$sha" | grep -Eq '^[0-9a-f]{64}$'; then
    echo "  OK   envelope.json payload_sha256 looks like hex-sha256"
  else
    echo "  FAIL envelope.json payload_sha256 is not a sha256 hex"
    fail=$((fail+1))
  fi
fi

# ---- app.log ----
APPLOG="$BASE/app.log"
if check_file "$APPLOG"; then
  if grep -q 'boot start' "$APPLOG"; then
    echo "  OK   app.log contains 'boot start'"
  else
    echo "  FAIL app.log missing 'boot start'"
    fail=$((fail+1))
  fi
  if grep -q 'resolved secret OK' "$APPLOG"; then
    echo "  OK   app.log contains 'resolved secret OK'"
  else
    echo "  FAIL app.log missing 'resolved secret OK'"
    fail=$((fail+1))
  fi
  if grep -q 'resolved param OK' "$APPLOG"; then
    echo "  OK   app.log contains 'resolved param OK'"
  else
    echo "  FAIL app.log missing 'resolved param OK'"
    fail=$((fail+1))
  fi
  # No-leak: the fake password marker should NEVER appear in logs.
  if grep -qE 'fake-pw-NOT-REAL|password=' "$APPLOG"; then
    echo "  FAIL app.log appears to leak the secret value"
    fail=$((fail+1))
  else
    echo "  OK   app.log does not leak the fake secret value"
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara con solution/REFERENCE.md para autoevaluarte."
exit 0
