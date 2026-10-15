#!/usr/bin/env bash
# dkr-14 example 04 — cosign attest for SLSA Provenance + SBOM.
# MODE=local by default: local registry + local key pair + no Rekor.
#
# Note: no `set -o pipefail` on purpose.
set -eu

MODE="${MODE:-local}"
BASE="${1:-/tmp/dkr-14-ex04}"
HERE="$(cd "$(dirname "$0")" && pwd)"
REG_CONTAINER="dkr-14-ex04-reg"
REG_PORT=5000
IMAGE_TAG="localhost:${REG_PORT}/attest-demo:v1"

echo "== dkr-14 example 04 — attest provenance + sbom (MODE=$MODE) =="
echo "   workdir: $BASE"

mkdir -p "$BASE" "$BASE/keys" "$BASE/sbom"
cp "$HERE/Dockerfile.sample" "$BASE/Dockerfile"
cp "$HERE/provenance.sample.json" "$BASE/provenance.json"

if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker not available."
  exit 0
fi
if ! command -v cosign >/dev/null 2>&1; then
  echo "SKIP: cosign not installed."
  exit 0
fi

if [ "$MODE" != "local" ]; then
  echo "This example runs MODE=local only (see workflow.yml for MODE=live GHA snippet)."
  exit 0
fi

# Registry
if ! docker ps --format '{{.Names}}' | grep -q "^${REG_CONTAINER}$"; then
  docker run -d --rm --name "$REG_CONTAINER" -p "${REG_PORT}:5000" registry:2 >/dev/null
  sleep 2
fi

echo "-- Build + push $IMAGE_TAG ..."
docker build -q -t "$IMAGE_TAG" "$BASE" >/dev/null
docker push -q "$IMAGE_TAG" >/dev/null

DIGEST=$(docker inspect "$IMAGE_TAG" --format='{{index .RepoDigests 0}}' | awk -F@ '{print $2}')
IMG="localhost:${REG_PORT}/attest-demo@${DIGEST}"
echo "   IMG: $IMG"

# SBOM
if command -v syft >/dev/null 2>&1; then
  echo "-- Generate SBOM (CycloneDX) ..."
  syft -q -o cyclonedx-json="$BASE/sbom/sbom.cdx.json" "$IMG"
else
  echo "SKIP: syft not installed — generating empty SBOM placeholder."
  echo '{"bomFormat":"CycloneDX","specVersion":"1.5","components":[]}' > "$BASE/sbom/sbom.cdx.json"
fi

# Fill provenance timestamps
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
UUID="local-$(date +%s)-$$"
# portable in-place: use python to rewrite JSON
python3 - "$BASE/provenance.json" "$UUID" "$NOW" <<'PY'
import json, sys
path, uuid, ts = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(path))
d["runDetails"]["metadata"]["invocationID"] = uuid
d["runDetails"]["metadata"]["startedOn"]    = ts
d["runDetails"]["metadata"]["finishedOn"]   = ts
json.dump(d, open(path, "w"), indent=2)
PY

# Keys
export COSIGN_PASSWORD=''
if [ ! -f "$BASE/keys/cosign.key" ]; then
  (cd "$BASE/keys" && cosign generate-key-pair >/dev/null 2>&1)
fi

echo "-- Sign (base signature) ..."
cosign sign --key "$BASE/keys/cosign.key" --tlog-upload=false --yes "$IMG" >/dev/null 2>&1

echo "-- Attest SLSA Provenance ..."
cosign attest --key "$BASE/keys/cosign.key" --tlog-upload=false --yes \
  --predicate "$BASE/provenance.json" --type slsaprovenance "$IMG" >/dev/null 2>&1

echo "-- Attest SBOM (CycloneDX) ..."
cosign attest --key "$BASE/keys/cosign.key" --tlog-upload=false --yes \
  --predicate "$BASE/sbom/sbom.cdx.json" --type cyclonedx "$IMG" >/dev/null 2>&1

echo "-- Verify base signature ..."
cosign verify --key "$BASE/keys/cosign.pub" --insecure-ignore-tlog "$IMG" >/dev/null 2>&1 && echo "   OK — signature"

echo "-- Verify SLSA Provenance attestation ..."
cosign verify-attestation --key "$BASE/keys/cosign.pub" --insecure-ignore-tlog \
  --type slsaprovenance "$IMG" >/dev/null 2>&1 && echo "   OK — slsaprovenance"

echo "-- Verify SBOM attestation ..."
cosign verify-attestation --key "$BASE/keys/cosign.pub" --insecure-ignore-tlog \
  --type cyclonedx "$IMG" >/dev/null 2>&1 && echo "   OK — cyclonedx"

echo "-- Negative test: verify-attestation for a type not attested (vuln) ..."
if cosign verify-attestation --key "$BASE/keys/cosign.pub" --insecure-ignore-tlog \
      --type vuln "$IMG" >/dev/null 2>&1; then
  echo "   UNEXPECTED PASS — should have failed."
  exit 1
else
  echo "   OK — correctly rejected (no vuln attestation attached)"
fi

echo
echo "DONE (MODE=local)."
echo "  Image:        $IMG"
echo "  SBOM:         $BASE/sbom/sbom.cdx.json"
echo "  Provenance:   $BASE/provenance.json"
echo "  Cleanup:      docker stop $REG_CONTAINER ; rm -rf $BASE"
