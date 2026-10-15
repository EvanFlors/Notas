#!/usr/bin/env bash
# Bootstrap: prepara el scratch dir para dkr-05-01.
# No crea los contenedores: eso lo hace el estudiante.
set -eu

BASE="${1:-/tmp/dkr05-act1}"

rm -rf "$BASE"
mkdir -p "$BASE"

cat > "$BASE/NOTES.md" <<'EOF'
# dkr-05-01 — scratch

Objetivo: red `dkr05-act1-net` con contenedores `db` y `web`, DNS por nombre funcional, web publicado en 18085.

Pasos sugeridos:
  1. docker network create dkr05-act1-net
  2. docker run -d --rm --name db  --network dkr05-act1-net \
        -e POSTGRES_PASSWORD=demo postgres:16-alpine
  3. docker run -d --rm --name web --network dkr05-act1-net \
        -p 18085:80 nginx:alpine
  4. docker exec web  getent hosts db
  5. curl -sS -o /dev/null -w "%{http_code}\n" http://localhost:18085/
  6. Edita diagram.txt con el estado final.

Validar:
  bash courses/docker/05-networking-basics/activities/01-two-containers-talking-by-name/tests/validate.sh
EOF

cat > "$BASE/diagram.txt" <<'EOF'
<!-- Reemplaza este placeholder con un diagrama ASCII de tu red. -->
<!-- Debe incluir: host, red dkr05-act1-net, contenedores db y web, IPs internas, puerto 18085 publicado. -->
EOF

echo "== Bootstrap OK =="
echo "Scratch dir: $BASE"
echo "Lee $BASE/NOTES.md y edita $BASE/diagram.txt al terminar."
