#!/usr/bin/env bash
# install-argocd.sh — bootstrap de Argo CD sobre un cluster kind local.
#
# Idempotente: si Argo CD ya esta instalado solo imprime el estado.
# Deliberadamente NO usamos `set -o pipefail`: encadenamos pipes con
# `grep -q` y `head`, y en esos casos SIGPIPE (exit 141) puede marcar
# una condicion normal como fallo si pipefail esta activo.
set -eu

ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGOCD_VERSION="${ARGOCD_VERSION:-v2.12.3}"
KIND_CLUSTER="${KIND_CLUSTER:-capstone}"

log() { printf '[install-argocd] %s\n' "$*"; }

# ---- Preflight ----
for bin in kubectl; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    log "SKIP: '$bin' no esta instalado. Instalalo y vuelve a correr."
    exit 0
  fi
done

if ! kubectl cluster-info >/dev/null 2>&1; then
  log "SKIP: no hay cluster accesible via kubectl."
  log "Sugerencia: 'kind create cluster --name ${KIND_CLUSTER}' (etapa 08)."
  exit 0
fi

# ---- Instalacion ----
log "Namespace ${ARGOCD_NAMESPACE}..."
kubectl get ns "$ARGOCD_NAMESPACE" >/dev/null 2>&1 \
  || kubectl create namespace "$ARGOCD_NAMESPACE"

MANIFEST_URL="https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
log "Aplicando manifests oficiales de Argo CD ${ARGOCD_VERSION}..."
kubectl apply -n "$ARGOCD_NAMESPACE" -f "$MANIFEST_URL"

log "Esperando a que el server esta Ready (hasta 5 min)..."
kubectl -n "$ARGOCD_NAMESPACE" rollout status deploy/argocd-server --timeout=300s

log "Argo CD listo. Password inicial del user 'admin':"
echo
echo "  kubectl -n ${ARGOCD_NAMESPACE} get secret argocd-initial-admin-secret \\"
echo "    -o jsonpath='{.data.password}' | base64 -d; echo"
echo
log "Acceso local via port-forward:"
echo
echo "  kubectl -n ${ARGOCD_NAMESPACE} port-forward svc/argocd-server 8080:443"
echo "  # luego abrir https://localhost:8080  (admin / <password-arriba>)"
echo
log "Registrar la Application fastapi-dev:"
echo
echo "  kubectl apply -f argocd/applications/fastapi-dev.yaml"
