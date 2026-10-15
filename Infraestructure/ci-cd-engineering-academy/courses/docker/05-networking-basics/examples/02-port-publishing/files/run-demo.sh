#!/usr/bin/env bash
# Demo: -p host:container vs --network host.
#
# NOTA: sin `set -o pipefail` por el patrón `... | grep -q ...`.
set -eu

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker no instalado."
  exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker daemon no responde."
  exit 0
fi

cleanup() {
  docker rm -f pub1 pub2 hostnet >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

echo "== 1) -p 18080:80 (publicación con NAT) =="
docker run -d --rm --name pub1 -p 18080:80 nginx:alpine >/dev/null
# Dar unos segundos al nginx para estar listo
for _ in 1 2 3 4 5; do
  if curl -fsS -o /dev/null "http://localhost:18080/"; then break; fi
  sleep 1
done
curl -sS -o /dev/null -w "status=%{http_code}\n" "http://localhost:18080/"

echo
echo "== 2) Segundo -p 18080:80 (debe fallar: puerto ocupado) =="
if docker run -d --rm --name pub2 -p 18080:80 nginx:alpine 2>&1 | tee /tmp/.dkr05-pub2.log; then
  if grep -q "already allocated\|address already in use" /tmp/.dkr05-pub2.log; then
    echo "OK: puerto ocupado reportado (comportamiento esperado)."
  fi
else
  echo "OK: segundo bind rechazado (comportamiento esperado)."
fi
docker rm -f pub2 >/dev/null 2>&1 || true

echo
echo "== 3) --network host =="
# Docker Desktop (macOS/Windows) tiene semántica distinta: expone a la VM, no al Mac.
# Detectamos "Docker Desktop" en server y hacemos SKIP si aplica.
SERVER_OS="$(docker info --format '{{.OperatingSystem}}' 2>/dev/null || echo unknown)"
IS_DOCKER_DESKTOP=0
case "$SERVER_OS" in
  *"Docker Desktop"*) IS_DOCKER_DESKTOP=1;;
esac

if [ "$IS_DOCKER_DESKTOP" -eq 1 ]; then
  echo "SKIP: Docker Desktop detectado ($SERVER_OS)."
  echo "      '--network host' no expone al Mac/Windows real; usa -p siempre."
else
  docker run -d --rm --name hostnet --network host \
    -e NGINX_PORT=18090 \
    nginx:alpine >/dev/null
  # Nginx alpine por default escucha en 80; para esta demo necesitamos 18090.
  # Reconfiguramos rápidamente escribiendo un config minimal.
  docker exec hostnet sh -c "cat > /etc/nginx/conf.d/default.conf <<'EOF'
server { listen 18090; location / { return 200 \"host-net OK\n\"; } }
EOF
nginx -s reload" >/dev/null 2>&1 || true
  sleep 1
  curl -sS -o /dev/null -w "status=%{http_code}\n" "http://localhost:18090/" || true
fi

echo
echo "== Done =="
