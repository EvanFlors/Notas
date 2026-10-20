#!/usr/bin/env bash
# Validator for dkr-14-01-build-sign-and-verify-pipeline.
#
# NOTE: deliberately NOT using `set -o pipefail` because many checks pipe
# long-producing commands (docker inspect, cosign verify, grep) which can
# emit SIGPIPE (141) and would be flagged spuriously.

BASE="${1:-${BASE_DIR:-/tmp/dkr-14-01}}"
REG_CONTAINER="dkr-14-01-registry"
REG_PORT=5000
WORKFLOW="$BASE/.github/workflows/release.yml"

pass=0
fail=0
skip=0
report=""

ok()   { report+="  OK   — $1\n"; pass=$((pass+1)); }
bad()  { report+="  FAIL — $1\n"; fail=$((fail+1)); }
skp()  { report+="  SKIP — $1\n"; skip=$((skip+1)); }

echo "== Validating dkr-14-01 under $BASE =="

# --- Structure ---
if [ ! -d "$BASE" ]; then
  bad "base dir missing: $BASE. Run starter/bootstrap.sh first."
  echo; printf "%b" "$report"
  echo "RESULT: $pass OK / $fail FAIL / $skip SKIP  →  FAIL"
  exit 1
fi
ok "base dir present"

for f in Dockerfile app.py provenance.json pipeline.sh verify.sh; do
  if [ -f "$BASE/$f" ]; then ok "$f present"; else bad "$f missing at $BASE/$f"; fi
done

# --- Workflow ---
if [ ! -f "$WORKFLOW" ]; then
  skp "release.yml not present (optional for MODE=live)"
else
  ok "release.yml present"
  if python3 -c "import yaml,sys; yaml.safe_load(open('$WORKFLOW'))" 2>/dev/null; then
    ok "release.yml is valid YAML"
  else
    bad "release.yml is NOT valid YAML"
  fi

  for perm in "id-token: write" "attestations: write" "packages: write"; do
    if grep -qF "$perm" "$WORKFLOW"; then
      ok "workflow declares permission: $perm"
    else
      bad "workflow missing permission: $perm"
    fi
  done

  if grep -qE "permissions:\s*write-all" "$WORKFLOW"; then
    bad "workflow uses 'permissions: write-all' — too broad"
  else
    ok "workflow does not use 'permissions: write-all'"
  fi

  for pattern in "actions/attest-build-provenance" "actions/attest-sbom"; do
    if grep -qF "$pattern" "$WORKFLOW"; then
      ok "workflow uses $pattern"
    else
      bad "workflow missing $pattern"
    fi
  done

  if grep -qE "anchore/sbom-action|download-syft|run:.*syft" "$WORKFLOW"; then
    ok "workflow generates SBOM (syft / sbom-action)"
  else
    bad "workflow does NOT generate SBOM"
  fi

  if grep -qE "sigstore/cosign-installer|cosign sign" "$WORKFLOW"; then
    ok "workflow signs with cosign"
  else
    bad "workflow does NOT invoke cosign"
  fi
fi

# --- pipeline.sh content checks ---
if [ -f "$BASE/pipeline.sh" ]; then
  for needle in "trivy image" "cosign sign" "cosign attest" "syft"; do
    if grep -qF "$needle" "$BASE/pipeline.sh"; then
      ok "pipeline.sh references '$needle'"
    else
      skp "pipeline.sh does not reference '$needle' (may still be STUB)"
    fi
  done
  # Ensure no set -o pipefail with grep -q (bad habit flagged by course)
  if grep -qE "^[[:space:]]*set [^#]*pipefail" "$BASE/pipeline.sh" && grep -qE "^[[:space:]]*[^#].*grep -q" "$BASE/pipeline.sh"; then
    bad "pipeline.sh uses 'set -o pipefail' alongside 'grep -q' (risk of spurious SIGPIPE failures)"
  else
    ok "pipeline.sh avoids pipefail+grep -q pitfall"
  fi
fi

# --- verify.sh content checks ---
if [ -f "$BASE/verify.sh" ]; then
  for needle in "cosign verify" "verify-attestation"; do
    if grep -qF "$needle" "$BASE/verify.sh"; then
      ok "verify.sh references '$needle'"
    else
      skp "verify.sh does not reference '$needle' (may still be STUB)"
    fi
  done
fi

# --- Runtime checks (graceful skip if tools absent) ---
have_docker=0; have_cosign=0; have_syft=0; have_trivy=0
command -v docker >/dev/null 2>&1 && have_docker=1
command -v cosign >/dev/null 2>&1 && have_cosign=1
command -v syft   >/dev/null 2>&1 && have_syft=1
command -v trivy  >/dev/null 2>&1 && have_trivy=1

echo "  (runtime tools: docker=$have_docker cosign=$have_cosign syft=$have_syft trivy=$have_trivy)"

if [ $have_docker -eq 0 ] || ! docker info >/dev/null 2>&1; then
  skp "docker not available — runtime checks skipped"
else
  if docker ps --format '{{.Names}}' | grep -q "^${REG_CONTAINER}$"; then
    ok "local registry '${REG_CONTAINER}' running"
  else
    skp "local registry not running (ok if pipeline.sh not run yet)"
  fi

  if docker inspect "localhost:${REG_PORT}/app:v1" >/dev/null 2>&1; then
    DIGEST=$(docker inspect "localhost:${REG_PORT}/app:v1" --format='{{index .RepoDigests 0}}' 2>/dev/null | awk -F@ '{print $2}')
    if [ -n "$DIGEST" ]; then
      IMG="localhost:${REG_PORT}/app@${DIGEST}"
      ok "image found (digest: ${DIGEST:0:19}...)"

      if [ -s "$BASE/sbom/sbom.cdx.json" ]; then
        if jq -e '.components' "$BASE/sbom/sbom.cdx.json" >/dev/null 2>&1; then
          ok "SBOM sbom/sbom.cdx.json valid CycloneDX"
        else
          bad "SBOM sbom/sbom.cdx.json malformed"
        fi
      elif [ $have_syft -eq 1 ]; then
        bad "SBOM missing (syft available — should have been generated)"
      else
        skp "SBOM check skipped (syft not installed)"
      fi

      if [ $have_cosign -eq 1 ] && [ -f "$BASE/keys/cosign.pub" ]; then
        if cosign verify --key "$BASE/keys/cosign.pub" --insecure-ignore-tlog "$IMG" >/dev/null 2>&1; then
          ok "cosign verify OK for $IMG"
        else
          bad "cosign verify FAILS (did you run pipeline.sh?)"
        fi
        if cosign verify-attestation --key "$BASE/keys/cosign.pub" --insecure-ignore-tlog --type slsaprovenance "$IMG" >/dev/null 2>&1; then
          ok "cosign verify-attestation slsaprovenance OK"
        else
          bad "cosign verify-attestation slsaprovenance FAILS"
        fi
        if cosign verify-attestation --key "$BASE/keys/cosign.pub" --insecure-ignore-tlog --type cyclonedx "$IMG" >/dev/null 2>&1; then
          ok "cosign verify-attestation cyclonedx OK"
        else
          bad "cosign verify-attestation cyclonedx FAILS"
        fi
      else
        skp "cosign verify skipped (cosign or keys missing)"
      fi
    fi
  else
    skp "image localhost:${REG_PORT}/app:v1 not pushed — runtime not exercised"
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
