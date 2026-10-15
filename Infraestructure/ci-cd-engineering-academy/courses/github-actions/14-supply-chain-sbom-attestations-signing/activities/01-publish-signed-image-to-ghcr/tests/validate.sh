#!/usr/bin/env bash
# Validator for gha-14-01-publish-signed-image-to-ghcr.
#
# NOTE: deliberately NOT using `set -o pipefail` because many checks pipe
# long-producing commands (docker inspect, cosign verify, yq) into grep,
# which can emit SIGPIPE (exit 141) and would be flagged spuriously.

BASE="${1:-${BASE_DIR:-/tmp/gha-14-01}}"
REG_PORT=5050
REG_CONTAINER="gha-14-01-registry"
WORKFLOW="$BASE/.github/workflows/release.yml"

pass=0
fail=0
skip=0
report=""

ok()   { report+="  OK   — $1\n"; pass=$((pass+1)); }
bad()  { report+="  FAIL — $1\n"; fail=$((fail+1)); }
skp()  { report+="  SKIP — $1\n"; skip=$((skip+1)); }

echo "== Validating gha-14-01 under $BASE =="

# --- Structure ---
if [ ! -d "$BASE" ]; then
  bad "base dir missing: $BASE. Run starter/bootstrap.sh first."
  echo; printf "%b" "$report"
  echo "RESULT: $pass OK / $fail FAIL / $skip SKIP  →  FAIL"
  exit 1
fi
ok "base dir present"

if [ -f "$BASE/Dockerfile" ]; then
  ok "Dockerfile present"
else
  bad "Dockerfile missing at $BASE/Dockerfile"
fi

# --- Workflow checks (YAML inspection) ---
if [ ! -f "$WORKFLOW" ]; then
  bad "workflow $WORKFLOW missing (crea .github/workflows/release.yml)"
else
  ok "workflow release.yml present"

  # Must be valid YAML (python -c)
  if python3 -c "import yaml,sys; yaml.safe_load(open('$WORKFLOW'))" 2>/dev/null; then
    ok "release.yml is valid YAML"
  else
    bad "release.yml is NOT valid YAML"
  fi

  # Required `uses:` patterns
  for pattern in \
      "actions/attest-build-provenance" \
      "actions/attest-sbom" ; do
    if grep -qF "$pattern" "$WORKFLOW"; then
      ok "workflow uses $pattern"
    else
      bad "workflow does NOT use $pattern"
    fi
  done

  # Must use syft (direct install or anchore/sbom-action)
  if grep -qE "anchore/sbom-action|download-syft|^\s*run:.*syft" "$WORKFLOW"; then
    ok "workflow generates SBOM (syft or sbom-action)"
  else
    bad "workflow does NOT generate SBOM (expected syft or anchore/sbom-action)"
  fi

  # Must use cosign (installer or direct run)
  if grep -qE "sigstore/cosign-installer|cosign sign" "$WORKFLOW"; then
    ok "workflow signs with cosign"
  else
    bad "workflow does NOT invoke cosign"
  fi

  # permissions: must include id-token:write and attestations:write and packages:write
  # Simple inspection with grep + context.
  for perm in "id-token: write" "attestations: write" "packages: write"; do
    if grep -qF "$perm" "$WORKFLOW"; then
      ok "workflow declares permission: $perm"
    else
      bad "workflow missing permission: $perm"
    fi
  done

  # Must NOT grant write-all or contents: write (overly broad)
  if grep -qE "permissions:\s*write-all" "$WORKFLOW"; then
    bad "workflow uses 'permissions: write-all' — too broad. Use least privilege."
  else
    ok "workflow does not use 'permissions: write-all'"
  fi

  # Must have default-deny at top-level permissions
  if grep -qE "^permissions:\s*\{\s*\}\s*$" "$WORKFLOW"; then
    ok "top-level permissions: {} (default-deny)"
  else
    skp "top-level default-deny permissions: {} not detected (recommended but not required)"
  fi
fi

# --- Runtime checks (optional: skip gracefully if tools missing) ---
have_docker=0
have_cosign=0
have_syft=0
command -v docker >/dev/null 2>&1 && have_docker=1
command -v cosign >/dev/null 2>&1 && have_cosign=1
command -v syft   >/dev/null 2>&1 && have_syft=1

echo "  (runtime tools: docker=$have_docker cosign=$have_cosign syft=$have_syft)"

if [ $have_docker -eq 0 ]; then
  skp "docker missing — runtime checks skipped"
else
  # Daemon reachable?
  if ! docker info >/dev/null 2>&1; then
    skp "docker daemon not reachable — runtime checks skipped"
  else
    # Is the local registry up?
    if docker ps --format '{{.Names}}' | grep -q "^${REG_CONTAINER}$"; then
      ok "local registry '${REG_CONTAINER}' running"
    else
      skp "local registry not running (ok — only needed if you ran MODE=local)"
    fi

    # Try to inspect the image
    if docker inspect "localhost:${REG_PORT}/app:v0.1.0" >/dev/null 2>&1; then
      DIGEST="$(docker inspect "localhost:${REG_PORT}/app:v0.1.0" --format='{{index .RepoDigests 0}}' 2>/dev/null | awk -F@ '{print $2}')"
      if [ -n "$DIGEST" ]; then
        ok "image localhost:${REG_PORT}/app:v0.1.0 found (digest: ${DIGEST:0:19}...)"
        IMG="localhost:${REG_PORT}/app@${DIGEST}"

        # SBOM check
        if [ -s "$BASE/sbom/sbom.cdx.json" ]; then
          if jq -e '.components | length > 0' "$BASE/sbom/sbom.cdx.json" >/dev/null 2>&1; then
            ok "SBOM sbom/sbom.cdx.json valid (CycloneDX, has components)"
          else
            bad "SBOM sbom/sbom.cdx.json is not valid CycloneDX (missing components[])"
          fi
        elif [ $have_syft -eq 1 ]; then
          bad "SBOM sbom/sbom.cdx.json missing (syft available — debió generarse)"
        else
          skp "SBOM check skipped (syft not installed)"
        fi

        # Cosign verify
        if [ $have_cosign -eq 1 ]; then
          if [ -f "$BASE/keys/cosign.pub" ]; then
            if (cd "$BASE" && cosign verify --key keys/cosign.pub --insecure-ignore-tlog "$IMG" >/dev/null 2>&1); then
              ok "cosign verify passes for $IMG"
            else
              bad "cosign verify FAILS for $IMG (did you sign?)"
            fi
          else
            bad "cosign public key missing at $BASE/keys/cosign.pub"
          fi
        else
          skp "cosign verify skipped (cosign not installed)"
        fi
      else
        bad "could not extract digest for image"
      fi
    else
      skp "image localhost:${REG_PORT}/app:v0.1.0 not pushed — MODE=local runtime not exercised"
    fi
  fi
fi

echo
printf "%b" "$report"
echo
if [ "$fail" -eq 0 ]; then
  echo "RESULT: ALL CHECKS PASS ($pass OK / $skip SKIP)"
  exit 0
else
  echo "RESULT: $pass OK / $fail FAIL / $skip SKIP  →  FAIL"
  exit 1
fi
