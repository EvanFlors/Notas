#!/usr/bin/env bash
# Validate k8s-09-02-protect-rollout-with-pdb.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks use
# patterns like `kubectl ... | grep -q`, where grep exits early on first match
# and SIGPIPEs the upstream (exit 141). pipefail would mark those as failures.
#
# This validator performs a REAL `kubectl drain` against the cluster — only
# run it against a disposable lab cluster (recommended: kind-k8s09-act2).

NS="${NS:-k8s-09-02}"
DEPLOY="${DEPLOY:-critical}"
PDB_NAME="${PDB_NAME:-critical-pdb}"
passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }

finalize() {
  if [ -n "${CORDONED_NODE:-}" ]; then
    kubectl uncordon "$CORDONED_NODE" >/dev/null 2>&1 || true
  fi
  printf "\n%b" "$report"
  printf "\nPassed: %d  Failed: %d\n" "$passed" "$failed"
  if [ "$failed" -eq 0 ]; then
    echo "RESULT: PASS"
    exit 0
  else
    echo "RESULT: FAIL"
    exit 1
  fi
}
trap finalize EXIT

# ---- Preconditions ----
if ! command -v kubectl >/dev/null 2>&1; then
  echo "SKIP: 'kubectl' no está instalado."
  trap - EXIT
  exit 0
fi

if ! kubectl version >/dev/null 2>&1; then
  echo "SKIP: no hay cluster accesible. Crea uno con:"
  echo "  kind create cluster --name k8s09-act2 --config starter/kind-3-workers.yaml"
  trap - EXIT
  exit 0
fi

# Advertencia si NO es un cluster kind: evitar drenar algo real.
CTX="$(kubectl config current-context 2>/dev/null)"
case "$CTX" in
  kind-*) : ;;
  *)
    echo "SKIP: contexto actual '$CTX' no parece kind-*. Para evitar daños,"
    echo "      este validador solo corre contra contextos 'kind-*'."
    echo "      Cambia con: kubectl config use-context kind-k8s09-act2"
    trap - EXIT
    exit 0
    ;;
esac

if ! kubectl get ns "$NS" >/dev/null 2>&1; then
  bad "namespace '$NS' no existe"
  exit 0
fi

# ---- 1. Deployment + réplicas ----
if ! kubectl -n "$NS" get deploy "$DEPLOY" >/dev/null 2>&1; then
  bad "Deployment '$DEPLOY' no existe en '$NS'"
  exit 0
fi
ok "Deployment '$DEPLOY' existe"

avail="$(kubectl -n "$NS" get deploy "$DEPLOY" -o jsonpath='{.status.availableReplicas}' 2>/dev/null)"
[ -z "$avail" ] && avail=0
if [ "$avail" -eq 3 ]; then
  ok "3 réplicas disponibles"
else
  bad "esperaba 3 réplicas disponibles, hay $avail"
  exit 0
fi

# ---- 2. podAntiAffinity required por hostname ----
tk="$(kubectl -n "$NS" get deploy "$DEPLOY" \
  -o jsonpath='{.spec.template.spec.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].topologyKey}' 2>/dev/null)"
if [ "$tk" = "kubernetes.io/hostname" ]; then
  ok "podAntiAffinity required con topologyKey=kubernetes.io/hostname"
else
  bad "podAntiAffinity required ausente o con topologyKey='$tk' (esperado kubernetes.io/hostname)"
fi

sel_label="$(kubectl -n "$NS" get deploy "$DEPLOY" \
  -o jsonpath='{.spec.template.spec.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].labelSelector.matchLabels.app}' 2>/dev/null)"
if [ "$sel_label" = "critical" ]; then
  ok "anti-affinity selector app=critical"
else
  bad "anti-affinity selector app='$sel_label' (esperado 'critical')"
fi

