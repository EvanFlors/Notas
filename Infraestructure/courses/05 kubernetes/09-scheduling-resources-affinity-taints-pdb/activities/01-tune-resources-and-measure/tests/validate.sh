#!/usr/bin/env bash
# Validate k8s-09-01-tune-resources-and-measure.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks use
# patterns like `kubectl ... | grep -q`, where grep exits early on first
# match and SIGPIPEs the upstream command (exit 141). pipefail would promote
# that to a failure even though the check succeeded.

NS="${NS:-k8s-09-01}"
DEPLOY="${DEPLOY:-api}"
passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }

# ---- Preconditions ----
if ! command -v kubectl >/dev/null 2>&1; then
  cat <<EOF
SKIP: 'kubectl' no está instalado.
  Instala con tu gestor de paquetes y verifica: kubectl version --client
EOF
  exit 0
fi

if ! kubectl version >/dev/null 2>&1; then
  cat <<EOF
SKIP: no hay cluster accesible (kubectl version falló).
  Crea uno con: kind create cluster --name k8s09-act1
EOF
  exit 0
fi

if ! kubectl get ns "$NS" >/dev/null 2>&1; then
  bad "namespace '$NS' no existe (créalo con: kubectl create ns $NS)"
  printf "\n%b\nPassed: %d  Failed: %d\n" "$report" "$passed" "$failed"
  exit 1
fi

# ---- 1. El Deployment existe y tiene 2 réplicas disponibles ----
if ! kubectl -n "$NS" get deploy "$DEPLOY" >/dev/null 2>&1; then
  bad "Deployment '$DEPLOY' no existe en namespace '$NS'"
  printf "\n%b\nPassed: %d  Failed: %d\n" "$report" "$passed" "$failed"
  exit 1
fi
ok "Deployment '$DEPLOY' existe"

avail="$(kubectl -n "$NS" get deploy "$DEPLOY" -o jsonpath='{.status.availableReplicas}' 2>/dev/null)"
[ -z "$avail" ] && avail=0
if [ "$avail" -ge 2 ]; then
  ok "al menos 2 réplicas disponibles ($avail)"
else
  bad "menos de 2 réplicas disponibles ($avail)"
fi

# ---- 2. Lee requests/limits del primer container del template ----
# cpu/memory en requests y limits
rc="$(kubectl -n "$NS" get deploy "$DEPLOY" -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)"
rm_="$(kubectl -n "$NS" get deploy "$DEPLOY" -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null)"
lc="$(kubectl -n "$NS" get deploy "$DEPLOY" -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}' 2>/dev/null)"
lm="$(kubectl -n "$NS" get deploy "$DEPLOY" -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null)"

if [ -z "$rc" ] || [ -z "$rm_" ] || [ -z "$lc" ] || [ -z "$lm" ]; then
  bad "faltan requests/limits (requests.cpu='$rc' requests.memory='$rm_' limits.cpu='$lc' limits.memory='$lm')"
  printf "\n%b\nPassed: %d  Failed: %d\n" "$report" "$passed" "$failed"
  exit 1
fi
ok "requests y limits declarados"

# ---- 3. requests == limits (Guaranteed en el nivel declarativo) ----
if [ "$rc" = "$lc" ]; then
  ok "requests.cpu == limits.cpu ($rc)"
else
  bad "requests.cpu ($rc) != limits.cpu ($lc)"
fi
if [ "$rm_" = "$lm" ]; then
  ok "requests.memory == limits.memory ($rm_)"
else
  bad "requests.memory ($rm_) != limits.memory ($lm)"
fi

# ---- 4. Rango de valores ----
# CPU en milicores: aceptar "N" o "Nm". Convertimos a enteros de milicores.
cpu_to_millis() {
  local v="$1"
  case "$v" in
    *m) echo "${v%m}" ;;
    "") echo "0" ;;
    *) # "1", "0.5", etc.
       # bash no hace floats; aproximamos *1000 vía awk.
       awk -v x="$v" 'BEGIN{printf "%d", x*1000}' ;;
  esac
}
cpu_m="$(cpu_to_millis "$rc")"
if [ "$cpu_m" -ge 50 ] && [ "$cpu_m" -le 500 ]; then
  ok "requests.cpu en rango [50m, 500m]: ${cpu_m}m"
else
  bad "requests.cpu fuera de rango [50m, 500m]: ${cpu_m}m"
fi

# Memoria: aceptar Mi o Gi. Convertimos a MiB enteros.
mem_to_mib() {
  local v="$1"
  case "$v" in
    *Mi) echo "${v%Mi}" ;;
    *Gi) local n="${v%Gi}"; echo $((n*1024)) ;;
    *M)  local n="${v%M}"; awk -v n="$n" 'BEGIN{printf "%d", n*1000000/1048576}' ;;
    *G)  local n="${v%G}"; awk -v n="$n" 'BEGIN{printf "%d", n*1000000000/1048576}' ;;
    "") echo "0" ;;
    *)  echo "0" ;;
  esac
}
mem_m="$(mem_to_mib "$rm_")"
if [ "$mem_m" -ge 32 ] && [ "$mem_m" -le 256 ]; then
  ok "requests.memory en rango [32Mi, 256Mi]: ${mem_m}Mi"
else
  bad "requests.memory fuera de rango [32Mi, 256Mi]: ${mem_m}Mi"
fi

# ---- 5. status.qosClass del Pod == Guaranteed ----
pod="$(kubectl -n "$NS" get pod -l app="$DEPLOY" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
if [ -z "$pod" ]; then
  bad "no se encontraron Pods con label app=$DEPLOY"
else
  qos="$(kubectl -n "$NS" get pod "$pod" -o jsonpath='{.status.qosClass}' 2>/dev/null)"
  if [ "$qos" = "Guaranteed" ]; then
    ok "pod '$pod' tiene QoS Guaranteed"
  else
    bad "pod '$pod' tiene QoS '$qos' (esperado Guaranteed)"
  fi
fi

# ---- Reporte final ----
printf "\n%b" "$report"
printf "\nPassed: %d  Failed: %d\n" "$passed" "$failed"
if [ "$failed" -eq 0 ]; then
  echo "RESULT: PASS"
  exit 0
else
  echo "RESULT: FAIL"
  exit 1
fi
