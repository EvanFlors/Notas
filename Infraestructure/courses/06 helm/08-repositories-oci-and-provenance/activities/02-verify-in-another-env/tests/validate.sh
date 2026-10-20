#!/usr/bin/env bash
# Validate helm-08-02-verify-in-another-env.
# Checks the consumer-side artifacts and runs an automatic negative test with
# an unrelated cosign key — must FAIL.
#
# Note: deliberately NO `set -o pipefail` — pipes to grep -q may yield SIGPIPE.
set -eu

MODE="${MODE:-local}"
BASE="${BASE:-/tmp/helm-08-act02}"
CHART_REF="${CHART_REF:-oci://localhost:5000/charts/mi-app}"
CHART_VERSION="${CHART_VERSION:-0.1.0}"
COSIGN_PUB="${COSIGN_PUB:-/tmp/helm-08-act01/keys/cosign.pub}"
passed=0
failed=0

fail() { echo "  FAIL $*"; failed=$((failed+1)); }
ok()   { echo "  OK   $*"; passed=$((passed+1)); }

echo "== Validating helm-08-02 (MODE=$MODE) at $BASE =="
echo "   CHART_REF=$CHART_REF  VERSION=$CHART_VERSION"

if ! command -v helm >/dev/null 2>&1; then
  echo "SKIP: helm not installed."; exit 0
fi
if ! command -v cosign >/dev/null 2>&1; then
  echo "SKIP: cosign not installed."; exit 0
fi

if [ ! -d "$BASE" ]; then
  echo "FAIL: workdir $BASE does not exist."
  exit 1
fi

# 1. Pulled .tgz present
TGZ=$(ls "$BASE/pulled/"*.tgz 2>/dev/null | head -1 || true)
if [ -z "$TGZ" ]; then
  fail "no .tgz in $BASE/pulled/ (did you run helm pull?)"
else
  ok "pulled chart present: $(basename "$TGZ")"
fi

# 2. Render file present and non-empty
if [ -s "$BASE/rendered.yaml" ]; then
  ok "rendered.yaml present and non-empty"
  if grep -q 'kind:' "$BASE/rendered.yaml"; then
    ok "rendered.yaml contains at least one K8s resource"
  else
    fail "rendered.yaml has no 'kind:' lines"
  fi
else
  fail "rendered.yaml missing or empty (did you run helm template?)"
fi

# 3. REPORT.md present with non-trivial content
if [ -f "$BASE/REPORT.md" ]; then
  LINES=$(wc -l < "$BASE/REPORT.md" | tr -d ' ')
  if [ "$LINES" -ge 10 ]; then
    ok "REPORT.md present ($LINES lines, >=10)"
  else
    fail "REPORT.md too short ($LINES lines, expected >=10)"
  fi
else
  fail "REPORT.md missing"
fi

# 4. Cosign verify — positive
if [ "$MODE" = "local" ]; then
  # Derive registry+chart from CHART_REF (strip oci://)
  REF="${CHART_REF#oci://}"
  REG_HOST="${REF%%/*}"
  CHART_PATH="${REF#*/}"   # e.g. charts/mi-app
  DIGEST=$(curl -sfI -H "Accept: application/vnd.oci.image.manifest.v1+json" \
    "http://${REG_HOST}/v2/${CHART_PATH}/manifests/${CHART_VERSION}" 2>/dev/null \
    | awk 'tolower($1)=="docker-content-digest:" {print $2}' | tr -d '\r')
  if [ -z "$DIGEST" ]; then
    fail "cannot resolve digest (is the publisher's registry still up?)"
  else
    IMG="${REG_HOST}/${CHART_PATH}@${DIGEST}"
    if [ ! -f "$COSIGN_PUB" ]; then
      fail "COSIGN_PUB not found at $COSIGN_PUB"
    elif cosign verify --key "$COSIGN_PUB" --insecure-ignore-tlog \
                       --allow-insecure-registry "$IMG" >/dev/null 2>&1; then
      ok "cosign verify (correct key) OK"
    else
      fail "cosign verify (correct key) FAILED"
    fi

    # Negative test: fresh key MUST fail
    TMP=$(mktemp -d /tmp/validate-h08-02.XXXX)
    (cd "$TMP" && COSIGN_PASSWORD='' cosign generate-key-pair >/dev/null 2>&1)
    if cosign verify --key "$TMP/cosign.pub" --insecure-ignore-tlog \
                     --allow-insecure-registry "$IMG" >/dev/null 2>&1; then
      fail "negative test: unrelated key UNEXPECTEDLY verified"
    else
      ok "negative test: unrelated key correctly rejected"
    fi
    rm -rf "$TMP"
  fi
else
  # MODE=live — rely on provided env
  if [ -n "${COSIGN_PUB:-}" ] && [ -f "$COSIGN_PUB" ]; then
    # Need digest — try helm show chart (requires helm >= 3.14)
    DIGEST=$(helm show chart "$CHART_REF" --version "$CHART_VERSION" 2>/dev/null \
             | awk '/^digest:/ {print $2}')
    if [ -z "$DIGEST" ]; then
      fail "cannot resolve digest (helm show chart needs >=3.14)"
    else
      REF="${CHART_REF#oci://}"
      IMG="${REF}@${DIGEST}"
      if cosign verify --key "$COSIGN_PUB" "$IMG" >/dev/null 2>&1; then
        ok "cosign verify (key-based, live) OK"
      else
        fail "cosign verify (key-based, live) FAILED"
      fi
    fi
  elif [ -n "${COSIGN_IDENTITY_REGEX:-}" ] && [ -n "${COSIGN_OIDC_ISSUER:-}" ]; then
    DIGEST=$(helm show chart "$CHART_REF" --version "$CHART_VERSION" 2>/dev/null \
             | awk '/^digest:/ {print $2}')
    REF="${CHART_REF#oci://}"
    IMG="${REF}@${DIGEST}"
    if cosign verify "$IMG" \
        --certificate-identity-regexp "$COSIGN_IDENTITY_REGEX" \
        --certificate-oidc-issuer "$COSIGN_OIDC_ISSUER" >/dev/null 2>&1; then
      ok "cosign verify (keyless, live) OK"
    else
      fail "cosign verify (keyless, live) FAILED"
    fi
  else
    echo "  SKIP: live mode needs COSIGN_PUB or (COSIGN_IDENTITY_REGEX + COSIGN_OIDC_ISSUER)"
  fi
fi

echo
echo "== Summary: $passed passed, $failed failed =="
[ "$failed" -eq 0 ]
