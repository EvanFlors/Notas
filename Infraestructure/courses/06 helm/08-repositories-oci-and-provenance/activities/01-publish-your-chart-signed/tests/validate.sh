#!/usr/bin/env bash
# Validate helm-08-01-publish-your-chart-signed.
# Supports both MODE=local (default) and MODE=live. In live mode the student
# must export MODE=live, REGISTRY, CHART, VERSION, COSIGN_PUB (file path), and
# COSIGN_IDENTITY_REGEX + COSIGN_OIDC_ISSUER (for keyless).
#
# Note: deliberately NO `set -o pipefail` — downstream pipes to grep -q may
# yield SIGPIPE (exit 141) and would be mis-reported as failures.
set -eu

MODE="${MODE:-local}"
BASE="${BASE:-/tmp/helm-08-act01}"
passed=0
failed=0

fail() { echo "  FAIL $*"; failed=$((failed+1)); }
ok()   { echo "  OK   $*"; passed=$((passed+1)); }

echo "== Validating helm-08-01 (MODE=$MODE) at $BASE =="

if ! command -v helm >/dev/null 2>&1; then
  echo "SKIP: helm not installed."
  exit 0
fi
if ! command -v cosign >/dev/null 2>&1; then
  echo "SKIP: cosign not installed."
  exit 0
fi

if [ ! -d "$BASE" ]; then
  echo "FAIL: workdir $BASE does not exist. Did you follow §5.1?"
  exit 1
fi

# Find a chart .tgz the student produced
TGZ=$(ls "$BASE"/*.tgz 2>/dev/null | head -1 || true)
if [ -z "$TGZ" ]; then
  fail "no .tgz found in $BASE (did you run helm package?)"
else
  ok "found packaged chart: $(basename "$TGZ")"
  # Extract chart version from filename (expects <name>-<ver>.tgz)
  CHART_VER=$(basename "$TGZ" .tgz | sed -E 's/.*-([0-9]+\.[0-9]+\.[0-9]+[^-]*)$/\1/')
  if [ -n "$CHART_VER" ] && echo "$CHART_VER" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+'; then
    ok "chart version looks SemVer-like: $CHART_VER"
  else
    fail "chart version '$CHART_VER' is not SemVer"
  fi
fi

if [ "$MODE" = "local" ]; then
  if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
    echo "SKIP: docker not available."
    exit 0
  fi

  REG_CONTAINER="helm-08-act01-reg"
  REG_HOST="localhost:5000"

  # Registry alive?
  if docker ps --format '{{.Names}}' | grep -q "^${REG_CONTAINER}$"; then
    ok "local registry running: $REG_CONTAINER"
  else
    fail "local registry $REG_CONTAINER not running (docker ps)"
  fi

  # Discover chart name from the .tgz
  CHART_NAME=$(basename "$TGZ" .tgz | sed -E 's/-[0-9]+\.[0-9]+\.[0-9]+.*$//')
  if [ -z "$CHART_NAME" ]; then
    fail "could not infer chart name from $TGZ"
  else
    ok "chart name: $CHART_NAME"

    TAGS=$(curl -sf "http://${REG_HOST}/v2/charts/${CHART_NAME}/tags/list" 2>/dev/null || echo '')
    if echo "$TAGS" | grep -q "\"${CHART_VER}\""; then
      ok "tag ${CHART_VER} present in registry"
    else
      fail "tag ${CHART_VER} NOT present in registry (did helm push succeed?)"
    fi

    # Signature tag exists?
    if echo "$TAGS" | grep -q 'sha256-.*\.sig'; then
      ok "signature artifact present (sha256-*.sig tag)"
    else
      fail "no cosign signature artifact (expected tag sha256-*.sig)"
    fi

    # Verify with provided public key
    PUB="$BASE/keys/cosign.pub"
    if [ ! -f "$PUB" ]; then
      fail "public key not found at $PUB"
    else
      DIGEST=$(curl -sfI -H "Accept: application/vnd.oci.image.manifest.v1+json" \
        "http://${REG_HOST}/v2/charts/${CHART_NAME}/manifests/${CHART_VER}" \
        | awk 'tolower($1)=="docker-content-digest:" {print $2}' | tr -d '\r')
      IMG="${REG_HOST}/charts/${CHART_NAME}@${DIGEST}"
      if [ -z "$DIGEST" ]; then
        fail "could not resolve digest"
      elif cosign verify --key "$PUB" --insecure-ignore-tlog \
                         --allow-insecure-registry "$IMG" >/dev/null 2>&1; then
        ok "cosign verify with correct public key: OK"
      else
        fail "cosign verify with correct public key FAILED"
      fi

      # Negative test: with a fresh unrelated key, verify must fail
      TMPKEY_DIR=$(mktemp -d /tmp/validate-helm08-wrongkey.XXXX)
      (cd "$TMPKEY_DIR" && COSIGN_PASSWORD='' cosign generate-key-pair >/dev/null 2>&1)
      if cosign verify --key "$TMPKEY_DIR/cosign.pub" --insecure-ignore-tlog \
                       --allow-insecure-registry "$IMG" >/dev/null 2>&1; then
        fail "negative test: wrong key UNEXPECTEDLY verified"
      else
        ok "negative test: wrong key correctly rejected"
      fi
      rm -rf "$TMPKEY_DIR"
    fi
  fi

elif [ "$MODE" = "live" ]; then
  REGISTRY="${REGISTRY:-}"
  CHART="${CHART:-}"
  VERSION="${VERSION:-}"
  if [ -z "$REGISTRY" ] || [ -z "$CHART" ] || [ -z "$VERSION" ]; then
    echo "FAIL: live mode requires REGISTRY, CHART, VERSION."
    exit 2
  fi

  echo "-- helm show chart ..."
  if helm show chart "oci://${REGISTRY}/${CHART}" --version "$VERSION" >/dev/null 2>&1; then
    ok "chart reachable at oci://${REGISTRY}/${CHART}:${VERSION}"
  else
    fail "chart not reachable (check login + visibility)"
  fi

  DIGEST=$(helm show chart "oci://${REGISTRY}/${CHART}" --version "$VERSION" 2>/dev/null \
           | awk '/^digest:/ {print $2}')
  if [ -z "$DIGEST" ]; then
    fail "could not resolve digest (helm >= 3.14 shows it)"
  else
    IMG="${REGISTRY}/${CHART}@${DIGEST}"
    if [ -n "${COSIGN_PUB:-}" ] && [ -f "$COSIGN_PUB" ]; then
      if cosign verify --key "$COSIGN_PUB" "$IMG" >/dev/null 2>&1; then
        ok "cosign verify (key-based) OK"
      else
        fail "cosign verify (key-based) FAILED"
      fi
    elif [ -n "${COSIGN_IDENTITY_REGEX:-}" ] && [ -n "${COSIGN_OIDC_ISSUER:-}" ]; then
      if cosign verify "$IMG" \
          --certificate-identity-regexp "$COSIGN_IDENTITY_REGEX" \
          --certificate-oidc-issuer "$COSIGN_OIDC_ISSUER" >/dev/null 2>&1; then
        ok "cosign verify (keyless) OK"
      else
        fail "cosign verify (keyless) FAILED"
      fi
    else
      echo "  SKIP: provide either COSIGN_PUB or (COSIGN_IDENTITY_REGEX + COSIGN_OIDC_ISSUER)"
    fi
  fi
else
  echo "FAIL: unknown MODE='$MODE'."
  exit 2
fi

echo
echo "== Summary: $passed passed, $failed failed =="
[ "$failed" -eq 0 ]
