#!/usr/bin/env bash
# Demo: DNS entre contenedores en una user-defined bridge vs la default.
#
# NOTA: no usamos `set -o pipefail` porque algunos chequeos piprean a `grep -q`
# y pipefail convertiría SIGPIPE en falso fallo.
set -eu

NET="dkr05-demo-net"

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker no está instalado."
  exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker daemon no responde."
  exit 0
fi

cleanup() {
  docker rm -f web client web2 client2 >/dev/null 2>&1 || true
  docker network rm "$NET" >/dev/null 2>&1 || true
}
trap cleanup EXIT

cleanup

echo "== 1) Crear user-defined bridge =="
docker network create "$NET" >/dev/null
docker network ls | grep "$NET"

echo
echo "== 2) Correr 'web' y 'client' en $NET =="
docker run -d --rm --name web    --network "$NET" nginx:alpine >/dev/null
docker run -d --rm --name client --network "$NET" alpine sleep 300 >/dev/null

echo
echo "== 3) Resolver 'web' por nombre desde 'client' =="
docker exec client getent hosts web || true
docker exec client wget -q -O - --timeout=5 http://web:80/ | head -n 1 || true

echo
echo "== 4) Mismo experimento en la red default (sin DNS por nombre) =="
docker run -d --rm --name web2    nginx:alpine >/dev/null
docker run -d --rm --name client2 alpine sleep 300 >/dev/null
# Debe FALLAR la resolución por nombre:
if docker exec client2 getent hosts web2 >/dev/null 2>&1; then
  echo "INESPERADO: la red default resolvió 'web2' por nombre."
else
  echo "OK: en la red default, 'web2' no resuelve por nombre (comportamiento esperado)."
fi
# Pero por IP sí (los contenedores están en el mismo bridge default):
WEB2_IP="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' web2)"
echo "   IP de web2: $WEB2_IP"
docker exec client2 wget -q -O - --timeout=5 "http://${WEB2_IP}:80/" | head -n 1 || true

echo
echo "== Done =="
