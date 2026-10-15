#!/usr/bin/env bash
# dkr-14-01 — reference solution for pipeline.sh (MODE=local).
# Note: no `set -o pipefail` on purpose (grep -q downstream can SIGPIPE).
set -eu

BASE="$(cd "$(dirname "$0")/.." && pwd)"
# Allow running directly from solution/ by passing BASE:
BASE="${BASE_OVERRIDE:-$BASE}"
if [ ! -f "$BASE/Dockerfile" ]; then
  BASE="/tmp/dkr-14-01"
fi

REG_CONTAINER="dkr-14-01-registry"
REG_PORT=5000
IMAGE_TAG="localhost:${REG_PORT}/app:v1"

echo "== pipeline.sh (solution) BASE=$BASE =="

if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "FAIL: docker unavailable."
  exit 1
fi

# 1) Registry
if ! docker ps --format '{{.Names}}' | grep -q "^${REG_CONTAINER}$"; then
  docker run -d --rm --name "$REG_CONTAINER" -p "${REG_PORT}:5000" registry:2 >/dev/null
  sleep 2
fi

# 2) Build + push
docker build -q -t "$IMAGE_TAG" "$BASE" >/dev/null
docker push -q "$IMAGE_TAG" >/dev/null

# 3) Digest
DIGEST=$(docker inspect "$IMAGE_TAG" --format='{{index .RepoDigests 0}}' | awk -F@ '{print $2}')
IMG="localhost:${REG_PORT}/app@${DIGEST}"
echo "IMG=$IMG"

# 4) SBOM
if command -v syft >/dev/null 2>&1; then
  syft -q -o cyclonedx-json="$BASE/sbom/sbom.cdx.json" "$IMG"
  echo "SBOM: $BASE/sbom/sbom.cdx.json"
else
  echo "SKIP: syft not installed"
  echo '{"bomFormat":"CycloneDX","specVersion":"1.5","components":[]}' > "$BASE/sbom/sbom.cdx.json"
fi

# 5) Trivy GATE
if command -v trivy >/dev/null 2>&1; then
  echo "-- trivy gate (CRITICAL) --"
  if ! trivy image --quiet --no-progress --severity CRITICAL --exit-code 1 --ignore-unfixed "$IMG"; then
    echo "GATE: CRITICAL vulns found. Aborting BEFORE signing."
    exit 3
  fi
  echo "GATE: OK"
else
  echo "SKIP: trivy not installed — gate not enforced in this run"
fi

# 6) Keys
export COSIGN_PASSWORD=''
if command -v cosign >/dev/null 2>&1; then
  if [ ! -f "$BASE/keys/cosign.key" ]; then
    (cd "$BASE/keys" && cosign generate-key-pair >/dev/null 2>&1)
  fi

  # 7) Sign
  cosign sign --key "$BASE/keys/cosign.key" --tlog-upload=false --yes "$IMG" >/dev/null 2>&1
  echo "cosign sign: OK"

  # 8) Fill provenance timestamps
  NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  UUID="local-$(date +%s)-$$"
  python3 - "$BASE/provenance.json" "$UUID" "$NOW" <<'PY'
import json, sys
p, uid, ts = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(p))
d["runDetails"]["metadata"]["invocationID"] = uid
d["runDetails"]["metadata"]["startedOn"]    = ts
d["runDetails"]["metadata"]["finishedOn"]   = ts
json.dump(d, open(p, "w"), indent=2)
PY

  # 9) Attest SLSA Provenance
  cosign attest --key "$BASE/keys/cosign.key" --tlog-upload=false --yes \
    --predicate "$BASE/provenance.json" --type slsaprovenance "$IMG" >/dev/null 2>&1
  echo "attest slsaprovenance: OK"

  # 10) Attest SBOM
  cosign attest --key "$BASE/keys/cosign.key" --tlog-upload=false --yes \
    --predicate "$BASE/sbom/sbom.cdx.json" --type cyclonedx "$IMG" >/dev/null 2>&1
  echo "attest cyclonedx: OK"
else
  echo "SKIP: cosign not installed — sign/attest not performed"
fi

echo
echo "DONE."
echo "  IMG=$IMG"
echo "  Verify with: bash $(dirname "$0")/verify.sh \"$IMG\" \"$BASE/keys/cosign.pub\""
