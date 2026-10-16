#!/usr/bin/env bash
# Validate obs-02-01-up-and-running-local-stack.
#
# NOTE: deliberately NO `set -o pipefail`. Several checks pipe commands into
# `grep -q`; pipefail would surface spurious SIGPIPE (exit 141) on the producer
# when grep exits early with a match.
#
# Usage:
#   bash tests/validate.sh                 # assumes you already brought up the
#                                          # stack at $BASE_DIR (default /tmp/obs-02-01)
#   BASE_DIR=/path bash tests/validate.sh
#   USE_SOLUTION=1 bash tests/validate.sh  # tool brings up solution/ in an
#                                          # isolated compose project and tears it down

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ACT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BASE="${BASE_DIR:-/tmp/obs-02-01}"
USE_SOLUTION="${USE_SOLUTION:-0}"
PROJECT_NAME="obs0201validator"
PROM_PORT="${PROM_PORT:-9090}"
GRAFANA_PORT="${GRAFANA_PORT:-3000}"

passed=0
failed=0
report=""

note_ok()   { report+="  OK   -- $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL -- $1\n"; failed=$((failed+1)); }

echo "== Validating obs-02-01-up-and-running-local-stack =="

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
if ! command -v curl >/dev/null 2>&1; then
  echo "SKIP: curl no instalado. Nada que validar." >&2
  exit 0
fi

STARTED_HERE=0
cleanup() {
  if [ "$STARTED_HERE" = "1" ]; then
    echo "  INFO -- tearing down compose project $PROJECT_NAME"
    (cd "$ACT_DIR/solution" && docker compose -p "$PROJECT_NAME" down -v >/dev/null 2>&1 || true)
  fi
}
trap cleanup EXIT

if [ "$USE_SOLUTION" = "1" ]; then
  echo "  INFO -- bringing up solution/ as compose project '$PROJECT_NAME'"
  if ! (cd "$ACT_DIR/solution" && docker compose -p "$PROJECT_NAME" up -d >/dev/null 2>&1); then
    echo "FAIL: no se pudo levantar el stack de solution/." >&2
    exit 1
  fi
  STARTED_HERE=1
else
  if [ ! -d "$BASE" ]; then
    echo "FAIL: $BASE no existe. Copia starter primero:" >&2
    echo "  rm -rf $BASE && mkdir -p $BASE && cp -R $ACT_DIR/starter/. $BASE/" >&2
    echo "  cd $BASE && docker compose up -d" >&2
    exit 1
  fi
fi

# ---- Wait for Prometheus to be ready (up to ~60s) ----
ready=0
for i in $(seq 1 30); do
  if curl -fsS "http://localhost:${PROM_PORT}/-/ready" >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 2
done
if [ "$ready" != "1" ]; then
  note_fail "Prometheus no respondio /-/ready en ~60s en :${PROM_PORT}"
else
  note_ok "Prometheus /-/ready responde en :${PROM_PORT}"
fi

# ---- Grafana health (wait up to ~90s) ----
grafana_ready=0
for i in $(seq 1 45); do
  if curl -fsS "http://localhost:${GRAFANA_PORT}/api/health" 2>/dev/null | grep -q '"database"'; then
    grafana_ready=1
    break
  fi
  sleep 2
done
if [ "$grafana_ready" = "1" ]; then
  note_ok "Grafana /api/health responde JSON con 'database'"
else
  note_fail "Grafana /api/health no respondio en :${GRAFANA_PORT}"
fi

# ---- Wait for scrapes to populate (~30s) ----
sleep 20

# ---- Targets: both 'prometheus' and 'node' must be UP ----
targets_json="$(curl -fsS "http://localhost:${PROM_PORT}/api/v1/targets" 2>/dev/null || true)"
if [ -z "$targets_json" ]; then
  note_fail "No se pudo obtener /api/v1/targets"
else
  if printf '%s' "$targets_json" | grep -q '"job":"prometheus"'; then
    if printf '%s' "$targets_json" | grep -q '"health":"up"'; then
      note_ok "Target 'prometheus' presente en /api/v1/targets"
    else
      note_fail "Target 'prometheus' presente pero health != up"
    fi
  else
    note_fail "Target 'prometheus' ausente en /api/v1/targets"
  fi

  if printf '%s' "$targets_json" | grep -q '"job":"node"'; then
    # count 'up' occurrences near the node job: pragmatic grep for '"health":"up"'
    # we already asserted at least one up above; now check that node is NOT down.
    if printf '%s' "$targets_json" | grep -q '"job":"node"[^}]*"health":"down"'; then
      note_fail "Target 'node' esta DOWN en /api/v1/targets"
    else
      note_ok "Target 'node' presente y no DOWN"
    fi
  else
    note_fail "Target 'node' ausente — anade el job 'node' en prometheus.yml apuntando a node-exporter:9100"
  fi
fi

# ---- Query 'up' returns value 1 ----
up_json="$(curl -fsS "http://localhost:${PROM_PORT}/api/v1/query?query=up" 2>/dev/null || true)"
if printf '%s' "$up_json" | grep -q '"status":"success"'; then
  if printf '%s' "$up_json" | grep -q '"value":\[.*,"1"\]'; then
    note_ok "Query 'up' devolvio al menos una serie con valor 1"
  else
    note_fail "Query 'up' no devolvio ningun valor '1' (ningun target UP)"
  fi
else
  note_fail "Query 'up' no respondio status:success"
fi

# ---- Grafana datasource endpoint reachable (auth admin:admin) ----
if curl -fsS -u admin:admin "http://localhost:${GRAFANA_PORT}/api/datasources" >/dev/null 2>&1; then
  note_ok "Grafana /api/datasources responde con creds admin:admin"
else
  note_fail "Grafana /api/datasources no respondio (creds admin:admin)"
fi

echo
printf "%b" "$report"
echo
echo "RESULT: $passed/$((passed+failed)) checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
