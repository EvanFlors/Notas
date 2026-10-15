#!/usr/bin/env bash
# Example 01 for dkr-09 — login + tag + push, dual-mode (local|live).
#
# MODE=local (default): targets a local registry:2 at localhost:${REGISTRY_PORT:-5000}.
# MODE=live:            targets ghcr.io/${OWNER}/dkr09-demo using `gh auth token`.
#
# No `set -o pipefail`: we deliberately pipe long-producing commands into greps
# that may exit early (SIGPIPE on the producer); pipefail would spuriously fail.
set -eu

MODE="${MODE:-local}"
REGISTRY_PORT="${REGISTRY_PORT:-5000}"
IMAGE_NAME="dkr09-demo"
TAG_V="v1.0.0"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "== dkr-09 example 01: push to registry (MODE=$MODE) =="

# ---- Build base image locally ----
set -x
docker build -t "${IMAGE_NAME}:dev" .
set +x

if [ "$MODE" = "local" ]; then
  REG_HOST="localhost:${REGISTRY_PORT}"
  NAMESPACE="evan"
  REG_CONTAINER="dkr09-registry"

  # Ensure local registry:2 is running
  if ! docker ps --format '{{.Names}}' | grep -qx "$REG_CONTAINER"; then
    echo "+ docker run -d --rm --name $REG_CONTAINER -p ${REGISTRY_PORT}:5000 registry:2"
    docker run -d --rm --name "$REG_CONTAINER" -p "${REGISTRY_PORT}:5000" registry:2 >/dev/null
    # small warmup
    for _ in 1 2 3 4 5; do
      if curl -fsS "http://${REG_HOST}/v2/" >/dev/null 2>&1; then break; fi
      sleep 1
    done
  else
    echo "+ (reusing already-running $REG_CONTAINER)"
  fi

elif [ "$MODE" = "live" ]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "ERROR: gh CLI no instalado." >&2; exit 2
  fi
  if ! gh auth status >/dev/null 2>&1; then
    echo "ERROR: gh no autenticado (gh auth login)." >&2; exit 2
  fi
  OWNER="${OWNER:-$(gh api user -q .login)}"
  REG_HOST="ghcr.io"
  NAMESPACE="$OWNER"

  echo "+ docker login ghcr.io -u $OWNER --password-stdin  (via gh auth token)"
  gh auth token | docker login ghcr.io -u "$OWNER" --password-stdin
else
  echo "ERROR: MODE desconocido '$MODE' (usa local|live)" >&2; exit 2
fi

FULL_V="${REG_HOST}/${NAMESPACE}/${IMAGE_NAME}:${TAG_V}"
FULL_LATEST="${REG_HOST}/${NAMESPACE}/${IMAGE_NAME}:latest"

set -x
docker tag "${IMAGE_NAME}:dev" "$FULL_V"
docker tag "${IMAGE_NAME}:dev" "$FULL_LATEST"
docker push "$FULL_V"
docker push "$FULL_LATEST"
set +x

# Resolve the canonical digest from the local image's RepoDigests.
DIGEST_REF="$(docker inspect --format '{{range .RepoDigests}}{{println .}}{{end}}' "$FULL_V" \
             | grep "${REG_HOST}/${NAMESPACE}/${IMAGE_NAME}@" | head -n1 || true)"

if [ -z "$DIGEST_REF" ]; then
  echo "WARN: no se pudo leer RepoDigest; intentando pull para forzarlo..."
  docker pull "$FULL_V" >/dev/null
  DIGEST_REF="$(docker inspect --format '{{range .RepoDigests}}{{println .}}{{end}}' "$FULL_V" \
             | grep "${REG_HOST}/${NAMESPACE}/${IMAGE_NAME}@" | head -n1 || true)"
fi

echo
echo "TAG    : $FULL_V"
echo "DIGEST : ${DIGEST_REF:-<missing>}"
echo

if [ -n "$DIGEST_REF" ]; then
  echo "+ docker pull $DIGEST_REF"
  docker pull "$DIGEST_REF" >/dev/null
  echo "OK — tag y digest apuntan al mismo manifest."
fi

if [ "$MODE" = "live" ]; then
  echo
  echo "Verifica el paquete en: https://github.com/${NAMESPACE}?tab=packages"
fi

echo
echo "Para limpiar el registry local:"
echo "  docker stop dkr09-registry"
echo "  docker rmi ${IMAGE_NAME}:dev ${FULL_V} ${FULL_LATEST} || true"
