#!/usr/bin/env bash
# Verify PII plantada no aparece literal en el output del Collector.
# No pipefail (grep -q sobre docker logs puede exit-early con SIGPIPE).
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"

if ! command -v docker >/dev/null 2>&1; then echo "SKIP: docker"; exit 0; fi
if ! docker info >/dev/null 2>&1; then echo "SKIP: dockerd"; exit 0; fi

cd "$HERE"
docker compose up -d --force-recreate
sleep 5

bash push-pii-spans.sh >/dev/null 2>&1 || { echo "FAIL: telemetrygen push"; exit 1; }
sleep 4

logs=$(docker logs otel13-ex03-collector 2>&1)

fail=0
check() {
  local pattern="$1" label="$2"
  if echo "$logs" | grep -qF "$pattern"; then
    echo "  FAIL: '$label' aparece literal en logs"
    fail=1
  else
    echo "  OK  : '$label' NO aparece literal"
  fi
}

echo "== Verificando scrubbing =="
check "hunter2-not-a-real-secret" "user.password"
check "Bearer dev-token-not-a-secret" "authorization header"
check "4111111111111111" "credit card number"
check "123-45-6789" "ssn"
check "alice@example.com" "user.email literal (debe estar hasheado)"
check "shouldberedacted" "token value in query"
check "bob@example.com" "email dentro de http.url"

# Positivo: el hash o REDACTED debe aparecer
if echo "$logs" | grep -qE "REDACTED|\\*\\*\\*@\\*\\*\\*|user\\.email"; then
  echo "  OK  : marcadores de scrubbing presentes"
else
  echo "  FAIL: no se ven marcadores de scrubbing en el output"
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "== OK: PII scrubbing verificado =="
else
  echo "== FAIL ==" >&2
  echo "--- Logs del Collector ---" >&2
  echo "$logs" | tail -80 >&2
  exit 1
fi
