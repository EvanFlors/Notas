#!/usr/bin/env bash
# Solución de referencia para dkr-05-01.
set -eu

BASE="${1:-/tmp/dkr05-act1}"
NET="dkr05-act1-net"

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker no instalado."
  exit 0
fi

HERE="$(cd "$(dirname "$0")/.." && pwd)"
bash "$HERE/starter/bootstrap.sh" "$BASE" >/dev/null

# Limpieza defensiva
docker rm -f db web >/dev/null 2>&1 || true
docker network rm "$NET" >/dev/null 2>&1 || true

docker network create "$NET" >/dev/null
docker run -d --rm --name db  --network "$NET" \
  -e POSTGRES_PASSWORD=demo postgres:16-alpine >/dev/null
docker run -d --rm --name web --network "$NET" \
  -p 18085:80 nginx:alpine >/dev/null

# Dar unos segundos a nginx
for _ in 1 2 3 4 5; do
  curl -fsS -o /dev/null "http://localhost:18085/" && break
  sleep 1
done

DB_IP="$(docker inspect -f "{{(index .NetworkSettings.Networks \"$NET\").IPAddress}}" db)"
WEB_IP="$(docker inspect -f "{{(index .NetworkSettings.Networks \"$NET\").IPAddress}}" web)"

cat > "$BASE/diagram.txt" <<EOF
HOST
  |
  |--  (localhost:18085) --> DNAT --> web:80
  |
  +--  network: $NET (bridge)
          |
          +-- db  ($DB_IP)   postgres:16-alpine  5432/tcp
          +-- web ($WEB_IP)  nginx:alpine        80/tcp  (publicado en host:18085)

DNS por nombre dentro de $NET: web<->db resuelven via 127.0.0.11 (embedded resolver).
EOF

echo "== Solución aplicada =="
echo "Red: $NET"
echo "web: $WEB_IP  db: $DB_IP"
echo "Diagram: $BASE/diagram.txt"
