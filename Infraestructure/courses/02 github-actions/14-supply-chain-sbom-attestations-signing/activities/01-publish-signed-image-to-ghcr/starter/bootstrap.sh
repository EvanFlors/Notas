#!/usr/bin/env bash
# Scaffolding para gha-14-01. NO corre docker, NO genera claves — el estudiante lo hace.
set -euo pipefail

BASE="${1:-/tmp/gha-14-01}"
rm -rf "$BASE"
mkdir -p "$BASE/.github/workflows" "$BASE/keys" "$BASE/sbom"

# Dockerfile mínimo (coincide con el que usa el solution)
cat > "$BASE/Dockerfile" <<'EOF'
FROM alpine:3.19
RUN apk add --no-cache ca-certificates
RUN echo "hello from gha-14-01" > /hello.txt
CMD ["cat", "/hello.txt"]
EOF

cat > "$BASE/NOTES.md" <<'EOF'
# gha-14-01 — scaffolding listo

Qué hacer:

1. Levanta registry local:
   docker run -d --rm --name gha-14-01-registry -p 5050:5000 registry:2

2. Build + push:
   docker build -t localhost:5050/app:v0.1.0 .
   docker push localhost:5050/app:v0.1.0

3. Captura el digest:
   DIGEST=$(docker inspect localhost:5050/app:v0.1.0 --format='{{index .RepoDigests 0}}' | awk -F@ '{print $2}')
   echo "$DIGEST"

4. SBOM:
   syft -o cyclonedx-json=sbom/sbom.cdx.json "localhost:5050/app@${DIGEST}"

5. Firma (key pair local):
   export COSIGN_PASSWORD=''
   cosign generate-key-pair --output-key-prefix keys/cosign
   cosign sign --key keys/cosign.key --tlog-upload=false --yes "localhost:5050/app@${DIGEST}"

6. Verifica:
   cosign verify --key keys/cosign.pub --insecure-ignore-tlog "localhost:5050/app@${DIGEST}"

7. Escribe .github/workflows/release.yml (ver README.md §5.2.B).

8. Valida:
   bash <ruta-actividad>/tests/validate.sh /tmp/gha-14-01
EOF

echo "Scaffolding en $BASE listo."
echo "Siguiente: lee NOTES.md y sigue README.md §5."
