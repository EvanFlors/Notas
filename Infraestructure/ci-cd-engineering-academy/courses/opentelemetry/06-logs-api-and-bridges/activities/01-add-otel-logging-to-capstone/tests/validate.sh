#!/usr/bin/env bash
# Validate otel-06-01-add-otel-logging-to-capstone.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks pipe
# into `grep -q ...` which can produce SIGPIPE (exit 141) on the upstream
# producer when grep matches early; pipefail would turn that into a false fail.

WORK="${WORK_DIR:-/tmp/otel-06-01}"
passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }

# --- Preflight ---
if ! command -v python3 >/dev/null 2>&1; then
  cat <<EOF
SKIP: 'python3' no esta instalado. Instala Python >= 3.10 y repite.
  - macOS Homebrew:  brew install python@3.11
  - Ubuntu/Debian:   sudo apt install python3 python3-venv python3-pip
Luego verifica: python3 --version
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

if [ ! -f app.py ]; then
  bad "no existe app.py en $WORK"
  printf "%b" "$report"
  echo "RESULT: FAIL"
  exit 1
fi

# --- 1. Codigo: wiring esperado ---
if grep -q 'LoggerProvider' app.py; then
  ok "app.py importa/instancia LoggerProvider"
else
  bad "app.py no instancia LoggerProvider"
fi

if grep -q 'LoggingHandler' app.py; then
  ok "app.py usa LoggingHandler"
else
  bad "app.py no usa LoggingHandler"
fi

if grep -q 'BatchLogRecordProcessor' app.py; then
  ok "app.py usa BatchLogRecordProcessor"
else
  bad "app.py no usa BatchLogRecordProcessor (debe batchear, no SimpleLogRecordProcessor)"
fi

if grep -q 'addHandler' app.py; then
  ok "app.py adjunta el handler a un logger"
else
  bad "app.py no llama addHandler"
fi

if grep -q '_LOGGER_PROVIDER.shutdown()' app.py || grep -q 'LOGGER_PROVIDER.shutdown()' app.py; then
  ok "app.py cierra el LoggerProvider en shutdown"
else
  bad "app.py no llama shutdown() sobre el LoggerProvider"
fi

# --- 2. Ejecutar y capturar salida ---
# Decidimos que Python usar:
#   1) .venv local (recomendado por README)
#   2) VIRTUAL_ENV activo externo
#   3) python3 del sistema si tiene opentelemetry
# Si ninguno funciona, SKIPeamos este tramo con un mensaje claro.
PY=""
if [ -x .venv/bin/python3 ] && .venv/bin/python3 -c "import opentelemetry.sdk._logs" >/dev/null 2>&1; then
  PY=".venv/bin/python3"
elif [ -n "$VIRTUAL_ENV" ] && "$VIRTUAL_ENV/bin/python3" -c "import opentelemetry.sdk._logs" >/dev/null 2>&1; then
  PY="$VIRTUAL_ENV/bin/python3"
elif python3 -c "import opentelemetry.sdk._logs" >/dev/null 2>&1; then
  PY="python3"
fi

if [ -z "$PY" ]; then
  bad "no encontre un python con 'opentelemetry' instalado. Corre: python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt"
else
  "$PY" app.py > out.json 2>&1
  rc=$?
  if [ "$rc" -ne 0 ]; then
    bad "app.py termino con codigo $rc. Mira $WORK/out.json"
  fi
fi

# --- 3. Validar contenido de la salida ---
log_count="$(grep -c '"severity_number"' out.json 2>/dev/null)"
log_count="${log_count:-0}"
if [ "$log_count" -ge 3 ]; then
  ok "se emitieron $log_count LogRecord OTel (>=3)"
else
  bad "solo $log_count LogRecord OTel encontrados (esperado >=3). Mira $WORK/out.json"
fi

# Para contar trace_id no-cero asociados a LogRecords (no a spans), usamos
# python: parseamos cada bloque JSON y contamos los que tienen severity_number
# y un trace_id distinto de todo-cero.
real_trace_count="$(python3 - <<'PY' 2>/dev/null
import json, re, sys
try:
    text = open("out.json").read()
except Exception:
    print(0); sys.exit(0)
# Dividir por bloques JSON de nivel superior (los exporters imprimen "{...}\n")
decoder = json.JSONDecoder()
i = 0
count = 0
while i < len(text):
    m = re.search(r"\{", text[i:])
    if not m:
        break
    try:
        obj, end = decoder.raw_decode(text[i+m.start():])
        i = i + m.start() + end
        if isinstance(obj, dict) and "severity_number" in obj:
            tid = obj.get("trace_id", "")
            if isinstance(tid, str) and tid.startswith("0x") and set(tid[2:]) - {"0"}:
                count += 1
    except Exception:
        i = i + m.start() + 1
print(count)
PY
)"
real_trace_count="${real_trace_count:-0}"
if [ "$real_trace_count" -ge 3 ]; then
  ok "al menos 3 LogRecord con trace_id real ($real_trace_count)"
else
  bad "solo $real_trace_count LogRecord con trace_id real (esperado >=3). Los logs dentro del span deberian tenerlo."
fi

if grep -q 'otel-06-01-capstone' out.json; then
  ok "Resource service.name correcto"
else
  bad "no veo service.name=otel-06-01-capstone en el Resource. Reusa el mismo RESOURCE para traces y logs."
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
