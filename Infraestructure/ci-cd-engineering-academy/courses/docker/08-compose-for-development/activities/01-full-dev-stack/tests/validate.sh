#!/usr/bin/env bash
# Validate dkr-08-01-full-dev-stack.
#
# NOTE: deliberately NO `set -o pipefail`. Several checks pipe long-producing
# commands (docker inspect, docker compose logs) into `grep -q`; pipefail would
# surface spurious SIGPIPE (exit 141) on the producer when grep exits early.
#
# Usage:
#   bash tests/validate.sh             # uses /tmp/dkr-08-01-full-dev-stack
#   BASE_DIR=/path bash tests/validate.sh
#   USE_SOLUTION=1 bash tests/validate.sh   # validates the solution/ dir instead

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ACT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BASE="${BASE_DIR:-/tmp/dkr-08-01-full-dev-stack}"
USE_SOLUTION="${USE_SOLUTION:-0}"
PROJECT_NAME="dkr0801fdstest"
PROXY_PORT="${PROXY_PORT:-8080}"

passed=0
failed=0
report=""

note_ok()   { report+="  OK   -- $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL -- $1\n"; failed=$((failed+1)); }
note_skip() { report+="  SKIP -- $1\n"; }

echo "== Validating dkr-08-01-full-dev-stack =="

# ---- Precheck: docker + compose v2 ----
if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker CLI no instalado. Nada que validar." >&2
  exit 0
fi
if ! docker compose version >/dev/null 2>&1; then
  echo "SKIP: 'docker compose' v2 no instalado. Nada que validar." >&2
  exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "SKIP: Docker daemon no accesible. Nada que validar." >&2
  exit 0
fi

# ---- Determine source dir to validate ----
if [ "$USE_SOLUTION" = "1" ]; then
  SRC_DIR="$ACT_DIR/solution"
  echo "  INFO -- validando solution/"
else
  if [ ! -d "$BASE" ]; then
    echo "FAIL: $BASE no existe. Primero copia starter a /tmp:" >&2
    echo "  rm -rf $BASE && mkdir -p $BASE && cp -R $ACT_DIR/starter/. $BASE/" >&2
    exit 1
  fi
  SRC_DIR="$BASE"
fi

if [ ! -f "$SRC_DIR/compose.yaml" ]; then
  echo "FAIL: no se encuentra $SRC_DIR/compose.yaml" >&2
  exit 1
fi

cd "$SRC_DIR"

