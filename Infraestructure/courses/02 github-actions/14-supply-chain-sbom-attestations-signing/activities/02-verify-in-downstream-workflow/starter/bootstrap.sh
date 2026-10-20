#!/usr/bin/env bash
# Scaffolding para gha-14-02.
set -euo pipefail

BASE="${1:-/tmp/gha-14-02}"
rm -rf "$BASE"
mkdir -p "$BASE/.github/workflows" "$BASE/fixture"

# Inputs esperados — valores ilustrativos. Los tests sobreescriben con el fixture.
cat > "$BASE/image-info.env" <<'EOF'
# Variables esperadas por verify.sh. Léelas con `set -a; source image-info.env; set +a`.
IMAGE_REF=ghcr.io/sigstore/sample-trusted-image:latest
EXPECTED_REPO=sigstore/sample-trusted-image
EXPECTED_WORKFLOW_REGEX=^https://github\.com/sigstore/sample-trusted-image/\.github/workflows/release\.yml@refs/tags/v.*$
EXPECTED_OIDC_ISSUER=https://token.actions.githubusercontent.com
EOF

cat > "$BASE/NOTES.md" <<'EOF'
# gha-14-02 — scaffolding

Tareas:

1. Escribe verify.sh que lea image-info.env y verifique firma + attestation.
2. Escribe .github/workflows/consume.yml con dos jobs: verify, deploy (needs: verify).
3. chmod +x verify.sh
4. Valida: bash tests/validate.sh /tmp/gha-14-02

Pistas:
- cosign verify "$IMAGE_REF" --certificate-identity-regexp "$EXPECTED_WORKFLOW_REGEX" --certificate-oidc-issuer "$EXPECTED_OIDC_ISSUER"
- gh attestation verify oci://"$IMAGE_REF" --repo "$EXPECTED_REPO"
- Workflow: permissions: contents: read. Nada más.
EOF

echo "Scaffolding en $BASE listo."
echo "Lee NOTES.md y README.md §5."
