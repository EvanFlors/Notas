#!/usr/bin/env bash
# Example 02 for dkr-09 — pin by digest.
# Pushes two distinct manifests to the same tag :v1 to prove tags are mutable
# and digests are not.
#
# No `set -o pipefail`: deliberate; we pipe outputs into greps that may exit
# early on the producer (SIGPIPE), which pipefail would surface as spurious
# failures.
set -eu

REGISTRY_PORT="${REGISTRY_PORT:-5000}"
REG_HOST="localhost:${REGISTRY_PORT}"
REG_CONTAINER="dkr09-registry"
REF="${REG_HOST}/evan/base"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "== dkr-09 example 02: pin by digest =="

# ensure registry up
if ! docker ps --format '{{.Names}}' | grep -qx "$REG_CONTAINER"; then
  echo "+ docker run -d --rm --name $REG_CONTAINER -p ${REGISTRY_PORT}:5000 registry:2"
  docker run -d --rm --name "$REG_CONTAINER" -p "${REGISTRY_PORT}:5000" registry:2 >/dev/null
  for _ in 1 2 3 4 5; do
    if curl -fsS "http://${REG_HOST}/v2/" >/dev/null 2>&1; then break; fi
    sleep 1
  done
fi

resolve_digest() {
  # Prints the registry/name@sha256:... line for the given full ref.
  local full="$1"
  docker inspect --format '{{range .RepoDigests}}{{println .}}{{end}}' "$full" \
    | grep "${REF}@" | head -n1 || true
}

echo "--- PUSH #1 (variant A) ---"
set -x
docker build -f Dockerfile.v1a -t "${REF}:v1" .
docker push "${REF}:v1"
set +x
DIGEST_A="$(resolve_digest "${REF}:v1")"
echo "DIGEST_A = ${DIGEST_A:-<missing>}"

# remove the local tag so the second build does not reuse cached layers under same name
docker rmi "${REF}:v1" >/dev/null 2>&1 || true

echo
echo "--- PUSH #2 (variant B) to same tag :v1 ---"
set -x
docker build --no-cache -f Dockerfile.v1b -t "${REF}:v1" .
docker push "${REF}:v1"
set +x
DIGEST_B="$(resolve_digest "${REF}:v1")"
echo "DIGEST_B = ${DIGEST_B:-<missing>}"

echo
echo "== RESULT =="
echo "DIGEST_A: ${DIGEST_A:-<missing>}"
echo "DIGEST_B: ${DIGEST_B:-<missing>}"

if [ -n "$DIGEST_A" ] && [ -n "$DIGEST_B" ] && [ "$DIGEST_A" != "$DIGEST_B" ]; then
  echo "OK — el tag :v1 migro: ambos digests son distintos y cada uno sigue siendo inmutable."
else
  echo "WARN — no se detecto migracion de digest (puede pasar si Dockerfile.v1a y .v1b dieron el mismo resultado)."
fi

echo
echo "Prueba de inmutabilidad: pullear por digest trae exactamente esos bytes."
if [ -n "$DIGEST_A" ]; then
  docker pull "$DIGEST_A" >/dev/null && echo "  pull OK: $DIGEST_A"
fi
if [ -n "$DIGEST_B" ]; then
  docker pull "$DIGEST_B" >/dev/null && echo "  pull OK: $DIGEST_B"
fi

echo
echo "Limpieza: docker stop $REG_CONTAINER  &&  docker rmi ${REF}:v1 || true"
