#!/usr/bin/env bash
# Demo: por qué `localhost` dentro de un contenedor NO es el host.
#
# NOTA: sin `set -o pipefail` por los pipes a `grep -q`.
set -eu

NET="dkr05-pitfall-net"

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker no instalado."
  exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker daemon no responde."
  exit 0
fi

cleanup() {
  docker rm -f db client bad >/dev/null 2>&1 || true
  docker network rm "$NET" >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

echo "== Exp 1: localhost dentro del contenedor NO es el host =="
docker run -d --rm --name db -p 18081:5432 \
  -e POSTGRES_PASSWORD=demo postgres:16-alpine >/dev/null
# Esperar a que postgres acepte TCP
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if nc -z localhost 18081 2>/dev/null; then break; fi
  sleep 1
done

# Desde un contenedor NUEVO sin red compartida, "localhost" es su propio ns.
set +e
docker run --rm alpine sh -c "apk add -q --no-cache busybox-extras >/dev/null; nc -z -w2 localhost 18081"
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
  echo "OK (esperado): desde otro contenedor, 'localhost:18081' no responde."
else
  echo "INESPERADO: 'localhost' adentro resolvió al host."
fi

echo
echo "== Exp 2: user-defined bridge + nombre =="
docker network create "$NET" >/dev/null
docker network connect "$NET" db
docker run --rm --network "$NET" alpine sh -c "nc -z -w2 db 5432 && echo 'OK: db:5432 responde'"

echo
echo "== Exp 3: app bindeada a 127.0.0.1 adentro, -p no la salva =="
# Levantamos un python http.server escuchando SOLO en 127.0.0.1 dentro del contenedor.
docker run -d --rm --name bad -p 18082:8000 python:3.12-alpine \
  python -m http.server 8000 --bind 127.0.0.1 >/dev/null
sleep 2
set +e
curl -fsS -o /dev/null --max-time 3 "http://localhost:18082/"
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
  echo "OK (esperado): -p no alcanza una app bindeada a 127.0.0.1 adentro."
  echo "Fix: --bind 0.0.0.0  (o quitarlo, es el default)."
else
  echo "INESPERADO: la conexión funcionó."
fi

echo
echo "== Done =="
