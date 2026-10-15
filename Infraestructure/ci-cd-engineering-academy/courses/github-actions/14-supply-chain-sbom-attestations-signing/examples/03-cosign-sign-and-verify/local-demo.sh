#!/usr/bin/env bash
# Demo 100% local: registry:2 + build + cosign sign (key pair) + verify.
# Requisitos: docker, cosign. Si cosign no está instalado, el script explica cómo.
#
# Uso:  bash local-demo.sh [BASE_DIR]
# Default BASE_DIR = /tmp/cosign-demo
set -euo pipefail

BASE="${1:-/tmp/cosign-demo}"
REG_CONTAINER="cosign-demo-registry"
REG_PORT=5050
IMAGE="localhost:${REG_PORT}/app:demo"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker no está instalado. Abortando."
  exit 2
fi
if ! command -v cosign >/dev/null 2>&1; then
  cat <<EOF
cosign no está instalado. Instrucciones:
  macOS:   brew install cosign
  Linux:   curl -sSfL https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64 \\
             -o /usr/local/bin/cosign && chmod +x /usr/local/bin/cosign
Y vuelve a correr este script.
EOF
  exit 2
fi

mkdir -p "$BASE"
cd "$BASE"

# 1) Levanta un registry local (si no está ya corriendo)
if ! docker ps --format '{{.Names}}' | grep -q "^${REG_CONTAINER}$"; then
  docker run -d --rm --name "$REG_CONTAINER" -p "${REG_PORT}:5000" registry:2 >/dev/null
  sleep 2
fi

# 2) Dockerfile mínimo
cat > Dockerfile <<'EOF'
FROM alpine:3.19
RUN echo "hello cosign" > /hello
CMD ["cat", "/hello"]
EOF

# 3) Build + push al registry local
docker build -t "$IMAGE" .
docker push "$IMAGE"

# 4) Obtiene digest exacto (firmamos por digest, no por tag)
DIGEST="$(docker inspect --format='{{index .RepoDigests 0}}' "$IMAGE" | awk -F@ '{print $2}')"
IMG_BY_DIGEST="localhost:${REG_PORT}/app@${DIGEST}"
echo "Image digest: $DIGEST"

# 5) Genera key pair (si no existe)
export COSIGN_PASSWORD=''
if [ ! -f cosign.key ]; then
  cosign generate-key-pair
fi

# 6) Firma SIN subir a Rekor público (es demo local y no tenemos red garantizada)
cosign sign --key cosign.key --tlog-upload=false --yes "$IMG_BY_DIGEST"

# 7) Verifica
cosign verify --key cosign.pub --insecure-ignore-tlog "$IMG_BY_DIGEST" \
  --output=json | jq -r '.[0].critical.image.docker_manifest_digest'

echo
echo "DEMO OK."
echo "  Registry: localhost:${REG_PORT}  (contenedor: ${REG_CONTAINER})"
echo "  Imagen:   $IMG_BY_DIGEST"
echo "  Claves:   $BASE/cosign.{key,pub}"
echo
echo "Para limpiar:"
echo "  docker rm -f ${REG_CONTAINER}"
echo "  rm -rf $BASE"
