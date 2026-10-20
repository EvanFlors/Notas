#!/usr/bin/env bash
# Validator: dkr-05-02-debug-published-port.
# NOTA: sin `set -o pipefail` (hay pipes a `grep -q`).

HOST_PORT=18086
CONTAINER=broken-web

passed=0
failed=0
report=""
note_ok()   { report+="  OK   -- $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL -- $1\n"; failed=$((failed+1)); }

echo "== Validando dkr-05-02-debug-published-port =="

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker no instalado."
  exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker daemon no responde."
  exit 0
fi

# Check 1: contenedor corre
if docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null | grep -qx true; then
  note_ok "contenedor '$CONTAINER' corriendo"
else
  note_fail "contenedor '$CONTAINER' no existe o no corre"
fi

# Check 2: publicación 18086 -> 8000
port_map="$(docker port "$CONTAINER" 8000/tcp 2>/dev/null || true)"
if echo "$port_map" | grep -q ":${HOST_PORT}\$"; then
  note_ok "publicación 8000/tcp -> *:${HOST_PORT} activa"
else
  note_fail "publicación 8000/tcp -> *:${HOST_PORT} ausente (visto: ${port_map:-nada})"
fi

# Check 3: curl desde el host responde 200
status="000"
for _ in 1 2 3 4 5; do
  status="$(curl -sS -o /dev/null -w "%{http_code}" --max-time 3 "http://localhost:${HOST_PORT}/" 2>/dev/null)"
  [ -z "$status" ] && status="000"
  [ "$status" = "200" ] && break
  sleep 1
done
if [ "$status" = "200" ]; then
  note_ok "curl http://localhost:${HOST_PORT}/ -> 200"
else
  note_fail "curl http://localhost:${HOST_PORT}/ -> ${status} (esperado 200)"
fi

# Check 4: dentro del contenedor, el bind es a 0.0.0.0 (no a 127.0.0.1)
listen_line=""
if docker exec "$CONTAINER" sh -c "command -v ss >/dev/null 2>&1"; then
  listen_line="$(docker exec "$CONTAINER" ss -ltn 2>/dev/null | awk 'NR>1 {print $4}' | grep ":8000\$" || true)"
elif docker exec "$CONTAINER" sh -c "command -v netstat >/dev/null 2>&1"; then
  listen_line="$(docker exec "$CONTAINER" netstat -ltn 2>/dev/null | awk 'NR>2 {print $4}' | grep ":8000\$" || true)"
else
  # fallback: /proc/net/tcp. Local 00000000:1F40 => 0.0.0.0:8000.
  tcp_line="$(docker exec "$CONTAINER" sh -c "cat /proc/net/tcp 2>/dev/null | awk '\$2 ~ /:1F40\$/ && \$4==\"0A\" {print \$2}'" | head -n1)"
  case "$tcp_line" in
    00000000:1F40) listen_line="0.0.0.0:8000";;
    0100007F:1F40) listen_line="127.0.0.1:8000";;
  esac
fi

if echo "$listen_line" | grep -Eq "^(0\.0\.0\.0|\*|\[::\]|:::):8000$"; then
  note_ok "proceso adentro escucha en 0.0.0.0:8000 (bind correcto)"
elif echo "$listen_line" | grep -q "^127\.0\.0\.1:8000\$"; then
  note_fail "proceso adentro escucha en 127.0.0.1:8000 (bug: debe ser 0.0.0.0)"
else
  note_fail "no se pudo determinar el bind (visto: ${listen_line:-nada})"
fi

echo
printf "%b" "$report"
echo
total=$((passed + failed))
echo "RESULT: $passed/$total checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