# ---- 3. Pods en 3 nodos distintos ----
nodes="$(kubectl -n "$NS" get pod -l app="$DEPLOY" -o jsonpath='{.items[*].spec.nodeName}' 2>/dev/null)"
distinct="$(echo "$nodes" | tr ' ' '\n' | sort -u | grep -c . || true)"
if [ "$distinct" -eq 3 ]; then
  ok "las 3 réplicas están en 3 nodos distintos"
else
  bad "las réplicas están en $distinct nodo(s) distintos (esperado 3)"
fi

# ---- 4. PDB existe y minAvailable == 2 ----
if ! kubectl -n "$NS" get pdb "$PDB_NAME" >/dev/null 2>&1; then
  bad "PDB '$PDB_NAME' no existe"
  exit 0
fi
ok "PDB '$PDB_NAME' existe"

minA="$(kubectl -n "$NS" get pdb "$PDB_NAME" -o jsonpath='{.spec.minAvailable}' 2>/dev/null)"
if [ "$minA" = "2" ]; then
  ok "PDB.spec.minAvailable == 2"
else
  bad "PDB.spec.minAvailable='$minA' (esperado 2)"
fi

pdb_sel="$(kubectl -n "$NS" get pdb "$PDB_NAME" -o jsonpath='{.spec.selector.matchLabels.app}' 2>/dev/null)"
if [ "$pdb_sel" = "critical" ]; then
  ok "PDB selector app=critical"
else
  bad "PDB selector app='$pdb_sel' (esperado 'critical')"
fi

# ---- 5. disruptionsAllowed == 1 (steady state) ----
# Espera un ciclo breve a que el controller recalcule.
for _ in 1 2 3 4 5; do
  da="$(kubectl -n "$NS" get pdb "$PDB_NAME" -o jsonpath='{.status.disruptionsAllowed}' 2>/dev/null)"
  [ "$da" = "1" ] && break
  sleep 2
done
if [ "$da" = "1" ]; then
  ok "PDB.status.disruptionsAllowed == 1"
else
  bad "PDB.status.disruptionsAllowed='$da' (esperado 1)"
fi

# ---- 6. drain real y observación ----
NODE="$(kubectl -n "$NS" get pod -l app="$DEPLOY" -o jsonpath='{.items[0].spec.nodeName}' 2>/dev/null)"
if [ -z "$NODE" ]; then
  bad "no pude elegir un nodo para drenar"
  exit 0
fi

echo "== Drenando $NODE y observando availableReplicas =="
CORDONED_NODE="$NODE"
kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --timeout=90s >/dev/null 2>&1 &
DRAIN_PID=$!

min_avail=99
# Muestreamos availableReplicas cada 0.5 s mientras drain corre.
while kill -0 "$DRAIN_PID" 2>/dev/null; do
  cur="$(kubectl -n "$NS" get deploy "$DEPLOY" -o jsonpath='{.status.availableReplicas}' 2>/dev/null)"
  [ -z "$cur" ] && cur=0
  if [ "$cur" -lt "$min_avail" ]; then
    min_avail="$cur"
  fi
  sleep 0.5
done
wait "$DRAIN_PID"
drain_rc=$?

cur="$(kubectl -n "$NS" get deploy "$DEPLOY" -o jsonpath='{.status.availableReplicas}' 2>/dev/null)"
[ -z "$cur" ] && cur=0
if [ "$cur" -lt "$min_avail" ]; then
  min_avail="$cur"
fi

if [ "$drain_rc" -eq 0 ]; then
  ok "kubectl drain completó (rc=0)"
else
  bad "kubectl drain terminó con rc=$drain_rc"
fi

if [ "$min_avail" -ge 2 ]; then
  ok "availableReplicas nunca cayó por debajo de 2 (mínimo observado: $min_avail)"
else
  bad "availableReplicas cayó a $min_avail durante el drain (PDB no se respetó o el polling fue muy lento)"
fi

# finalize() se encarga de uncordon.
