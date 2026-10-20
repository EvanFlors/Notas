#!/usr/bin/env bash
# Structural validation for gl-08-02-sign-and-publish.
# Checks that .gitlab-ci.yml declares build/sign/verify, uses Kaniko and
# cosign, firma el digest con id_tokens aud=sigstore, verifica con
# certificate-identity + oidc-issuer, no referencia COSIGN_KEY, y que
# cleanup-policy.json y README-INTENT.md tienen la forma esperada.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.

set -eu

BASE="${1:-/tmp/gl-08-sign}"
YML="$BASE/.gitlab-ci.yml"
POLICY="$BASE/cleanup-policy.json"
DOC="$BASE/README-INTENT.md"
fail=0

echo "== Structural validation for $BASE =="

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: 'python3' is required but not installed."
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "FAIL: 'jq' is required but not installed."
  exit 2
fi

# --- .gitlab-ci.yml ------------------------------------------------------
if [ ! -f "$YML" ]; then
  echo "FAIL: $YML does not exist."
  fail=$((fail+1))
else
  echo "  OK   $YML exists"
  if python3 -c 'import sys,yaml; yaml.safe_load(open(sys.argv[1]))' "$YML" >/dev/null 2>&1; then
    echo "  OK   $YML is valid YAML"
  else
    echo "  FAIL $YML is not valid YAML"
    fail=$((fail+1))
  fi

  for s in "build" "sign" "verify"; do
    if grep -qE "^${s}:" "$YML"; then
      echo "  OK   has job '${s}'"
    else
      echo "  FAIL missing job '${s}'"
      fail=$((fail+1))
    fi
  done

  # Kaniko in build
  if grep -qE 'kaniko-project/executor' "$YML"; then
    echo "  OK   uses Kaniko for build"
  else
    echo "  FAIL does not use Kaniko (kaniko-project/executor)"
    fail=$((fail+1))
  fi

  # Cosign image in sign/verify
  if grep -qE 'projectsigstore/cosign|sigstore/cosign' "$YML"; then
    echo "  OK   uses cosign image"
  else
    echo "  FAIL does not reference projectsigstore/cosign"
    fail=$((fail+1))
  fi

  # id_tokens with aud: sigstore
  if grep -qE 'id_tokens:' "$YML" && grep -qE 'aud:[[:space:]]*sigstore' "$YML"; then
    echo "  OK   declares id_tokens with aud: sigstore"
  else
    echo "  FAIL missing id_tokens: ... aud: sigstore"
    fail=$((fail+1))
  fi

  # Must sign the digest (contain @ in sign/verify)
  if grep -qE 'cosign sign' "$YML" && grep -qE '@\$DIGEST|@\$\{DIGEST\}' "$YML"; then
    echo "  OK   signs the digest (not just a tag)"
  else
    echo "  FAIL does not sign IMAGE@\$DIGEST (must sign the digest, not the tag)"
    fail=$((fail+1))
  fi

  # Verify with certificate-identity + oidc-issuer
  if grep -qE -- '--certificate-identity' "$YML" && grep -qE -- '--certificate-oidc-issuer' "$YML"; then
    echo "  OK   verify pins --certificate-identity and --certificate-oidc-issuer"
  else
    echo "  FAIL verify does not pin --certificate-identity and --certificate-oidc-issuer"
    fail=$((fail+1))
  fi

  # No long-lived cosign key
  if grep -qiE 'COSIGN_KEY|cosign\.key|--key[[:space:]]' "$YML"; then
    echo "  FAIL references COSIGN_KEY / cosign.key / --key (keyless required)"
    fail=$((fail+1))
  else
    echo "  OK   no long-lived cosign key referenced (keyless)"
  fi

  # Must capture digest from kaniko
  if grep -qE -- '--digest-file' "$YML"; then
    echo "  OK   captures digest with --digest-file"
  else
    echo "  FAIL does not capture digest with --digest-file"
    fail=$((fail+1))
  fi
fi

# --- cleanup-policy.json -------------------------------------------------
if [ ! -f "$POLICY" ]; then
  echo "FAIL: $POLICY does not exist."
  fail=$((fail+1))
else
  echo "  OK   $POLICY exists"
  if jq empty "$POLICY" >/dev/null 2>&1; then
    echo "  OK   $POLICY is valid JSON"
  else
    echo "  FAIL $POLICY is not valid JSON"
    fail=$((fail+1))
  fi
  for key in "enabled" "cadence" "keep_n" "older_than" "name_regex_delete" "name_regex_keep"; do
    val=$(jq -r "has(\"$key\")" "$POLICY" 2>/dev/null || echo "false")
    if [ "$val" = "true" ]; then
      echo "  OK   cleanup-policy.json has key '${key}'"
    else
      echo "  FAIL cleanup-policy.json missing key '${key}'"
      fail=$((fail+1))
    fi
  done
fi

# --- README-INTENT.md ----------------------------------------------------
if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist."
  fail=$((fail+1))
else
  echo "  OK   $DOC exists"
  for section in "Build (Kaniko)" "Firma keyless" "Verificacion" "SBOM" "Cleanup policy"; do
    if grep -qiF "$section" "$DOC"; then
      echo "  OK   README-INTENT.md mentions '${section}'"
    else
      echo "  FAIL README-INTENT.md missing '${section}'"
      fail=$((fail+1))
    fi
  done
  for word in "cosign" "sigstore" "digest" "CycloneDX"; do
    if grep -qiF "$word" "$DOC"; then
      echo "  OK   README-INTENT.md mentions '${word}'"
    else
      echo "  FAIL README-INTENT.md missing word '${word}'"
      fail=$((fail+1))
    fi
  done
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  exit 1
fi
echo "OK: estructura valida. Compara con solution/REFERENCE.md para autoevaluarte."
exit 0
