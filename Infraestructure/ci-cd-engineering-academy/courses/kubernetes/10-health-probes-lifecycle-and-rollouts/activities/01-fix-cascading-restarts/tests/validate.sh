#!/usr/bin/env bash
# Validate k8s-10-01-fix-cascading-restarts.
# Lee /tmp/k8s-10-01/deployment.yaml y comprueba la forma esperada de las
# probes (startup/readiness/liveness).
#
# Note: we deliberately do NOT enable `set -o pipefail`. Varios checks usan
# `... | grep -q ...` que puede provocar SIGPIPE (exit 141) y pipefail lo
# convertiria en un falso fallo.

WORK="${WORK_DIR:-/tmp/k8s-10-01}"
TARGET="$WORK/deployment.yaml"
passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }

# --- Preflight ---
if [ ! -f "$TARGET" ]; then
  cat <<EOF
SKIP: no existe $TARGET.
Para hacer la actividad:
  mkdir -p $WORK
  cp starter/deployment.yaml $TARGET
  # luego edita $TARGET segun las instrucciones del README
EOF
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3 no esta disponible; necesario para parsear YAML."
  exit 0
fi

python3 -c 'import yaml' 2>/dev/null
if [ $? -ne 0 ]; then
  echo "SKIP: python3 PyYAML no esta disponible. Instala con: pip install pyyaml"
  exit 0
fi

# --- Extrae campos de las probes a un formato plano ---
# Formato: una linea por campo "clave=valor".
# Ej: liveness.httpGet.path=/healthz
probe_dump() {
  python3 - "$1" <<'PY'
import sys, yaml
p = sys.argv[1]
with open(p) as f:
    doc = yaml.safe_load(f)
try:
    c = doc["spec"]["template"]["spec"]["containers"][0]
except Exception as e:
    print(f"ERR:cannot-read-container:{e}")
    sys.exit(0)
for pname in ("startupProbe", "readinessProbe", "livenessProbe"):
    p = c.get(pname)
    if not p:
        print(f"{pname}=MISSING")
        continue
    print(f"{pname}=PRESENT")
    hg = p.get("httpGet") or {}
    print(f"{pname}.httpGet.path={hg.get('path','')}")
    print(f"{pname}.periodSeconds={p.get('periodSeconds','')}")
    print(f"{pname}.failureThreshold={p.get('failureThreshold','')}")
    print(f"{pname}.timeoutSeconds={p.get('timeoutSeconds','')}")
PY
}

DUMP="$(probe_dump "$TARGET")"
if echo "$DUMP" | grep -q "^ERR:"; then
  echo "FAIL: no pude leer $TARGET como Deployment YAML:"
  echo "$DUMP"
  exit 1
fi

get() {
  # get <clave>  -> imprime el valor (todo lo que esta despues del primer '=')
  echo "$DUMP" | sed -n "s|^$1=||p" | head -1
}

# --- Checks ---

# livenessProbe presente y NO apunta a '/'
if [ "$(get livenessProbe)" = "PRESENT" ]; then
  ok "livenessProbe presente"
else
  bad "livenessProbe ausente"
fi

lv_path="$(get livenessProbe.httpGet.path)"
case "$lv_path" in
  /)
    bad "livenessProbe.httpGet.path sigue en '/' (anti-patron: toca DB)"
    ;;
  /healthz)
    ok "livenessProbe.httpGet.path = /healthz (barata y local)"
    ;;
  "")
    bad "livenessProbe.httpGet.path vacio"
    ;;
  *)
    bad "livenessProbe.httpGet.path = '$lv_path' (esperado /healthz)"
    ;;
esac

lv_period="$(get livenessProbe.periodSeconds)"
if [ -n "$lv_period" ] && [ "$lv_period" -ge 10 ] 2>/dev/null; then
  ok "livenessProbe.periodSeconds = $lv_period (>= 10, tolerante)"
else
  bad "livenessProbe.periodSeconds = '$lv_period' (debe ser >= 10)"
fi

lv_fail="$(get livenessProbe.failureThreshold)"
if [ -n "$lv_fail" ] && [ "$lv_fail" -ge 3 ] 2>/dev/null; then
  ok "livenessProbe.failureThreshold = $lv_fail (>= 3)"
else
  bad "livenessProbe.failureThreshold = '$lv_fail' (debe ser >= 3)"
fi

# readinessProbe presente y apunta a /readyz
if [ "$(get readinessProbe)" = "PRESENT" ]; then
  ok "readinessProbe presente"
else
  bad "readinessProbe ausente"
fi

rd_path="$(get readinessProbe.httpGet.path)"
if [ "$rd_path" = "/readyz" ]; then
  ok "readinessProbe.httpGet.path = /readyz (verifica dependencias)"
else
  bad "readinessProbe.httpGet.path = '$rd_path' (esperado /readyz)"
fi

rd_period="$(get readinessProbe.periodSeconds)"
if [ -n "$rd_period" ] && [ "$rd_period" -ge 2 ] 2>/dev/null && [ "$rd_period" -le 10 ] 2>/dev/null; then
  ok "readinessProbe.periodSeconds = $rd_period (entre 2 y 10)"
else
  bad "readinessProbe.periodSeconds = '$rd_period' (esperado 2..10)"
fi

# startupProbe presente y apunta a /healthz con ventana >= 60s
if [ "$(get startupProbe)" = "PRESENT" ]; then
  ok "startupProbe presente"
else
  bad "startupProbe ausente (anade uno)"
fi

st_path="$(get startupProbe.httpGet.path)"
if [ "$st_path" = "/healthz" ]; then
  ok "startupProbe.httpGet.path = /healthz"
else
  bad "startupProbe.httpGet.path = '$st_path' (esperado /healthz)"
fi

st_period="$(get startupProbe.periodSeconds)"
st_fail="$(get startupProbe.failureThreshold)"
if [ -n "$st_period" ] && [ -n "$st_fail" ]; then
  window=$(( st_period * st_fail ))
  if [ "$window" -ge 60 ] 2>/dev/null; then
    ok "startupProbe ventana = ${window}s (>= 60s)"
  else
    bad "startupProbe ventana = ${window}s (periodSeconds*failureThreshold debe ser >= 60)"
  fi
else
  bad "startupProbe sin periodSeconds o failureThreshold"
fi

# --- Reporte ---
echo
echo "=== k8s-10-01 report ==="
printf '%b' "$report"
total=$((passed+failed))
echo "---"
echo "Passed: $passed / $total"
if [ "$failed" -eq 0 ]; then
  echo "RESULT: PASS"
  exit 0
else
  echo "RESULT: FAIL ($failed problema(s))"
  exit 1
fi
