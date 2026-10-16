#!/usr/bin/env bash
# Validate otel-06-02-click-through-trace-to-logs.
#
# This is a mixed-validation activity. We check static artifacts (collector
# config has both pipelines, Grafana datasource has tracesToLogsV2, evidence
# files exist) and leave the actual Grafana click-through for manual review.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks pipe
# into `grep -q ...` which can produce SIGPIPE on the upstream producer; with
# pipefail that becomes a spurious failure.

WORK="${WORK_DIR:-/tmp/otel-06-02}"
passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }

# --- Preflight ---
missing=""
command -v docker >/dev/null 2>&1 || missing+=" docker"
command -v python3 >/dev/null 2>&1 || missing+=" python3"
if [ -n "$missing" ]; then
  cat <<EOF
SKIP: falta(n):$missing. Instala:
  - docker:   https://docs.docker.com/get-docker/
  - python3:  >=3.10 (brew install python@3.11 / apt install python3)
EOF
  exit 0
fi

echo "== Validando $WORK =="

if [ ! -d "$WORK" ]; then
  bad "no existe directorio $WORK (ejecuta la actividad antes)"
  printf "%b" "$report"
  echo "RESULT: FAIL"
  exit 1
fi

cd "$WORK" || { echo "cd $WORK fallo"; exit 1; }

# --- 1. Archivos esperados ---
for f in docker-compose.yml collector-config.yaml grafana-datasources.yaml tempo-config.yaml app.py evidence.md trace-id.txt; do
  if [ -f "$f" ]; then
    ok "existe $f"
  else
    bad "no existe $f"
  fi
done

# --- 2. Collector config tiene las dos pipelines ---
if [ -f collector-config.yaml ]; then
  if grep -q '^    traces:' collector-config.yaml || grep -q '    traces:' collector-config.yaml; then
    ok "collector-config.yaml tiene pipeline traces"
  else
    bad "collector-config.yaml no tiene pipeline traces"
  fi
  if grep -q '^    logs:' collector-config.yaml || grep -q '    logs:' collector-config.yaml; then
    ok "collector-config.yaml tiene pipeline logs"
  else
    bad "collector-config.yaml no tiene pipeline logs"
  fi
  if grep -q 'loki:' collector-config.yaml; then
    ok "collector-config.yaml declara exporter loki"
  else
    bad "collector-config.yaml no declara exporter loki"
  fi
fi

# --- 3. Grafana datasource tiene tracesToLogsV2 ---
if [ -f grafana-datasources.yaml ]; then
  if grep -q 'tracesToLogsV2' grafana-datasources.yaml; then
    ok "grafana-datasources.yaml tiene tracesToLogsV2"
  else
    bad "grafana-datasources.yaml no tiene tracesToLogsV2 (sin el, no hay click-through)"
  fi
fi

# --- 4. trace-id valido ---
if [ -f trace-id.txt ]; then
  tid="$(tr -d ' \n\r' < trace-id.txt)"
  tlen="${#tid}"
  if [ "$tlen" -eq 32 ] && echo "$tid" | grep -Eq '^[0-9a-fA-F]{32}$'; then
    ok "trace-id.txt tiene 32 hex chars"
  else
    bad "trace-id.txt no tiene 32 hex chars (len=$tlen, val='$tid')"
  fi
fi

# --- 5. app.py tiene las piezas clave ---
if [ -f app.py ]; then
  grep -q 'start_as_current_span' app.py && ok "app.py usa start_as_current_span" || bad "app.py no usa start_as_current_span"
  grep -q 'LoggerProvider' app.py && ok "app.py configura LoggerProvider" || bad "app.py no configura LoggerProvider"
  # 3 spans anidados: busca los 3 nombres sugeridos (receive, validate, charge)
  nspans=0
  for n in receive validate charge; do
    if grep -q "\"$n\"" app.py || grep -q "'$n'" app.py; then
      nspans=$((nspans+1))
    fi
  done
  if [ "$nspans" -ge 3 ]; then
    ok "app.py referencia los 3 nombres de span (receive, validate, charge)"
  else
    bad "app.py no referencia 3 spans (receive, validate, charge); encontrados: $nspans"
  fi
fi

# --- 6. evidence.md menciona lo esperado ---
if [ -f evidence.md ]; then
  for kw in span trace Loki LogQL; do
    if grep -qi "$kw" evidence.md; then
      ok "evidence.md menciona '$kw'"
    else
      bad "evidence.md no menciona '$kw'"
    fi
  done
fi

# --- 7. (Opcional) Si docker compose esta levantado, chequear Loki y Tempo responden ---
if command -v curl >/dev/null 2>&1; then
  if curl -s -o /dev/null -w '%{http_code}' http://localhost:3100/ready 2>/dev/null | grep -q '200'; then
    ok "Loki responde en localhost:3100"
  else
    report+="  INFO Loki no responde en localhost:3100 (manual verification)\n"
  fi
  if curl -s -o /dev/null -w '%{http_code}' http://localhost:3200/ready 2>/dev/null | grep -q '200'; then
    ok "Tempo responde en localhost:3200"
  else
    report+="  INFO Tempo no responde en localhost:3200 (manual verification)\n"
  fi
fi

printf "%b" "$report"
echo "----"
echo "PASS: $passed   FAIL: $failed"
if [ "$failed" -eq 0 ]; then
  echo "RESULT: PASS"
  exit 0
else
  echo "RESULT: FAIL"
  exit 1
fi
