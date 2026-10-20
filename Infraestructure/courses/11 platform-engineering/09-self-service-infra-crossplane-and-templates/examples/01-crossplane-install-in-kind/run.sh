#!/usr/bin/env bash
# Example 01 — install Crossplane + provider-kubernetes in a kind cluster.
# Idempotent. Skips gracefully if docker/kind/kubectl/helm missing.
#
# Note: deliberately NO `set -o pipefail` because some checks use
# `kubectl ... | grep -q ...` and pipefail would spuriously mark the
# SIGPIPE (exit 141) produced when grep exits on first match as a failure.
set -eu

CLUSTER="plat-09-ex01"
NS="crossplane-system"
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="/tmp/plat-09-ex01"
mkdir -p "$WORK"

skip() { echo "SKIP: $1"; exit 0; }

command -v docker  >/dev/null 2>&1 || skip "docker no instalado"
command -v kind    >/dev/null 2>&1 || skip "kind no instalado"
command -v kubectl >/dev/null 2>&1 || skip "kubectl no instalado"
command -v helm    >/dev/null 2>&1 || skip "helm no instalado"
docker info        >/dev/null 2>&1 || skip "docker daemon no responde"

echo "== 1. kind create cluster (si no existe) =="
if ! kind get clusters | grep -qx "$CLUSTER"; then
  kind create cluster --config "$HERE/kind-config.yaml" --name "$CLUSTER"
else
  echo "  cluster $CLUSTER ya existe"
fi
kubectl config use-context "kind-$CLUSTER"

echo "== 2. helm repo add crossplane-stable (si falta) =="
if ! helm repo list 2>/dev/null | awk '{print $1}' | grep -qx "crossplane-stable"; then
  helm repo add crossplane-stable https://charts.crossplane.io/stable
fi
helm repo update >/dev/null

echo "== 3. instala/upgrade chart crossplane en $NS =="
kubectl create ns "$NS" --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install crossplane crossplane-stable/crossplane \
  --namespace "$NS" --wait --timeout 5m

echo "== 4. espera CRDs base de Crossplane =="
for crd in providers.pkg.crossplane.io providerconfigs.pkg.crossplane.io \
           compositeresourcedefinitions.apiextensions.crossplane.io \
           compositions.apiextensions.crossplane.io; do
  kubectl wait --for=condition=Established "crd/$crd" --timeout=120s
done

echo "== 5. instala provider-kubernetes =="
kubectl apply -f "$HERE/provider.yaml"
kubectl wait --for=condition=Healthy provider.pkg.crossplane.io/provider-kubernetes --timeout=180s

echo "== 6. RBAC + ProviderConfig default =="
kubectl apply -f "$HERE/rbac.yaml"
# El SA del provider se nombra provider-kubernetes-* dinamicamente;
# le damos cluster-admin via el nombre esperado del rbac.yaml y tambien
# a cualquier SA del provider via label selector por si cambia la convencion.
kubectl -n "$NS" get sa -l pkg.crossplane.io/provider=provider-kubernetes -o name 2>/dev/null \
  | while read -r sa; do
      name="${sa##*/}"
      kubectl create clusterrolebinding "crossplane-${name}" \
        --clusterrole=cluster-admin --serviceaccount="$NS:$name" \
        --dry-run=client -o yaml | kubectl apply -f - >/dev/null
    done
kubectl apply -f "$HERE/providerconfig.yaml"

echo
echo "== estado =="
kubectl get provider.pkg.crossplane.io
kubectl get providerconfig.kubernetes.crossplane.io

echo
echo "OK: crossplane + provider-kubernetes listos."
echo "Para explorar:  kubectl get all -n $NS"
echo "Para limpiar :  bash $HERE/cleanup.sh"
