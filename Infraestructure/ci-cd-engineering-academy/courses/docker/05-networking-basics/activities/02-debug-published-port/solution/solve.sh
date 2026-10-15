#!/usr/bin/env bash
# Solución: recrea 'broken-web' con bind correcto a 0.0.0.0.
set -eu

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker no instalado."
  exit 0
fi

docker rm -f broken-web >/dev/null 2>&1 || true
# El default de http.server es 0.0.0.0; omitir --bind basta. Lo dejamos explícito para claridad.
docker run -d --name broken-web -p 18086:8000 python:3.12-alpine \
  python -m http.server 8000 --bind 0.0.0.0 >/dev/null

for _ in 1 2 3 4 5; do
  curl -fsS -o /dev/null "http://localhost:18086/" && break
  sleep 1
done

echo "== Solución aplicada =="
docker port broken-web
curl -sS -o /dev/null -w "status=%{http_code}\n" http://localhost:18086/
