#!/usr/bin/env bash
# Scaffolding for dkr-14-01. Creates /tmp/dkr-14-01 with:
# - app.py + Dockerfile
# - empty keys/, sbom/
# - provenance.json template
# - STUB pipeline.sh and verify.sh (student completes)
# - STUB .github/workflows/release.yml for MODE=live
#
# This does NOT run docker, trivy or cosign — that's for the student.
set -euo pipefail

BASE="${1:-/tmp/dkr-14-01}"

echo "== bootstrap dkr-14-01 at $BASE =="
rm -rf "$BASE"
mkdir -p "$BASE/.github/workflows" "$BASE/keys" "$BASE/sbom"

# -------- App source --------
cat > "$BASE/app.py" <<'EOF'
# Minimal "hello" app — no framework to keep the image small.
import http.server, socketserver, os

PORT = int(os.environ.get("PORT", "8000"))

class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(b"hello from dkr-14-01\n")

with socketserver.TCPServer(("", PORT), Handler) as srv:
    srv.serve_forever()
EOF

# -------- Dockerfile --------
cat > "$BASE/Dockerfile" <<'EOF'
# Small, non-root Python image for the supply-chain demo.
FROM python:3.12-slim

RUN groupadd -g 10001 app && useradd -u 10001 -g 10001 -s /sbin/nologin -M app
WORKDIR /app
COPY app.py /app/app.py
USER 10001:10001
EXPOSE 8000
CMD ["python", "app.py"]
EOF

# -------- Provenance template --------
cat > "$BASE/provenance.json" <<'EOF'
{
  "buildDefinition": {
    "buildType": "https://example.com/dkr-14-01/local-demo/v1",
    "externalParameters": {
      "source": "git+file:///tmp/dkr-14-01",
      "entryPoint": "pipeline.sh"
    },
    "internalParameters": {
      "runner": "local-dev"
    },
    "resolvedDependencies": []
  },
  "runDetails": {
    "builder": {
      "id": "https://example.com/dkr-14-01/local-demo"
    },
    "metadata": {
      "invocationID": "REPLACE_WITH_UUID",
      "startedOn":    "REPLACE_WITH_TIMESTAMP",
      "finishedOn":   "REPLACE_WITH_TIMESTAMP"
    }
  }
}
EOF

# -------- pipeline.sh STUB --------
cat > "$BASE/pipeline.sh" <<'EOF'
#!/usr/bin/env bash
# dkr-14-01 — STUB. Fill in each TODO block.
# Note: do NOT add `set -o pipefail` if you pipe to grep -q (SIGPIPE 141).
set -eu

BASE="$(cd "$(dirname "$0")" && pwd)"
REG_CONTAINER="dkr-14-01-registry"
REG_PORT=5000
IMAGE_TAG="localhost:${REG_PORT}/app:v1"

# ------- 1. Local registry -------
# TODO: start registry:2 on localhost:$REG_PORT if not running
# docker run -d --rm --name "$REG_CONTAINER" -p "${REG_PORT}:5000" registry:2

# ------- 2. Build + push -------
# TODO: docker build -t "$IMAGE_TAG" "$BASE"
# TODO: docker push "$IMAGE_TAG"

# ------- 3. Resolve digest -------
# TODO: DIGEST=$(docker inspect "$IMAGE_TAG" --format='{{index .RepoDigests 0}}' | awk -F@ '{print $2}')
# TODO: IMG="localhost:${REG_PORT}/app@${DIGEST}"
# TODO: echo "IMG=$IMG"

# ------- 4. SBOM -------
# TODO: syft -o cyclonedx-json="$BASE/sbom/sbom.cdx.json" "$IMG"

# ------- 5. Scan + GATE (critical) -------
# TODO: trivy image --severity CRITICAL --exit-code 1 --ignore-unfixed "$IMG"
#       If this exits non-zero, the pipeline MUST abort before signing.

# ------- 6. Key pair -------
# TODO: export COSIGN_PASSWORD=''
#       if [ ! -f "$BASE/keys/cosign.key" ]; then
#         (cd "$BASE/keys" && cosign generate-key-pair)
#       fi

