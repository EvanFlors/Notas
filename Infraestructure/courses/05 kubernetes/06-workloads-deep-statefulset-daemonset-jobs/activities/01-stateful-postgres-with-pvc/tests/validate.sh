#!/usr/bin/env bash
# Validate k8s-06-01-stateful-postgres-with-pvc.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks pipe
# command output into `grep -q`; if grep matches early, the upstream command
# may receive SIGPIPE (exit 141) and pipefail would mark the whole pipeline
# as failed — a false negative.

WORK="${WORK_DIR:-/tmp/k8s-06-01}"
NS="${NS:-default}"
passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }

# --- Preflight ---
if ! command -v kubectl >/dev/null 2>&1; then
  cat <<EOF
SKIP: 'kubectl' no está instalado.
  https://kubernetes.io/docs/tasks/tools/
EOF
  exit 0
fi

if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "SKIP: no hay cluster accesible (kubectl cluster-info falla)."
  echo "       Levanta uno: kind create cluster --name k8s-06"
  exit 0
fi

echo "== Validando estado del lab en namespace: $NS =="

# --- 1. Service pg existe y es headless ---
if ! kubectl -n "$NS" get svc pg >/dev/null 2>&1; then
  bad "Service 'pg' no existe en $NS"
else
  ok "Service 'pg' existe"
  cip="$(kubectl -n "$NS" get svc pg -o jsonpath='{.spec.clusterIP}' 2>/dev/null)"
  if [ "$cip" = "None" ]; then
    ok "Service 'pg' es headless (clusterIP: None)"
  else
    bad "Service 'pg' NO es headless (clusterIP='$cip', esperado 'None')"
  fi
fi

# --- 2. StatefulSet pg ---
if ! kubectl -n "$NS" get statefulset pg >/dev/null 2>&1; then
  bad "StatefulSet 'pg' no existe"
else
  ok "StatefulSet 'pg' existe"

  svcname="$(kubectl -n "$NS" get statefulset pg -o jsonpath='{.spec.serviceName}' 2>/dev/null)"
  if [ "$svcname" = "pg" ]; then
    ok "StatefulSet.spec.serviceName = pg"
  else
    bad "StatefulSet.spec.serviceName = '$svcname' (esperado 'pg')"
  fi

  ready="$(kubectl -n "$NS" get statefulset pg -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"
  [ "$ready" = "1" ] && ok "StatefulSet readyReplicas = 1" \
                     || bad "StatefulSet readyReplicas = '$ready' (esperado 1)"

  img="$(kubectl -n "$NS" get statefulset pg -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)"
  if echo "$img" | grep -q '^postgres:'; then
    ok "image es postgres (:${img#postgres:})"
  else
    bad "image = '$img' (esperado postgres:...)"
  fi
fi

# --- 3. PVC data-pg-0 Bound ---
pvc_phase="$(kubectl -n "$NS" get pvc data-pg-0 -o jsonpath='{.status.phase}' 2>/dev/null)"
if [ "$pvc_phase" = "Bound" ]; then
  ok "PVC data-pg-0 Bound"
else
  bad "PVC data-pg-0 phase='$pvc_phase' (esperado 'Bound')"
fi

# --- 4. Pod pg-0 Ready ---
pod_ready="$(kubectl -n "$NS" get pod pg-0 -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)"
if [ "$pod_ready" = "True" ]; then
  ok "Pod pg-0 Ready=True"
else
  bad "Pod pg-0 Ready='$pod_ready'"
fi

# --- 5. Dato persistente ---
# La tabla t con la fila 'hola k8s-06' debe existir en la DB.
if kubectl -n "$NS" exec pg-0 -- psql -U postgres -d demo -tAc \
     "SELECT msg FROM t WHERE msg='hola k8s-06';" 2>/dev/null | grep -q 'hola k8s-06'; then
  ok "fila 'hola k8s-06' presente en demo.t"
else
  bad "no encontré la fila 'hola k8s-06' en demo.t (¿faltó Paso 4?)"
fi

# --- 6. ADR escrito ---
adr="$WORK/adr.md"
if [ ! -f "$adr" ]; then
  bad "no existe $adr (Paso 6)"
else
  ok "adr.md existe"
  if grep -qi 'StatefulSet' "$adr"; then
    ok "adr.md menciona StatefulSet"
  else
    bad "adr.md no menciona 'StatefulSet'"
  fi
fi

echo -e "$report"
echo "----"
echo "PASS: $passed   FAIL: $failed"
if [ "$failed" -eq 0 ]; then
  echo "RESULT: PASS"
  exit 0
else
  echo "RESULT: FAIL"
  exit 1
fi
