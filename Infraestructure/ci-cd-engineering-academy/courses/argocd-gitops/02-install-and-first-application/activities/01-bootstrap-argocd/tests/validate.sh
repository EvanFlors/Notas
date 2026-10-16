#!/usr/bin/env bash
# Validate argo-02-01-bootstrap-argocd.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks use
# patterns like `cmd | grep -q ...`; if grep matches early it can trigger
# SIGPIPE on the upstream command (exit 141), and pipefail would promote
# that to a failure of the whole pipeline — a false negative.

WORK="${WORK_DIR:-/tmp/argo-02-01}"
NS="argocd"
passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }

# --- Preflight: tools available? ---
missing=""
command -v kind    >/dev/null 2>&1 || missing+=" kind"
command -v kubectl >/dev/null 2>&1 || missing+=" kubectl"
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

if ! kubectl get nodes >/dev/null 2>&1; then
  echo "SKIP: no hay cluster alcanzable con el current-context."
  echo "Crea uno con 'kind create cluster --name argo-02' y vuelve a correr el validador."
  exit 0
fi

echo "== Validando bootstrap de Argo CD en el namespace: $NS =="

# --- 1. Namespace existe ---
if kubectl get namespace "$NS" >/dev/null 2>&1; then
  ok "namespace '$NS' existe"
else
  bad "namespace '$NS' no existe"
  echo -e "$report"
  echo "----"
  echo "PASS: $passed   FAIL: $failed"
  echo "RESULT: FAIL"
  exit 1
fi

# --- 2. CRDs ---
for crd in applications.argoproj.io applicationsets.argoproj.io appprojects.argoproj.io; do
  if kubectl get crd "$crd" >/dev/null 2>&1; then
    ok "CRD $crd presente"
  else
    bad "CRD $crd ausente"
  fi
done

# --- 3. Deployments esperados ---
EXPECTED_DEPLOYS=(
  argocd-server
  argocd-repo-server
  argocd-redis
  argocd-applicationset-controller
  argocd-notifications-controller
  argocd-dex-server
)
for d in "${EXPECTED_DEPLOYS[@]}"; do
  if ! kubectl -n "$NS" get deploy "$d" >/dev/null 2>&1; then
    bad "deployment $d no existe"
    continue
  fi
  avail="$(kubectl -n "$NS" get deploy "$d" -o jsonpath='{.status.availableReplicas}' 2>/dev/null)"
  if [ "${avail:-0}" -ge 1 ]; then
    ok "deployment $d Available ($avail réplica(s))"
  else
    bad "deployment $d sin réplicas Available"
  fi
done

# --- 4. StatefulSet application-controller ---
if ! kubectl -n "$NS" get sts argocd-application-controller >/dev/null 2>&1; then
  bad "statefulset argocd-application-controller no existe"
else
  ready="$(kubectl -n "$NS" get sts argocd-application-controller -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"
  if [ "${ready:-0}" -ge 1 ]; then
    ok "statefulset argocd-application-controller Ready ($ready/)"
  else
    bad "statefulset argocd-application-controller sin réplicas Ready"
  fi
fi

# --- 5. Secret initial-admin ---
if kubectl -n "$NS" get secret argocd-initial-admin-secret >/dev/null 2>&1; then
  ok "secret argocd-initial-admin-secret presente"
else
  bad "secret argocd-initial-admin-secret no existe (¿se usó una instalación distinta a install.yaml?)"
fi

# --- 6. Service argocd-server ---
if kubectl -n "$NS" get svc argocd-server >/dev/null 2>&1; then
  ok "service argocd-server presente"
else
  bad "service argocd-server no existe"
fi

# --- 7. Snapshot ---
snap="$WORK/snapshot.md"
if [ ! -f "$snap" ]; then
  bad "no existe $snap"
else
  ok "snapshot.md existe"
  for section in "deployments" "statefulsets" "crds" "admin-password"; do
    if grep -q "^## $section" "$snap"; then
      ok "snapshot contiene sección '## $section'"
    else
      bad "snapshot no contiene sección '## $section'"
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
