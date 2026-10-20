#!/usr/bin/env bash
# plat-09-01 — Setup cluster kind + Crossplane + aplica starter del alumno.
# Idempotente. SKIP si docker/kind/kubectl/helm faltan.
#
# Note: deliberately NO `set -o pipefail` because some checks use
# `kubectl ... | grep -q ...` and pipefail would spuriously mark the
# SIGPIPE (exit 141) produced when grep exits on first match as a failure.
set -eu

CLUSTER="plat-09-01"
XP_NS="crossplane-system"
TEAM_NS="team-student"
HERE="$(cd "$(dirname "$0")" && pwd)"
ACT="$(cd "$HERE/.." && pwd)"
WORK="/tmp/plat-09-01"
mkdir -p "$WORK"

MANIFESTS_DIR="${MANIFESTS_DIR:-$ACT/starter}"
echo "Usando manifiestos de: $MANIFESTS_DIR"

skip() { echo "SKIP: $1"; exit 0; }

command -v docker  >/dev/null 2>&1 || skip "docker no instalado"
command -v kind    >/dev/null 2>&1 || skip "kind no instalado"
command -v kubectl >/dev/null 2>&1 || skip "kubectl no instalado"
command -v helm    >/dev/null 2>&1 || skip "helm no instalado"
docker info        >/dev/null 2>&1 || skip "docker daemon no responde"

if grep -l 'REPLACE_ME' "$MANIFESTS_DIR"/*.yaml >/dev/null 2>&1; then
  echo "ERROR: hay 'REPLACE_ME' pendientes en $MANIFESTS_DIR:"
  grep -l 'REPLACE_ME' "$MANIFESTS_DIR"/*.yaml
  echo "Completa los TODO antes de ejecutar setup."
  exit 1
fi

echo "== 1. kind create cluster (si no existe) =="
if ! kind get clusters | grep -qx "$CLUSTER"; then
  cat >"$WORK/kind-config.yaml" <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: $CLUSTER
nodes:
  - role: control-plane
EOF
  kind create cluster --config "$WORK/kind-config.yaml" --name "$CLUSTER"
fi
kubectl config use-context "kind-$CLUSTER"

echo "== 2. helm repo + install crossplane =="
if ! helm repo list 2>/dev/null | awk '{print $1}' | grep -qx crossplane-stable; then
  helm repo add crossplane-stable https://charts.crossplane.io/stable
fi
helm repo update >/dev/null
kubectl create ns "$XP_NS" --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install crossplane crossplane-stable/crossplane \
  --namespace "$XP_NS" --wait --timeout 5m

for crd in providers.pkg.crossplane.io providerconfigs.pkg.crossplane.io \
           compositeresourcedefinitions.apiextensions.crossplane.io \
           compositions.apiextensions.crossplane.io; do
  kubectl wait --for=condition=Established "crd/$crd" --timeout=120s
done

echo "== 3. provider-kubernetes =="
cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-kubernetes
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v0.14.0
EOF
kubectl wait --for=condition=Healthy provider.pkg.crossplane.io/provider-kubernetes --timeout=180s

# RBAC: cluster-admin a todas las SAs del provider
kubectl -n "$XP_NS" get sa -l pkg.crossplane.io/provider=provider-kubernetes -o name 2>/dev/null \
  | while read -r sa; do
      name="${sa##*/}"
      kubectl create clusterrolebinding "crossplane-${name}" \
        --clusterrole=cluster-admin --serviceaccount="$XP_NS:$name" \
        --dry-run=client -o yaml | kubectl apply -f - >/dev/null
    done

cat <<EOF | kubectl apply -f -
apiVersion: kubernetes.crossplane.io/v1alpha1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: InjectedIdentity
EOF

echo "== 4. apply XRD + Composition =="
kubectl apply -f "$MANIFESTS_DIR/xrd.yaml"
kubectl wait --for=condition=Established xrd/xnamespaceproducts.platform.io --timeout=60s
kubectl apply -f "$MANIFESTS_DIR/composition.yaml"

echo "== 5. apply Claim =="
kubectl create ns "$TEAM_NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "$MANIFESTS_DIR/claim.yaml"

echo "setup OK. Espera unos segundos antes de validar:"
echo "  bash $HERE/validate.sh"
