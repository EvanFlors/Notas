#!/usr/bin/env bash
# Reference solution — verify firma Sigstore + attestation GitHub de una imagen OCI.
# Fail closed: cualquier verificación falla → exit != 0.
set -euo pipefail

INFO="${1:-image-info.env}"
if [ ! -f "$INFO" ]; then
  echo "FAIL: $INFO no existe." >&2
  exit 2
fi

# shellcheck disable=SC1090
set -a; . "$INFO"; set +a

for v in IMAGE_REF EXPECTED_REPO EXPECTED_WORKFLOW_REGEX EXPECTED_OIDC_ISSUER; do
  if [ -z "${!v:-}" ]; then
    echo "FAIL: variable $v no definida en $INFO" >&2
    exit 2
  fi
done

if ! command -v cosign >/dev/null 2>&1; then
  echo "FAIL: cosign no instalado. Fail closed." >&2
  exit 2
fi
if ! command -v gh >/dev/null 2>&1; then
  echo "FAIL: gh CLI no instalado. Fail closed." >&2
  exit 2
fi

echo "==> cosign verify"
cosign verify "$IMAGE_REF" \
  --certificate-identity-regexp "$EXPECTED_WORKFLOW_REGEX" \
  --certificate-oidc-issuer "$EXPECTED_OIDC_ISSUER" \
  --output=json >/tmp/cosign-verify.json

echo "==> gh attestation verify"
gh attestation verify "oci://${IMAGE_REF}" --repo "$EXPECTED_REPO"

echo "OK: firma y attestation verificadas."
