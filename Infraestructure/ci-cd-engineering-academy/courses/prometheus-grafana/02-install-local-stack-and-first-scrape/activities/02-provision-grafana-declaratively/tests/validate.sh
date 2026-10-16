#!/usr/bin/env bash
# Validate obs-02-02-provision-grafana-declaratively.
#
# NOTE: deliberately NO `set -o pipefail`. Several checks pipe curl output into
# `grep -q`; pipefail would surface spurious SIGPIPE (exit 141) on curl when
# grep exits early with a match.
#
# Usage:
#   bash tests/validate.sh                 # assumes you already brought up the
#                                          # stack at $BASE_DIR (default /tmp/obs-02-02)
#   USE_SOLUTION=1 bash tests/validate.sh  # the tool brings up solution/ in an
#                                          # isolated compose project and tears it down

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ACT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BASE="${BASE_DIR:-/tmp/obs-02-02}"
USE_SOLUTION="${USE_SOLUTION:-0}"
PROJECT_NAME="obs0202validator"
PROM_PORT="${PROM_PORT:-9090}"
GRAFANA_PORT="${GRAFANA_PORT:-3000}"

passed=0
failed=0
report=""

note_ok()   { report+="  OK   -- $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL -- $1\n"; failed=$((failed+1)); }

echo "== Validating obs-02-02-provision-grafana-declaratively =="

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker CLI no instalado. Nada que validar." >&2
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
if ! command -v curl >/dev/null 2>&1; then
  echo "SKIP: curl no instalado." >&2
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
    echo "FAIL: $BASE no existe. Primero copia starter y levanta:" >&2
    echo "  rm -rf $BASE && mkdir -p $BASE && cp -R $ACT_DIR/starter/. $BASE/" >&2
    echo "  cd $BASE && docker compose up -d" >&2
    exit 1
  fi
fi

# ---- wait for Grafana to be ready (up to ~90s) ----
ready=0
for i in $(seq 1 45); do
  if curl -fsS "http://localhost:${GRAFANA_PORT}/api/health" >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 2
done
if [ "$ready" != "1" ]; then
  echo "FAIL: Grafana no respondio /api/health en ~90s" >&2
  exit 1
fi
note_ok "Grafana /api/health responde"

# ---- Prometheus up ----
if curl -fsS "http://localhost:${PROM_PORT}/-/ready" >/dev/null 2>&1; then
  note_ok "Prometheus /-/ready responde"
else
  note_fail "Prometheus /-/ready no responde"
fi

# ---- Datasource 'Prometheus' with uid 'prometheus' provisioned ----
ds_json="$(curl -fsS -u admin:admin "http://localhost:${GRAFANA_PORT}/api/datasources" 2>/dev/null || true)"
if printf '%s' "$ds_json" | grep -q '"uid":"prometheus"'; then
  note_ok "Datasource con uid 'prometheus' presente"
else
  note_fail "Datasource con uid 'prometheus' ausente — revisa provisioning/datasources/*.yml"
fi
if printf '%s' "$ds_json" | grep -q '"type":"prometheus"'; then
  note_ok "Datasource tiene type: prometheus"
else
  note_fail "Datasource tipo != prometheus"
fi

# ---- Datasource by uid returns 200 and url correct ----
ds_detail="$(curl -fsS -u admin:admin "http://localhost:${GRAFANA_PORT}/api/datasources/uid/prometheus" 2>/dev/null || true)"
if printf '%s' "$ds_detail" | grep -q '"url":"http://prometheus:9090"'; then
  note_ok "Datasource URL = http://prometheus:9090"
else
  note_fail "Datasource URL != http://prometheus:9090 (usa el nombre del servicio en compose)"
fi

# ---- Dashboard with uid 'obs02-overview' discoverable ----
search_json="$(curl -fsS -u admin:admin "http://localhost:${GRAFANA_PORT}/api/search?type=dash-db" 2>/dev/null || true)"
if printf '%s' "$search_json" | grep -q '"uid":"obs02-overview"'; then
  note_ok "Dashboard uid 'obs02-overview' encontrado"
else
  note_fail "Dashboard uid 'obs02-overview' no encontrado — revisa grafana/dashboards/*.json"
fi

# ---- Dashboard payload has a target referencing uid 'prometheus' ----
dash_payload="$(curl -fsS -u admin:admin "http://localhost:${GRAFANA_PORT}/api/dashboards/uid/obs02-overview" 2>/dev/null || true)"
if printf '%s' "$dash_payload" | grep -q '"uid":"prometheus"'; then
  note_ok "Dashboard referencia datasource uid 'prometheus'"
else
  note_fail "Dashboard no referencia uid 'prometheus' en ningun panel"
fi

# ---- Dashboard is marked as provisioned ----
if printf '%s' "$dash_payload" | grep -q '"provisioned":true'; then
  note_ok "Dashboard marcado como provisioned"
else
  note_fail "Dashboard NO esta marcado como provisioned (revisa provisioning/dashboards/*.yml)"
fi

echo
printf "%b" "$report"
echo
echo "RESULT: $passed/$((passed+failed)) checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
