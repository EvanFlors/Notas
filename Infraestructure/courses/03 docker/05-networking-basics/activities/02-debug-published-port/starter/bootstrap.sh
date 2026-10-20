#!/usr/bin/env bash
# Bootstrap: deja un contenedor publicado roto para debuggear.
# El bug: la app escucha SOLO en 127.0.0.1 (dentro del container), por lo que
# el DNAT de -p llega al namespace del container pero no hay socket que lo acepte.
set -eu

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker no instalado."
  exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker daemon no responde."
  exit 0
fi

docker rm -f broken-web >/dev/null 2>&1 || true

# python http.server escuchando SOLO en loopback del container.
docker run -d --name broken-web -p 18086:8000 python:3.12-alpine \
  python -m http.server 8000 --bind 127.0.0.1 >/dev/null

sleep 1

echo "== Bootstrap listo =="
docker ps --filter name=broken-web --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
echo
echo "Síntoma esperado: 'curl http://localhost:18086/' falla con 'connection reset' / 'empty reply'."
echo "Diagnostica y arregla sin cambiar el puerto publicado del host (18086)."