# ------- 7. Sign -------
# TODO: cosign sign --key "$BASE/keys/cosign.key" --tlog-upload=false --yes "$IMG"

# ------- 8. Fill provenance timestamps -------
# TODO: NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"; UUID="local-$(date +%s)-$$"
#       Use python3 to rewrite "$BASE/provenance.json" with those values.

# ------- 9. Attest SLSA provenance -------
# TODO: cosign attest --key "$BASE/keys/cosign.key" --tlog-upload=false --yes \
#         --predicate "$BASE/provenance.json" --type slsaprovenance "$IMG"

# ------- 10. Attest SBOM -------
# TODO: cosign attest --key "$BASE/keys/cosign.key" --tlog-upload=false --yes \
#         --predicate "$BASE/sbom/sbom.cdx.json" --type cyclonedx "$IMG"

echo "pipeline.sh is a STUB — implement the TODO blocks."
exit 1
EOF
chmod +x "$BASE/pipeline.sh"

# -------- verify.sh STUB --------
cat > "$BASE/verify.sh" <<'EOF'
#!/usr/bin/env bash
# dkr-14-01 verify.sh — consumer side. STUB.
# Usage: verify.sh IMG COSIGN_PUB_PATH
set -eu

IMG="${1:-}"
PUB="${2:-cosign.pub}"

if [ -z "$IMG" ]; then
  echo "usage: $0 <IMG@sha256:...> <cosign.pub>"
  exit 2
fi

# TODO: 1. HEAD manifest to confirm image exists
# TODO: 2. cosign verify         --key "$PUB" --insecure-ignore-tlog "$IMG"
# TODO: 3. cosign verify-attestation --key "$PUB" --insecure-ignore-tlog --type slsaprovenance "$IMG"
# TODO: 4. cosign verify-attestation --key "$PUB" --insecure-ignore-tlog --type cyclonedx    "$IMG"
# TODO: print OK/FAIL per step. Exit 0 only if ALL pass.

echo "verify.sh is a STUB — implement."
exit 1
EOF
chmod +x "$BASE/verify.sh"

# -------- release.yml STUB (MODE=live) --------
cat > "$BASE/.github/workflows/release.yml" <<'EOF'
# dkr-14-01 MODE=live STUB. Replace with your implementation.
# Required: permissions default-deny, cosign sign keyless, attest-build-provenance,
# attest-sbom, syft/anchore-sbom-action, docker login + build-push.
name: release

on:
  push:
    tags: ["v*"]

permissions: {}

jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      # TODO: packages: write
      # TODO: id-token: write
      # TODO: attestations: write
    steps:
      - uses: actions/checkout@v4
      # TODO: docker/login-action to ghcr.io
      # TODO: docker/build-push-action (push: true), capture digest
      # TODO: anchore/sbom-action or syft
      # TODO: sigstore/cosign-installer + cosign sign --yes
      # TODO: actions/attest-build-provenance (push-to-registry: true)
      # TODO: actions/attest-sbom (sbom-path, push-to-registry: true)
EOF

# -------- NOTES --------
cat > "$BASE/NOTES.md" <<'EOF'
# dkr-14-01 — scaffolding ready

Goal: implement pipeline.sh + verify.sh (and optionally release.yml for MODE=live)
so that an outsider with only your IMG and cosign.pub can verify everything.

Required chain:
  build → push → syft(SBOM) → trivy(gate CRITICAL) → cosign sign →
  cosign attest(slsaprovenance) → cosign attest(cyclonedx) → verify

Install if missing:
  brew install syft trivy cosign jq
  (or see install.sh scripts in the respective GitHub repos)

Run:
  bash pipeline.sh
  bash verify.sh "localhost:5000/app@sha256:..." keys/cosign.pub
  bash <this-activity>/tests/validate.sh /tmp/dkr-14-01

Cleanup:
  docker stop dkr-14-01-registry 2>/dev/null || true
  rm -rf /tmp/dkr-14-01
EOF

echo "Scaffolding ready at $BASE"
echo "Next: cd $BASE && cat NOTES.md"
