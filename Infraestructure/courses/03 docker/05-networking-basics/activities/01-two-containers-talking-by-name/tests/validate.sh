#!/usr/bin/env bash
# Validator: dkr-05-01-two-containers-talking-by-name.
#
# NOTA: no `set -o pipefail`. Varios checks hacen `... | grep -q ...` y
# pipefail convertiría SIGPIPE del productor en falso FAIL.

NET="dkr05-act1-net"
HOST_PORT="${HOST_PORT:-18085}"

passed=0
failed=0
report=""

note_ok()   { report+="  OK   -- $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL -- $1\n"; failed=$((failed+1)); }

echo "== Validando dkr-05-01-two-containers-talking-by-name =="

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker no instalado — no se puede validar esta actividad."
  exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker daemon no responde."
  exit 0
fi

# Check 1: red existe
if docker network inspect "$NET" >/dev/null 2>&1; then
  note_ok "red '$NET' existe"
else
  note_fail "red '$NET' NO existe (crea con: docker network create $NET)"
fi

# Check 2: contenedores db y web existen y corren
for c in db web; do
  if docker inspect -f '{{.State.Running}}' "$c" 2>/dev/null | grep -qx true; then
    note_ok "contenedor '$c' corriendo"
  else
    note_fail "contenedor '$c' no existe o no corre"
  fi
done

# Check 3: ambos están conectados a la red
for c in db web; do
  if docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$c" 2>/dev/null | grep -qw "$NET"; then
    note_ok "'$c' conectado a '$NET'"
  else
    note_fail "'$c' NO está en '$NET'"
  fi
done

# Check 4: DNS por nombre entre contenedores (web resuelve db)
if docker exec web getent hosts db >/dev/null 2>&1; then
  note_ok "web resuelve 'db' por nombre"
else
  note_fail "web NO resuelve 'db' (¿usaste la bridge default?)"
fi

# Check 5: puerto publicado y responde
# Pequeño retry por si nginx tarda en levantar
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
  note_fail "curl http://localhost:${HOST_PORT}/ -> $status (esperado 200)"
fi

# Check 6: diagrama no es el placeholder
DIAGRAM="${BASE_DIR:-/tmp/dkr05-act1}/diagram.txt"
if [ -f "$DIAGRAM" ]; then
  if grep -q "Reemplaza este placeholder" "$DIAGRAM"; then
    note_fail "diagrama en $DIAGRAM sigue siendo el placeholder"
  else
    # al menos 3 líneas con algún caracter visible
    non_empty_lines="$(grep -c '[^[:space:]]' "$DIAGRAM" 2>/dev/null || echo 0)"
    if [ "$non_empty_lines" -ge 3 ]; then
      note_ok "diagrama no vacío en $DIAGRAM ($non_empty_lines líneas)"
    else
      note_fail "diagrama en $DIAGRAM demasiado corto"
    fi
  fi
else
  note_fail "no existe $DIAGRAM (¿corriste starter/bootstrap.sh?)"
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
