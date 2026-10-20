#!/usr/bin/env bash
# Validate dkr-08-02-flaky-startup-fix-with-healthcheck.
#
# NOTE: deliberately NO `set -o pipefail`. Several checks pipe long-producing
# commands into `grep -q`; pipefail would surface spurious SIGPIPE (exit 141).
#
# Runs TWO consecutive up/curl/down cycles to prove non-flakiness.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ACT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BASE="${BASE_DIR:-/tmp/dkr-08-02-flaky-startup}"
USE_SOLUTION="${USE_SOLUTION:-0}"
PROJECT_NAME="dkr0802flakytest"
APP_PORT="${APP_PORT:-8010}"

passed=0
failed=0
report=""

note_ok()   { report+="  OK   -- $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL -- $1\n"; failed=$((failed+1)); }

echo "== Validating dkr-08-02-flaky-startup-fix-with-healthcheck =="

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker CLI no instalado." >&2
  exit 0
fi
if ! docker compose version >/dev/null 2>&1; then
  echo "SKIP: 'docker compose' v2 no instalado." >&2
  exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "SKIP: Docker daemon no accesible." >&2
  exit 0
fi

if [ "$USE_SOLUTION" = "1" ]; then
  SRC_DIR="$ACT_DIR/solution"
  echo "  INFO -- validando solution/"
else
  if [ ! -d "$BASE" ]; then
    echo "FAIL: $BASE no existe. Copia starter primero:" >&2
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

cleanup

# ---- Structural checks ----
if docker compose -p "$PROJECT_NAME" config 2>/dev/null | python3 -c "
import sys, yaml
d = yaml.safe_load(sys.stdin)
db = d.get('services', {}).get('db', {})
sys.exit(0 if db.get('healthcheck') else 1)
"; then
  note_ok "db declara healthcheck"
else
  note_fail "db NO declara healthcheck (necesario para arreglar la carrera)"
fi

if docker compose -p "$PROJECT_NAME" config 2>/dev/null | python3 -c "
import sys, yaml
d = yaml.safe_load(sys.stdin)
api = d.get('services', {}).get('api', {})
dep = api.get('depends_on', {})
if isinstance(dep, dict) and dep.get('db', {}).get('condition') == 'service_healthy':
    sys.exit(0)
sys.exit(1)
"; then
  note_ok "api depends_on db con condition: service_healthy"
else
  note_fail "api NO usa depends_on con condition: service_healthy"
fi

# ---- Two consecutive runs ----
run_once() {
  local attempt="$1"
  echo "  INFO -- iteracion $attempt: up --wait + curl /db + down -v"
  docker compose -p "$PROJECT_NAME" down -v --remove-orphans >/dev/null 2>&1 || true
  if ! docker compose -p "$PROJECT_NAME" up -d --build --wait --wait-timeout 120 \
       >/tmp/.dkr-08-02-up-$attempt.log 2>&1; then
    note_fail "iteracion $attempt: up --wait fallo"
    tail -15 /tmp/.dkr-08-02-up-$attempt.log >&2 || true
    return 1
  fi
  # Pequena ventana (hasta 10s) para que uvicorn abra el socket; db ya esta healthy
  # por el fix, asi que esta espera es solo para app startup, no para la carrera DB.
  local ok=0
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if curl -fsS "http://localhost:${APP_PORT}/db" >/tmp/.dkr-08-02-db-$attempt.out 2>/dev/null; then
      if grep -q '"db":"ok"' /tmp/.dkr-08-02-db-$attempt.out; then
        ok=1
        break
      fi
    fi
    sleep 1
  done
  if [ "$ok" = "1" ]; then
    note_ok "iteracion $attempt: /db respondio db:ok"
    return 0
  else
    note_fail "iteracion $attempt: /db nunca respondio db:ok (ultimo: $(cat /tmp/.dkr-08-02-db-$attempt.out 2>/dev/null))"
    docker compose -p "$PROJECT_NAME" logs api 2>&1 | tail -10 >&2 || true
    return 1
  fi
}

run_once 1
run_once 2

cleanup

echo
printf "%b" "$report"
echo
total=$((passed + failed))
echo "RESULT: $passed/$total checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