cleanup() {
  docker compose -p "$PROJECT_NAME" down -v --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT

# ---- Pre-cleanup ----
cleanup

# ---- Check 1: compose config parses ----
if docker compose -p "$PROJECT_NAME" config >/tmp/.dkr-08-01-config.yaml 2>/tmp/.dkr-08-01-config.err; then
  note_ok "compose.yaml parsea (docker compose config)"
else
  note_fail "compose.yaml no parsea (ver /tmp/.dkr-08-01-config.err)"
  printf "%b\n" "$report" >&2
  exit 1
fi

# ---- Check 2: three services declared ----
services="$(docker compose -p "$PROJECT_NAME" config --services 2>/dev/null | sort | tr '\n' ' ')"
expected="api db proxy "
if [ "$services" = "$expected" ]; then
  note_ok "los 3 servicios estan declarados: api, db, proxy"
else
  note_fail "esperaba servicios 'api db proxy', encontre: $services"
fi

# ---- Check 3: db declares a healthcheck ----
if grep -A1 'db:' /tmp/.dkr-08-01-config.yaml 2>/dev/null | grep -q "healthcheck" \
   || docker compose -p "$PROJECT_NAME" config 2>/dev/null | python3 -c "
import sys, yaml
d = yaml.safe_load(sys.stdin)
svc = d.get('services', {}).get('db', {})
sys.exit(0 if svc.get('healthcheck') else 1)
"; then
  note_ok "db declara healthcheck"
else
  note_fail "db NO declara healthcheck (requisito del lab)"
fi

# ---- Check 4: api depends_on db with condition service_healthy ----
if docker compose -p "$PROJECT_NAME" config 2>/dev/null | python3 -c "
import sys, yaml
d = yaml.safe_load(sys.stdin)
api = d.get('services', {}).get('api', {})
dep = api.get('depends_on', {})
if isinstance(dep, dict) and dep.get('db', {}).get('condition') == 'service_healthy':
    sys.exit(0)
sys.exit(1)
"; then
  note_ok "api depends_on db condition: service_healthy"
else
  note_fail "api NO depende de db con condition: service_healthy"
fi

# ---- Check 5: up with --wait ----
echo "  INFO -- levantando stack con 'docker compose up -d --wait --wait-timeout 150' (puede tardar en el primer build)..."
if docker compose -p "$PROJECT_NAME" up -d --build --wait --wait-timeout 150 >/tmp/.dkr-08-01-up.log 2>&1; then
  note_ok "docker compose up -d --wait termino exitoso"
else
  note_fail "docker compose up fallo (ver /tmp/.dkr-08-01-up.log)"
  tail -20 /tmp/.dkr-08-01-up.log >&2 || true
  printf "%b\n" "$report" >&2
  exit 1
fi

# ---- Check 6: endpoints via proxy ----
sleep 2
if curl -fsS "http://localhost:${PROXY_PORT}/" >/tmp/.dkr-08-01-root.out 2>/dev/null; then
  if grep -q '"status":"ok"' /tmp/.dkr-08-01-root.out; then
    note_ok "GET http://localhost:${PROXY_PORT}/ devuelve status ok"
  else
    note_fail "GET / respondio pero sin status ok: $(cat /tmp/.dkr-08-01-root.out)"
  fi
else
  note_fail "GET http://localhost:${PROXY_PORT}/ fallo (proxy no responde)"
fi

if curl -fsS "http://localhost:${PROXY_PORT}/db" >/tmp/.dkr-08-01-db.out 2>/dev/null; then
  if grep -q '"db":"ok"' /tmp/.dkr-08-01-db.out; then
    note_ok "GET http://localhost:${PROXY_PORT}/db devuelve db ok"
  else
    note_fail "GET /db respondio pero sin db ok: $(cat /tmp/.dkr-08-01-db.out)"
  fi
else
  note_fail "GET http://localhost:${PROXY_PORT}/db fallo"
fi

# ---- Check 7: ningun servicio en (unhealthy) o (starting) y los que tienen HC estan healthy ----
status_dump="$(docker compose -p "$PROJECT_NAME" ps --format '{{.Service}} {{.Status}}')"
bad="$(printf '%s\n' "$status_dump" | grep -E '\(unhealthy\)|\(starting\)' || true)"
if [ -z "$bad" ]; then
  note_ok "ningun servicio en (unhealthy) ni (starting)"
else
  note_fail "servicios en mal estado: $bad"
fi

healthy_count="$(printf '%s\n' "$status_dump" | grep -c '(healthy)' || true)"
if [ "$healthy_count" -ge 2 ]; then
  note_ok "al menos 2 servicios reportan (healthy): api y db"
else
  note_fail "esperaba >=2 servicios (healthy), vi $healthy_count"
fi

# ---- Check 8: down -v cleans up ----
if docker compose -p "$PROJECT_NAME" down -v >/tmp/.dkr-08-01-down.log 2>&1; then
  note_ok "docker compose down -v limpio exitosamente"
else
  note_fail "docker compose down -v fallo (ver /tmp/.dkr-08-01-down.log)"
fi

# No volume should remain
remaining="$(docker volume ls -q --filter "name=${PROJECT_NAME}_" | wc -l | tr -d ' ')"
if [ "$remaining" = "0" ]; then
  note_ok "no quedan volumenes del proyecto"
else
  note_fail "quedan $remaining volumenes del proyecto tras down -v"
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
