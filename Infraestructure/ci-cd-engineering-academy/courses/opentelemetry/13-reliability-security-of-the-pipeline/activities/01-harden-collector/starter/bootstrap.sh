#!/usr/bin/env bash
# Prepara /tmp/otel13-act01/ con certs y copia del collector.yaml insecure.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
BASE="${BASE_DIR:-/tmp/otel13-act01}"
mkdir -p "$BASE/queue" "$BASE/certs"

if command -v openssl >/dev/null 2>&1; then
  if [ ! -f "$BASE/certs/server.crt" ]; then
    cd "$BASE/certs"
    openssl genrsa -out ca.key 2048 2>/dev/null
    openssl req -x509 -new -nodes -key ca.key -sha256 -days 365 \
      -out ca.crt -subj "/CN=otel13-act01-ca" 2>/dev/null
    openssl genrsa -out server.key 2048 2>/dev/null
    cat > server.cnf <<'EOF'
[req]
distinguished_name = req_dn
req_extensions = v3_req
prompt = no
[req_dn]
CN = gateway
[v3_req]
subjectAltName = @alt_names
[alt_names]
DNS.1 = gateway
DNS.2 = localhost
IP.1  = 127.0.0.1
EOF
    openssl req -new -key server.key -out server.csr -config server.cnf 2>/dev/null
    openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
      -out server.crt -days 365 -sha256 \
      -extensions v3_req -extfile server.cnf 2>/dev/null
    rm -f server.csr server.cnf ca.srl
    cd "$HERE"
  fi
  echo "Certs listos en $BASE/certs/"
else
  echo "SKIP: openssl no instalado. El starter copiara la config pero el TLS no funcionara."
fi

cp "$HERE/collector.yaml" "$BASE/collector.yaml"
echo "Copiado starter/collector.yaml -> $BASE/collector.yaml (edita este ultimo)."
echo "Siguiente paso: edita $BASE/collector.yaml con los 7 controles, luego:"
echo "  docker compose -f $HERE/docker-compose.yaml up -d --force-recreate"
