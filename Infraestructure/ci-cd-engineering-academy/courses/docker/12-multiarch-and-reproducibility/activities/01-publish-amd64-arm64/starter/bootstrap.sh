#!/usr/bin/env bash
# Bootstrap for dkr-12-01-publish-amd64-arm64.
#
# MODE=local  (default): starts a local registry:2 on 127.0.0.1:5050 as container 'dkr12-registry'.
# MODE=live             : expects GHCR_OWNER + gh auth (or GHCR_TOKEN).
#
# Produces /tmp/dkr-12-publish/app/ with a PLACEHOLDER Dockerfile the student must build+push.
set -eu

BASE="${1:-${BASE_DIR:-/tmp/dkr-12-publish}}"
MODE="${MODE:-local}"
APP="$BASE/app"

if ! docker buildx version >/dev/null 2>&1; then
  echo "ERROR: docker buildx no esta disponible. Instala Docker Desktop reciente o el plugin buildx." >&2
  exit 2
fi

rm -rf "$BASE"
mkdir -p "$APP"

cat > "$APP/Dockerfile" <<'EOF'
# PLACEHOLDER — reemplaza o deja; lo importante es publicar multi-arch.
# Esta imagen es trivial a proposito; el foco de la actividad es el PROCESO
# de build con buildx, no el contenido del Dockerfile.
FROM alpine:3.20
RUN echo "arch=$(uname -m)" > /info.txt
CMD ["cat", "/info.txt"]
EOF

cat > "$APP/.dockerignore" <<'EOF'
.git
EOF

if [ "$MODE" = "local" ]; then
  # Clean previous registry container with same name.
  docker rm -f dkr12-registry >/dev/null 2>&1 || true
  # Puerto 5050 para no chocar con el registry de dkr-09 (que usa 5000).
  docker run -d --rm --name dkr12-registry -p 127.0.0.1:5050:5000 registry:2 >/dev/null
  # Wait for it to be ready.
  for i in 1 2 3 4 5 6 7 8; do
    if curl -sf http://127.0.0.1:5050/v2/ >/dev/null 2>&1; then break; fi
    sleep 1
  done
  echo "== Bootstrap OK (MODE=local) =="
  echo "App dir:  $APP"
  echo "Registry: 127.0.0.1:5050 (container dkr12-registry)"
  echo
  echo "Siguiente:"
  echo "  1) docker buildx create --name dkr12 --driver docker-container \\"
  echo "        --driver-opt network=host --use"
  echo "  2) docker buildx build --platform linux/amd64,linux/arm64 --provenance=false \\"
  echo "        -t 127.0.0.1:5050/dkr-12-app:v1 --push $APP"
  echo "  3) bash .../tests/validate.sh"
elif [ "$MODE" = "live" ]; then
  if [ -z "${GHCR_OWNER:-}" ]; then
    echo "ERROR: en MODE=live debes exportar GHCR_OWNER=<tu-user-o-org>." >&2
    exit 2
  fi
  # Login a GHCR si hay token o gh.
  if [ -n "${GHCR_TOKEN:-}" ]; then
    echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_OWNER" --password-stdin >/dev/null
  elif command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    gh auth token | docker login ghcr.io -u "$GHCR_OWNER" --password-stdin >/dev/null
  else
    echo "WARNING: ni GHCR_TOKEN ni 'gh auth status' disponibles; necesitaras loguearte a mano." >&2
  fi
  echo "== Bootstrap OK (MODE=live) =="
  echo "App dir:  $APP"
  echo "Target:   ghcr.io/$GHCR_OWNER/dkr-12-app:v1"
  echo
  echo "Siguiente:"
  echo "  1) docker buildx create --name dkr12 --driver docker-container --use"
  echo "  2) docker buildx build --platform linux/amd64,linux/arm64 --provenance=false \\"
  echo "        -t ghcr.io/$GHCR_OWNER/dkr-12-app:v1 --push $APP"
  echo "  3) MODE=live GHCR_OWNER=$GHCR_OWNER bash .../tests/validate.sh"
else
  echo "ERROR: MODE desconocido '$MODE' (usa 'local' o 'live')." >&2
  exit 2
fi
