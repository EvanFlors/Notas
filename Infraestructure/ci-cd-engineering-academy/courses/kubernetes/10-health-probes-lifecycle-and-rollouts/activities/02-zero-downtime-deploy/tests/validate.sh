#!/usr/bin/env bash
# Validate k8s-10-02-zero-downtime-deploy.
# Lee /tmp/k8s-10-02/deployment.yaml y comprueba la forma final del Deployment
# + PodDisruptionBudget.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Varios checks usan
# `... | grep -q ...` que puede provocar SIGPIPE (exit 141) y pipefail lo
# convertiria en un falso fallo.

WORK="${WORK_DIR:-/tmp/k8s-10-02}"
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
  echo "SKIP: python3 no disponible."
  exit 0
fi
python3 -c 'import yaml' 2>/dev/null
if [ $? -ne 0 ]; then
  echo "SKIP: python3 PyYAML no disponible. pip install pyyaml"
  exit 0
fi

# --- Extrae los campos relevantes de todos los documentos del archivo ---
DUMP="$(python3 - "$TARGET" <<'PY'
import sys, yaml
path = sys.argv[1]
with open(path) as f:
    docs = list(yaml.safe_load_all(f))
dep = None
pdb = None
for d in docs:
    if not isinstance(d, dict):
        continue
    k = d.get("kind")
    if k == "Deployment":
        dep = d
    elif k == "PodDisruptionBudget":
        pdb = d
if dep is None:
    print("ERR:no-deployment")
    sys.exit(0)
spec = dep.get("spec", {}) or {}
print(f"dep.replicas={spec.get('replicas','')}")
strat = (spec.get("strategy") or {})
ru = (strat.get("rollingUpdate") or {})
print(f"strategy.type={strat.get('type','')}")
print(f"strategy.maxSurge={ru.get('maxSurge','')}")
print(f"strategy.maxUnavailable={ru.get('maxUnavailable','')}")
pod = ((spec.get("template") or {}).get("spec") or {})
print(f"pod.terminationGracePeriodSeconds={pod.get('terminationGracePeriodSeconds','')}")
containers = pod.get("containers") or []
if not containers:
    print("ERR:no-containers")
    sys.exit(0)
c = containers[0]
lc = (c.get("lifecycle") or {})
pre = (lc.get("preStop") or {})
pre_ex = (pre.get("exec") or {})
cmd = pre_ex.get("command")
print(f"preStop.exec.command={cmd!r}")
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
if pdb is None:
    print("pdb=MISSING")
else:
    print("pdb=PRESENT")
    pspec = pdb.get("spec") or {}
    print(f"pdb.minAvailable={pspec.get('minAvailable','')}")
    sel = (pspec.get("selector") or {}).get("matchLabels") or {}
    print(f"pdb.selector.app={sel.get('app','')}")
PY
)"

if echo "$DUMP" | grep -q "^ERR:"; then
  echo "FAIL: $DUMP"
  exit 1
fi

get() {
  echo "$DUMP" | sed -n "s|^$1=||p" | head -1
}

# --- Checks ---

# Replicas
reps="$(get dep.replicas)"
if [ "$reps" = "3" ]; then
  ok "replicas = 3"
else
  bad "replicas = '$reps' (esperado 3)"
fi

# Strategy
if [ "$(get strategy.type)" = "RollingUpdate" ]; then
  ok "strategy.type = RollingUpdate"
else
  bad "strategy.type = '$(get strategy.type)' (esperado RollingUpdate)"
fi

ms="$(get strategy.maxSurge)"
if [ "$ms" = "1" ] || [ "$ms" = "25%" ]; then
  ok "strategy.maxSurge = $ms"
elif [ -n "$ms" ]; then
  ok "strategy.maxSurge = $ms (presente)"
else
  bad "strategy.maxSurge no definido"
fi

mu="$(get strategy.maxUnavailable)"
if [ "$mu" = "0" ]; then
  ok "strategy.maxUnavailable = 0 (sin perdida de capacidad)"
else
  bad "strategy.maxUnavailable = '$mu' (esperado 0 para zero-downtime estricto)"
fi

# Grace period
grace="$(get pod.terminationGracePeriodSeconds)"
if [ -n "$grace" ] && [ "$grace" -ge 20 ] 2>/dev/null; then
  ok "terminationGracePeriodSeconds = $grace (>= 20)"
else
  bad "terminationGracePeriodSeconds = '$grace' (esperado >= 20)"
fi

# preStop
preCmd="$(get preStop.exec.command)"
if echo "$preCmd" | grep -q 'sleep'; then
  ok "preStop.exec.command incluye sleep: $preCmd"
else
  bad "preStop.exec.command no incluye sleep (actual: $preCmd)"
fi

# Probes
for p in startupProbe readinessProbe livenessProbe; do
  if [ "$(get "$p")" = "PRESENT" ]; then
    ok "$p presente"
  else
    bad "$p ausente"
  fi
done

# Liveness tolerante
lv_period="$(get livenessProbe.periodSeconds)"
if [ -n "$lv_period" ] && [ "$lv_period" -ge 10 ] 2>/dev/null; then
  ok "livenessProbe.periodSeconds = $lv_period (>= 10)"
else
  bad "livenessProbe.periodSeconds = '$lv_period' (debe ser >= 10)"
fi

lv_fail="$(get livenessProbe.failureThreshold)"
if [ -n "$lv_fail" ] && [ "$lv_fail" -ge 3 ] 2>/dev/null; then
  ok "livenessProbe.failureThreshold = $lv_fail (>= 3)"
else
  bad "livenessProbe.failureThreshold = '$lv_fail' (debe ser >= 3)"
fi

# Readiness reactiva
rd_period="$(get readinessProbe.periodSeconds)"
if [ -n "$rd_period" ] && [ "$rd_period" -ge 1 ] 2>/dev/null && [ "$rd_period" -le 10 ] 2>/dev/null; then
  ok "readinessProbe.periodSeconds = $rd_period (1..10)"
else
  bad "readinessProbe.periodSeconds = '$rd_period' (esperado 1..10)"
fi

# Startup ventana
st_period="$(get startupProbe.periodSeconds)"
st_fail="$(get startupProbe.failureThreshold)"
if [ -n "$st_period" ] && [ -n "$st_fail" ]; then
  window=$(( st_period * st_fail ))
  if [ "$window" -ge 30 ] 2>/dev/null; then
    ok "startupProbe ventana = ${window}s (>= 30s)"
  else
    bad "startupProbe ventana = ${window}s (esperado >= 30s)"
  fi
else
  bad "startupProbe sin periodSeconds/failureThreshold"
fi

# PDB
if [ "$(get pdb)" = "PRESENT" ]; then
  ok "PodDisruptionBudget presente"
else
  bad "PodDisruptionBudget ausente"
fi

pdb_min="$(get pdb.minAvailable)"
if [ "$pdb_min" = "2" ]; then
  ok "pdb.minAvailable = 2"
else
  bad "pdb.minAvailable = '$pdb_min' (esperado 2 con replicas=3)"
fi

pdb_sel="$(get pdb.selector.app)"
if [ "$pdb_sel" = "web-zdd" ]; then
  ok "pdb.selector apunta a app=web-zdd"
else
  bad "pdb.selector.app = '$pdb_sel' (esperado web-zdd)"
fi

# --- Reporte ---
echo
echo "=== k8s-10-02 report ==="
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
