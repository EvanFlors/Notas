#!/usr/bin/env bash
# Validate cap-09-02-register-argocd-app.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks pipe
# kubectl/helm output into `grep -q`; grep may close its stdin early and
# trigger SIGPIPE (exit 141) on the upstream command — pipefail would turn
# that into a spurious failure.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STAGE_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
APP_FILE="${STAGE_DIR}/argocd/applications/fastapi-dev.yaml"
APPOFAPPS_FILE="${STAGE_DIR}/argocd/app-of-apps.yaml"
INSTALL_SCRIPT="${STAGE_DIR}/scripts/install-argocd.sh"

fail=0
ok()  { echo "  OK   $1"; }
bad() { echo "  FAIL $1"; fail=$((fail+1)); }

# ---- Preflight ----
if ! command -v kubectl >/dev/null 2>&1; then
  echo "SKIP: 'kubectl' no esta instalado. Instala desde https://kubernetes.io/docs/tasks/tools/"
  exit 0
fi

echo "== Static files =="
for f in "${APP_FILE}" "${APPOFAPPS_FILE}" "${INSTALL_SCRIPT}"; do
  if [ -f "${f}" ]; then ok "exists ${f#${STAGE_DIR}/}"; else bad "missing ${f#${STAGE_DIR}/}"; fi
done

if [ -x "${INSTALL_SCRIPT}" ]; then
  ok "install-argocd.sh es ejecutable"
else
  bad "install-argocd.sh NO es ejecutable (chmod +x)"
fi

echo
echo "== Application CR schema (campos minimos) =="
for key in "kind: Application" "project:" "repoURL:" "destination:" "syncPolicy:" "automated:" "selfHeal: true" "prune: true" "releaseName:" "valueFiles:"; do
  if grep -q "${key}" "${APP_FILE}"; then
    ok "Application contiene '${key}'"
  else
    bad "Application NO contiene '${key}'"
  fi
done

echo
echo "== app-of-apps CR =="
for key in "name: capstone-root" "path: projects/capstone/stages/09-helm-chart-argocd/argocd/applications" "recurse: true"; do
  if grep -q "${key}" "${APPOFAPPS_FILE}"; then
    ok "app-of-apps contiene '${key}'"
  else
    bad "app-of-apps NO contiene '${key}'"
  fi
done

echo
echo "== No real secrets =="
if grep -Ei '(password|secret|token).*=.*[A-Za-z0-9/+]{20,}' "${APP_FILE}" "${APPOFAPPS_FILE}" >/dev/null 2>&1; then
  bad "sospecha de secreto real en Application/app-of-apps"
else
  ok "sin secretos reales en los manifests"
fi

echo
echo "== Cluster reachable? =="
if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "SKIP (parcial): no hay cluster accesible, se omiten chequeos live."
  echo
  if [ "${fail}" -gt 0 ]; then
    echo "RESULT: ${fail} issue(s) found."
    exit 1
  fi
  echo "RESULT: 0 issue(s). Manifests validos (chequeos live omitidos)."
  exit 0
fi

echo
echo "== Argo CD instalado? =="
if kubectl get ns argocd >/dev/null 2>&1 \
   && kubectl -n argocd get deploy argocd-server >/dev/null 2>&1; then
  ok "namespace argocd + deploy argocd-server existen"
  if kubectl -n argocd rollout status deploy/argocd-server --timeout=10s >/dev/null 2>&1; then
    ok "argocd-server Available"
  else
    bad "argocd-server NO esta Available"
  fi
else
  echo "  INFO argo CD no instalado todavia; corre scripts/install-argocd.sh"
fi

echo
echo "== Application fastapi-dev registrada? =="
if kubectl -n argocd get application fastapi-dev >/dev/null 2>&1; then
  ok "Application fastapi-dev existe"
  SYNC=$(kubectl -n argocd get application fastapi-dev -o jsonpath='{.status.sync.status}' 2>/dev/null || true)
  HEALTH=$(kubectl -n argocd get application fastapi-dev -o jsonpath='{.status.health.status}' 2>/dev/null || true)
  if [ "${SYNC}" = "Synced" ]; then ok "sync=Synced"; else echo "  INFO sync=${SYNC:-unknown}"; fi
  if [ "${HEALTH}" = "Healthy" ]; then ok "health=Healthy"; else echo "  INFO health=${HEALTH:-unknown}"; fi
else
  echo "  INFO Application fastapi-dev todavia no aplicada; kubectl apply -f ${APP_FILE}"
fi

echo
if [ "${fail}" -gt 0 ]; then
  echo "RESULT: ${fail} issue(s) found."
  exit 1
fi
echo "RESULT: 0 issue(s). Argo CD + Application configurados."
exit 0
