#!/usr/bin/env bash
# Levanta un registry local (si no existe), genera un key pair cosign offline,
# empuja una imagen base y la firma. Deja cosign.pub listo para la ClusterPolicy.
#
# Idempotente: si el key pair ya existe, lo reutiliza.
set -euo pipefail

REGISTRY_NAME="${REGISTRY_NAME:-k8s-16-registry}"
REGISTRY_PORT="${REGISTRY_PORT:-5001}"
IMAGE_REF="${IMAGE_REF:-localhost:${REGISTRY_PORT}/app/web:v1}"
BASE_IMAGE="${BASE_IMAGE:-nginxinc/nginx-unprivileged:1.27-alpine}"

for bin in docker cosign kubectl; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "ERROR: $bin no instalado" >&2
    exit 1
  fi
done

# 1) Registry local
if ! docker inspect "$REGISTRY_NAME" >/dev/null 2>&1; then
  echo "Creando registry local $REGISTRY_NAME en :$REGISTRY_PORT ..."
  docker run -d --restart=always -p "127.0.0.1:${REGISTRY_PORT}:5000" --name "$REGISTRY_NAME" registry:2
else
  echo "Registry $REGISTRY_NAME ya existe"
fi

# 2) Key pair cosign offline (sin passphrase para lab)
if [ ! -f cosign.key ] || [ ! -f cosign.pub ]; then
  echo "Generando key pair cosign (sin passphrase, lab) ..."
  COSIGN_PASSWORD="" cosign generate-key-pair
else
  echo "Key pair cosign ya existe"
fi

# 3) Pull + retag + push
docker pull "$BASE_IMAGE"
docker tag "$BASE_IMAGE" "$IMAGE_REF"
docker push "$IMAGE_REF"

# 4) Firma la imagen (modo offline: --tlog-upload=false evita Rekor publico)
echo "Firmando $IMAGE_REF con cosign (offline) ..."
COSIGN_PASSWORD="" cosign sign --yes --key cosign.key --tlog-upload=false "$IMAGE_REF"

# 5) Verifica localmente que la firma es valida
cosign verify --key cosign.pub --insecure-ignore-tlog "$IMAGE_REF" >/dev/null
echo "OK: $IMAGE_REF firmada y verificable con cosign.pub"

echo
echo "Public key:"
cat cosign.pub
