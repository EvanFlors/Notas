#!/usr/bin/env bash
# Validate argo-02-02-connect-repo-and-sync.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks use
# patterns like `cmd | grep -q ...`; if grep matches early it can trigger
# SIGPIPE on the upstream command (exit 141), and pipefail would promote
# that to a failure of the whole pipeline — a false negative.

WORK="${WORK_DIR:-/tmp/argo-02-02}"
NS_ARGO="argocd"
NS_APP="default"
APP="guestbook"
EXPECTED_REPO="https://github.com/argoproj/argocd-example-apps.git"
EXPECTED_PATH="guestbook"
EXPECTED_SERVER="https://kubernetes.default.svc"
passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }

# --- Preflight: tools available? ---
missing=""
command -v kubectl >/dev/null 2>&1 || missing+=" kubectl"
command -v docker  >/dev/null 2>&1 || missing+=" docker"
command -v kind    >/dev/null 2>&1 || missing+=" kind"
# argocd CLI es opcional para la validación (usamos kubectl sobre el CR),
# pero la actividad la requiere; avisamos como SKIP si falta.
if ! command -v argocd >/dev/null 2>&1; then
  missing+=" argocd"
fi

if [ -n "$missing" ]; then
  cat <<EOF
SKIP: faltan herramientas:$missing
Instala:
  - macOS:   brew install argocd kind kubectl
  - Linux:   https://argo-cd.readthedocs.io/en/stable/cli_installation/
             https://kind.sigs.k8s.io/docs/user/quick-start/#installation
             https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
  - Windows: choco install argocd-cli kind kubernetes-cli
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
  echo "Completa primero argo-02-01-bootstrap-argocd."
  exit 0
fi

if ! kubectl get namespace "$NS_ARGO" >/dev/null 2>&1; then
  echo "SKIP: namespace '$NS_ARGO' no existe. Completa primero argo-02-01-bootstrap-argocd."
  exit 0
fi

echo "== Validando Application '$APP' =="

# --- 1. Application CR existe ---
if ! kubectl -n "$NS_ARGO" get application "$APP" >/dev/null 2>&1; then
  bad "Application '$APP' no existe en namespace '$NS_ARGO'"
  echo -e "$report"
  echo "----"
  echo "PASS: $passed   FAIL: $failed"
  echo "RESULT: FAIL"
  exit 1
else
  ok "Application '$APP' existe"
fi

# --- 2. spec.source.repoURL ---
repo="$(kubectl -n "$NS_ARGO" get application "$APP" -o jsonpath='{.spec.source.repoURL}' 2>/dev/null)"
if [ "$repo" = "$EXPECTED_REPO" ]; then
  ok "source.repoURL = $EXPECTED_REPO"
else
  bad "source.repoURL = '$repo' (esperado '$EXPECTED_REPO')"
fi

# --- 3. spec.source.path ---
spath="$(kubectl -n "$NS_ARGO" get application "$APP" -o jsonpath='{.spec.source.path}' 2>/dev/null)"
if [ "$spath" = "$EXPECTED_PATH" ]; then
  ok "source.path = $EXPECTED_PATH"
else
  bad "source.path = '$spath' (esperado '$EXPECTED_PATH')"
fi

# --- 4. spec.destination.server ---
dserver="$(kubectl -n "$NS_ARGO" get application "$APP" -o jsonpath='{.spec.destination.server}' 2>/dev/null)"
if [ "$dserver" = "$EXPECTED_SERVER" ]; then
  ok "destination.server = $EXPECTED_SERVER"
else
  bad "destination.server = '$dserver' (esperado '$EXPECTED_SERVER')"
fi

# --- 5. spec.destination.namespace ---
dns="$(kubectl -n "$NS_ARGO" get application "$APP" -o jsonpath='{.spec.destination.namespace}' 2>/dev/null)"
if [ "$dns" = "$NS_APP" ]; then
  ok "destination.namespace = $NS_APP"
else
  bad "destination.namespace = '$dns' (esperado '$NS_APP')"
fi

# --- 6. sync status Synced ---
sync="$(kubectl -n "$NS_ARGO" get application "$APP" -o jsonpath='{.status.sync.status}' 2>/dev/null)"
if [ "$sync" = "Synced" ]; then
  ok "status.sync.status = Synced"
else
  bad "status.sync.status = '$sync' (esperado Synced; corre 'argocd app sync $APP')"
fi

# --- 7. health status Healthy ---
health="$(kubectl -n "$NS_ARGO" get application "$APP" -o jsonpath='{.status.health.status}' 2>/dev/null)"
if [ "$health" = "Healthy" ]; then
  ok "status.health.status = Healthy"
else
  bad "status.health.status = '$health' (esperado Healthy)"
fi

# --- 8. Deployment guestbook-ui en 'default' Ready ---
if ! kubectl -n "$NS_APP" get deploy guestbook-ui >/dev/null 2>&1; then
  bad "deployment guestbook-ui no existe en '$NS_APP'"
else
  ready="$(kubectl -n "$NS_APP" get deploy guestbook-ui -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"
  if [ "${ready:-0}" -ge 1 ]; then
    ok "deployment guestbook-ui Ready ($ready)"
  else
    bad "deployment guestbook-ui sin réplicas Ready"
  fi
fi

# --- 9. Service guestbook-ui en 'default' ---
if kubectl -n "$NS_APP" get svc guestbook-ui >/dev/null 2>&1; then
  ok "service guestbook-ui presente en '$NS_APP'"
else
  bad "service guestbook-ui no existe en '$NS_APP'"
fi

# --- 10. Snapshot ---
snap="$WORK/snapshot.md"
if [ ! -f "$snap" ]; then
  bad "no existe $snap"
else
  ok "snapshot.md existe"
  for section in "application" "resources" "kube-view" "sync-vs-health"; do
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
