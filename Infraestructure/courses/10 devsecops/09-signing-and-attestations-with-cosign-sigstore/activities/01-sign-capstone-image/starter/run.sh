#!/usr/bin/env bash
# run.sh — levanta registry:2 local, construye imagen trivial, la firma con
# cosign key-based y la verifica (positivo + negativo).
#
# Deja los artefactos en el directorio actual (típicamente /tmp/sec-09-01-sign).
#
# No usa `set -o pipefail` porque algunos checks con `grep -q` pueden salir con
# SIGPIPE (141) sin ser error real.
set -eu

WORKDIR="$(pwd)"
REGISTRY_CONTAINER="sec09-registry"
REGISTRY_PORT="5000"
IMAGE_REF="localhost:${REGISTRY_PORT}/sec09/payments:v1"

echo "== sec-09-01: firma key-based en registry local =="
echo "   workdir   : $WORKDIR"
echo "   image     : $IMAGE_REF"

# ----- 0. Preflight -----
if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker no está instalado."
  exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker daemon no está corriendo."
  exit 0
fi
if ! command -v cosign >/dev/null 2>&1; then
  echo "SKIP: cosign no está instalado."
  exit 0
fi

# ----- 1. registry:2 -----
if ! docker ps --format '{{.Names}}' | grep -qx "$REGISTRY_CONTAINER"; then
  if docker ps -a --format '{{.Names}}' | grep -qx "$REGISTRY_CONTAINER"; then
    docker rm -f "$REGISTRY_CONTAINER" >/dev/null
  fi
  echo "-- levantando registry:2 en localhost:${REGISTRY_PORT}"
  docker run -d --rm -p "${REGISTRY_PORT}:5000" --name "$REGISTRY_CONTAINER" registry:2 >/dev/null
  sleep 2
else
  echo "-- registry:2 ya corriendo"
fi

# ----- 2. build & push -----
BUILD_DIR="$WORKDIR/build"
mkdir -p "$BUILD_DIR"
cat > "$BUILD_DIR/Dockerfile" <<'EOF'
FROM alpine:3.20
RUN echo "capstone v1" > /app.txt
CMD ["cat", "/app.txt"]
EOF

echo "-- build imagen"
docker build -q -t "$IMAGE_REF" "$BUILD_DIR" >/dev/null

echo "-- push a registry local"
docker push "$IMAGE_REF" >/dev/null

# Capturamos el digest desde el registry (no desde el tag local).
IMAGE_DIGEST="$(docker inspect --format='{{index .RepoDigests 0}}' "$IMAGE_REF" | awk -F@ '{print $2}')"
if [ -z "${IMAGE_DIGEST:-}" ]; then
  # Fallback: query al registry por el manifest.
  IMAGE_DIGEST="$(docker buildx imagetools inspect "$IMAGE_REF" 2>/dev/null | awk '/^Digest/{print $2; exit}')"
fi
if [ -z "${IMAGE_DIGEST:-}" ]; then
  echo "FAIL: no se pudo obtener el digest de $IMAGE_REF"
  exit 1
fi
IMAGE_BY_DIGEST="localhost:${REGISTRY_PORT}/sec09/payments@${IMAGE_DIGEST}"
echo "$IMAGE_DIGEST" > "$WORKDIR/IMAGE_DIGEST"
echo "   digest    : $IMAGE_DIGEST"

# ----- 3. generar claves -----
export COSIGN_PASSWORD=""

for pair in "cosign" "wrong"; do
  if [ ! -f "$WORKDIR/${pair}.key" ]; then
    echo "-- generando par ${pair}.{key,pub}"
    (cd "$WORKDIR" && mv cosign.key "${pair}.key.tmp" 2>/dev/null || true)
    (cd "$WORKDIR" && cosign generate-key-pair >/dev/null)
    mv "$WORKDIR/cosign.key" "$WORKDIR/${pair}.key"
    mv "$WORKDIR/cosign.pub" "$WORKDIR/${pair}.pub"
  fi
done

# ----- 4. firmar -----
echo "-- firmando $IMAGE_BY_DIGEST con cosign.key"
cosign sign --yes --key "$WORKDIR/cosign.key" \
  --allow-insecure-registry \
  "$IMAGE_BY_DIGEST" >/dev/null 2>&1 || cosign sign --yes --key "$WORKDIR/cosign.key" \
  --allow-insecure-registry --tlog-upload=false \
  "$IMAGE_BY_DIGEST"

# ----- 5. verificación positiva -----
echo "-- verify con cosign.pub (debe pasar)"
if cosign verify --key "$WORKDIR/cosign.pub" \
    --allow-insecure-registry --insecure-ignore-tlog=true \
    "$IMAGE_BY_DIGEST" >/dev/null 2>&1; then
  echo "   OK positivo"
else
  echo "   FAIL positivo"
  exit 1
fi

# ----- 6. verificación negativa (debe fallar) -----
echo "-- verify con wrong.pub (debe fallar)"
if cosign verify --key "$WORKDIR/wrong.pub" \
    --allow-insecure-registry --insecure-ignore-tlog=true \
    "$IMAGE_BY_DIGEST" >/dev/null 2>&1; then
  echo "   FAIL: wrong.pub verificó, no debería"
  exit 1
else
  echo "   OK negativo (verify falló como se esperaba)"
fi

echo
echo "== TODO OK =="
echo "   artefactos en: $WORKDIR"
echo "   IMAGE_DIGEST : $(cat "$WORKDIR/IMAGE_DIGEST")"
echo
echo "Siguiente: escribe SIGN-LOG.md explicando que garantiza (y que no) esta firma."
