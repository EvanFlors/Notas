#!/usr/bin/env bash
# sec-08 example 03 — show (and optionally run) verification commands.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `cmd | grep -q ...` which can SIGPIPE (141) when grep exits early.
set -eu

echo "== sec-08 example 03: verify SLSA + SBOM attestations =="

HAS_COSIGN=0
HAS_GH=0

if command -v cosign >/dev/null 2>&1; then
  echo "[OK] cosign found ($(cosign version 2>/dev/null | head -n1 || echo 'version?'))"
  HAS_COSIGN=1
else
  echo "[SKIP] cosign not found. Install: https://docs.sigstore.dev/system_config/installation/"
fi

if command -v gh >/dev/null 2>&1; then
  echo "[OK] gh found ($(gh --version | head -n1))"
  HAS_GH=1
else
  echo "[SKIP] gh not found. Install: https://cli.github.com/"
fi

if [ "${HAS_COSIGN}" -eq 0 ] && [ "${HAS_GH}" -eq 0 ]; then
  echo "[SKIP] neither cosign nor gh available; exiting 0."
  exit 0
fi

cat <<'EOF'

--- Verification commands (replace placeholders with your target) ---

# High-level (gh CLI):
gh attestation verify \
  oci://ghcr.io/<org>/<repo>@sha256:<digest> \
  --repo <org>/<repo>

# Granular (cosign) — provenance SLSA v1.0:
cosign verify-attestation \
  --type slsaprovenance1 \
  --certificate-identity-regexp '^https://github\.com/<org>/<repo>/\.github/workflows/release\.yml@refs/heads/main$' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
  ghcr.io/<org>/<repo>@sha256:<digest>

# Granular (cosign) — SBOM CycloneDX:
cosign verify-attestation \
  --type cyclonedx \
  --certificate-identity-regexp '^https://github\.com/<org>/<repo>/\.github/workflows/release\.yml@refs/heads/main$' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
  ghcr.io/<org>/<repo>@sha256:<digest>

--- !!! ANTI-PATTERN — DO NOT USE !!! ---
# Missing --certificate-identity + --certificate-oidc-issuer:
#   cosign verify-attestation --type slsaprovenance1 <image>
# This accepts attestations signed by ANYONE — including an attacker.
EOF

TARGET_IMAGE="${TARGET_IMAGE:-}"
TARGET_REPO="${TARGET_REPO:-}"

if [ -n "${TARGET_IMAGE}" ] && [ -n "${TARGET_REPO}" ] && [ "${HAS_GH}" -eq 1 ]; then
  echo
  echo "[INFO] TARGET_IMAGE + TARGET_REPO set — running real verification"
  echo "       gh attestation verify oci://${TARGET_IMAGE} --repo ${TARGET_REPO}"
  gh attestation verify "oci://${TARGET_IMAGE}" --repo "${TARGET_REPO}" || \
    echo "[WARN] verification failed — check that the image actually has attestations."
else
  echo
  echo "[INFO] set TARGET_IMAGE=ghcr.io/... and TARGET_REPO=owner/repo"
  echo "       to run a real verification. Skipped for now."
fi

echo "[OK] example finished successfully."
