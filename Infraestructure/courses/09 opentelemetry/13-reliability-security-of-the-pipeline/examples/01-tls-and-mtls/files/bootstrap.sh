#!/usr/bin/env bash
# Generate self-signed CA + server cert + client cert for the TLS/mTLS example.
# Idempotent: skips if certs already exist.
# No pipefail: we grep over openssl output.
set -eu

BASE="${BASE_DIR:-/tmp/otel13-ex01}"
CERTS="$BASE/certs"

if ! command -v openssl >/dev/null 2>&1; then
  echo "SKIP: openssl no instalado. Instala con: brew install openssl / apt-get install openssl"
  exit 0
fi

mkdir -p "$CERTS"
cd "$CERTS"

if [ -f ca.crt ] && [ -f server.crt ] && [ -f client.crt ]; then
  echo "Certs ya existen en $CERTS; nada que hacer."
  exit 0
fi

echo "== Generando CA =="
openssl genrsa -out ca.key 4096 2>/dev/null
openssl req -x509 -new -nodes -key ca.key -sha256 -days 365 \
  -out ca.crt -subj "/CN=otel13-ex01-ca" 2>/dev/null

echo "== Generando server cert (CN=gateway, SAN=gateway,localhost) =="
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

echo "== Generando client cert (CN=agent) =="
openssl genrsa -out client.key 2048 2>/dev/null
openssl req -new -key client.key -out client.csr \
  -subj "/CN=agent" 2>/dev/null
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out client.crt -days 365 -sha256 2>/dev/null

rm -f server.csr client.csr server.cnf ca.srl
chmod 644 "$CERTS"/*.crt "$CERTS"/*.key

echo
echo "Certs generados en $CERTS:"
ls -la "$CERTS"
