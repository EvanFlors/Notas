#!/usr/bin/env bash
# Validate k8s-02-01-create-local-cluster.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks use
# patterns like `cmd | grep -q ...`; if grep matches early it can trigger
# SIGPIPE on the upstream command (exit 141), and pipefail would promote
# that to a failure of the whole pipeline — a false negative.

WORK="${WORK_DIR:-/tmp/k8s-02-01}"
CLUSTER="academy"
NS="k8s-02-lab"
passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }

# --- Preflight: tools available? ---
missing=""
command -v kubectl >/dev/null 2>&1 || missing+=" kubectl"
command -v kind    >/dev/null 2>&1 || missing+=" kind"
command -v docker  >/dev/null 2>&1 || missing+=" docker"

if [ -n "$missing" ]; then
  cat <<EOF
SKIP: faltan herramientas:$missing
Instala:
  - macOS:   brew install kind kubectl
  - Linux:   https://kind.sigs.k8s.io/docs/user/quick-start/#installation
             https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
  - Windows: choco install kind kubernetes-cli
Y asegura que Docker Desktop / colima / dockerd esté corriendo.
EOF
  exit 0
fi

if ! docker info >/dev/null 2>&1; then
  echo "SKIP: el daemon de Docker no responde. Arranca Docker Desktop / colima / 'sudo systemctl start docker'."
  exit 0
fi

echo "== Validando estado del lab en: $WORK =="

# --- 1. Cluster kind existe ---
if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  bad "cluster kind '$CLUSTER' no existe (kind get clusters)"
  echo -e "$report"
  echo "----"
  echo "PASS: $passed   FAIL: $failed"
  echo "RESULT: FAIL"
  exit 1
else
  ok "cluster kind '$CLUSTER' existe"
fi

# --- 2. current-context es kind-academy ---
ctx="$(kubectl config current-context 2>/dev/null)"
if [ "$ctx" = "kind-$CLUSTER" ]; then
  ok "current-context = kind-$CLUSTER"
else
  bad "current-context = '$ctx' (esperado 'kind-$CLUSTER')"
fi

# --- 3. Nodo Ready ---
# Con --no-headers hay una línea por nodo; buscamos "Ready" en ella.
nodes_ready="$(kubectl --context "kind-$CLUSTER" get nodes --no-headers 2>/dev/null | awk '{print $2}' | grep -c '^Ready$')"
if [ "${nodes_ready:-0}" -ge 1 ]; then
  ok "al menos 1 nodo Ready"
else
  bad "ningún nodo Ready en el cluster"
fi

# --- 4. Namespace del contexto es k8s-02-lab ---
ctx_ns="$(kubectl config view --minify -o jsonpath='{.contexts[0].context.namespace}' 2>/dev/null)"
if [ "$ctx_ns" = "$NS" ]; then
  ok "namespace del contexto = $NS"
else
  bad "namespace del contexto = '$ctx_ns' (esperado '$NS')"
fi

# --- 5. Namespace existe en el cluster ---
if kubectl --context "kind-$CLUSTER" get namespace "$NS" >/dev/null 2>&1; then
  ok "namespace '$NS' existe en el cluster"
else
  bad "namespace '$NS' no existe"
fi

# --- 6. ConfigMap lab-config ---
if ! kubectl --context "kind-$CLUSTER" -n "$NS" get configmap lab-config >/dev/null 2>&1; then
  bad "configmap 'lab-config' no existe en namespace '$NS'"
else
  ok "configmap 'lab-config' existe"

  greeting="$(kubectl --context "kind-$CLUSTER" -n "$NS" get cm lab-config -o jsonpath='{.data.greeting}' 2>/dev/null)"
  if [ "$greeting" = "hola k8s" ]; then
    ok "lab-config.data.greeting = 'hola k8s'"
  else
    bad "lab-config.data.greeting = '$greeting' (esperado 'hola k8s')"
  fi

  module="$(kubectl --context "kind-$CLUSTER" -n "$NS" get cm lab-config -o jsonpath='{.data.module}' 2>/dev/null)"
  if [ "$module" = "k8s-02" ]; then
    ok "lab-config.data.module = 'k8s-02'"
  else
    bad "lab-config.data.module = '$module' (esperado 'k8s-02')"
  fi

  owner="$(kubectl --context "kind-$CLUSTER" -n "$NS" get cm lab-config -o jsonpath='{.metadata.labels.owner}' 2>/dev/null)"
  if [ "$owner" = "academy" ]; then
    ok "lab-config.metadata.labels.owner = 'academy'"
  else
    bad "lab-config.metadata.labels.owner = '$owner' (esperado 'academy')"
  fi
fi

# --- 7. Snapshot ---
snap="$WORK/snapshot.md"
if [ ! -f "$snap" ]; then
  bad "no existe $snap"
else
  ok "snapshot.md existe"
  for section in "current-context" "namespace del contexto" "nodo" "ConfigMap"; do
    if grep -q "$section" "$snap"; then
      ok "snapshot menciona '$section'"
    else
      bad "snapshot no menciona '$section'"
    fi
  done
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
