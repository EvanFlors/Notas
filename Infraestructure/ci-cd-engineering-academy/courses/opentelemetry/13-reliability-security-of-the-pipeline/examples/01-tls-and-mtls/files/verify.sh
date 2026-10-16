#!/usr/bin/env bash
# End-to-end: generate certs, launch gateway+agent with TLS, swap to mTLS,
# verify behavior. No pipefail (we grep over logs that may exit early).
set -eu

BASE="${BASE_DIR:-/tmp/otel13-ex01}"
HERE="$(cd "$(dirname "$0")" && pwd)"

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker no instalado"; exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker daemon no accesible"; exit 0
fi
if ! command -v openssl >/dev/null 2>&1; then
  echo "SKIP: openssl no instalado"; exit 0
fi

bash "$HERE/bootstrap.sh"

echo
echo "== Fase 1: TLS server-side =="
cp "$HERE/gateway-tls.yaml" "$BASE/gateway.yaml"
cp "$HERE/agent-tls.yaml"   "$BASE/agent.yaml"
docker compose -f "$HERE/docker-compose.yaml" up -d --force-recreate
sleep 8

if docker logs otel13-ex01-gateway 2>&1 | grep -q "Everything is ready"; then
  echo "  OK: gateway listo con TLS"
else
  echo "  FAIL: gateway no arranco (TLS)" >&2
  docker logs otel13-ex01-gateway | tail -30 >&2
  exit 1
fi

if ! docker logs otel13-ex01-agent 2>&1 | grep -q "certificate signed by unknown"; then
  echo "  OK: agent conecta al gateway sin errores de cert"
else
  echo "  FAIL: agent reporta cert desconocido" >&2
  exit 1
fi

echo
echo "== Fase 2: mTLS =="
cp "$HERE/gateway-mtls.yaml" "$BASE/gateway.yaml"
cp "$HERE/agent-mtls.yaml"   "$BASE/agent.yaml"
docker compose -f "$HERE/docker-compose.yaml" restart
sleep 8

if docker logs otel13-ex01-gateway 2>&1 | tail -40 | grep -q "Everything is ready"; then
  echo "  OK: gateway listo con mTLS"
else
  echo "  FAIL: gateway no arranco (mTLS)" >&2
  exit 1
fi

# curl without client cert -> should fail
set +e
curl -sS --max-time 5 -k --cacert "$BASE/certs/ca.crt" \
  https://localhost:4318/v1/traces -d '{}' 2>&1 > /tmp/otel13-ex01-curl-noclient.out
rc=$?
set -e
if grep -qi "certificate required\|bad certificate\|handshake failure\|tls" /tmp/otel13-ex01-curl-noclient.out || [ $rc -ne 0 ]; then
  echo "  OK: curl sin client cert rechazado (comportamiento mTLS correcto)"
else
  echo "  FAIL: curl sin client cert fue aceptado" >&2
  cat /tmp/otel13-ex01-curl-noclient.out >&2
  exit 1
fi

# curl with client cert -> should pass TLS (may still get 400 for bad body)
set +e
http_code=$(curl -sS --max-time 5 -o /tmp/otel13-ex01-curl-ok.out -w "%{http_code}" \
  -k --cacert "$BASE/certs/ca.crt" \
  --cert "$BASE/certs/client.crt" --key "$BASE/certs/client.key" \
  https://localhost:4318/v1/traces -X POST -H "Content-Type: application/json" -d '{}')
rc=$?
set -e
if [ "$http_code" = "400" ] || [ "$http_code" = "200" ] || [ "$http_code" = "415" ]; then
  echo "  OK: curl con client cert supera TLS (HTTP $http_code)"
else
  echo "  FAIL: curl con client cert no supero TLS (HTTP $http_code, rc=$rc)" >&2
  exit 1
fi

echo
echo "== OK: TLS server-side y mTLS verificados =="
