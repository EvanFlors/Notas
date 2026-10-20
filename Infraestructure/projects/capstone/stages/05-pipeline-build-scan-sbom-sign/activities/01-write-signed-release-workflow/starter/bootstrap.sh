#!/usr/bin/env bash
# Scaffolding for cap-05-01-write-signed-release-workflow.
set -euo pipefail

BASE="${1:-/tmp/cap-05}"
rm -rf "$BASE"
mkdir -p "$BASE/project/.github/workflows"

cat > "$BASE/project/README.md" <<'EOF'
# Capstone stage 5 — Activity 01 (starter)

Tareas:
1. Crear `trivy.yaml` con gate HIGH/CRITICAL + ignore-unfixed.
2. Crear `.github/workflows/release.yml`:
   - Trigger en tags `v*.*.*`.
   - Permisos del job: id-token, attestations, packages, contents.
   - docker/build-push-action -> trivy -> syft -> cosign sign -> cosign attest spdxjson
     -> actions/attest-build-provenance.
   - Consumir image@${digest} en todos los steps post-build.
   - Actions pinneadas por SHA de 40 hex.
3. Crear `.github/workflows/verify.yml`:
   - `on: workflow_call` con inputs image + digest.
   - cosign verify con --certificate-identity-regexp y --certificate-oidc-issuer.

Validar:
  bash tests/validate.sh /tmp/cap-05
EOF

echo "Scaffolding listo en $BASE/project/"
ls -R "$BASE/project"
