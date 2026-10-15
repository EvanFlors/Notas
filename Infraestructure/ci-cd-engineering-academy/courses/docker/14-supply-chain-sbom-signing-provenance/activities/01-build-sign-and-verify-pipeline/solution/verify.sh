#!/usr/bin/env bash
# dkr-14-01 — reference solution for verify.sh (consumer side).
# Note: no `set -o pipefail`.
set -eu

IMG="${1:-}"
PUB="${2:-cosign.pub}"

if [ -z "$IMG" ]; then
  echo "usage: $0 <IMG@sha256:...> <cosign.pub>"
  exit 2
fi
if [ ! -f "$PUB" ]; then
  echo "FAIL: public key not found at $PUB"
  exit 2
fi
if ! command -v cosign >/dev/null 2>&1; then
  echo "FAIL: cosign not installed."
  exit 2
fi

pass=0
fail=0

check() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "  OK   — $label"
    pass=$((pass+1))
  else
    echo "  FAIL — $label"
    fail=$((fail+1))
  fi
}

echo "== verify.sh =="
echo "   IMG: $IMG"
echo "   PUB: $PUB"
echo

# 1. Manifest reachable (crane fallback: use cosign tree, else curl)
# We rely on cosign to touch the registry; registry absence will surface in step 2 anyway.

# 2. Base signature
check "cosign verify (base signature)" \
  cosign verify --key "$PUB" --insecure-ignore-tlog "$IMG"

# 3. SLSA Provenance attestation
check "cosign verify-attestation --type slsaprovenance" \
  cosign verify-attestation --key "$PUB" --insecure-ignore-tlog --type slsaprovenance "$IMG"

# 4. SBOM (CycloneDX) attestation
check "cosign verify-attestation --type cyclonedx" \
  cosign verify-attestation --key "$PUB" --insecure-ignore-tlog --type cyclonedx "$IMG"

echo
if [ "$fail" -eq 0 ]; then
  echo "RESULT: ALL CHECKS PASS ($pass OK)"
  exit 0
else
  echo "RESULT: $pass OK / $fail FAIL  →  FAIL"
  exit 1
fi
