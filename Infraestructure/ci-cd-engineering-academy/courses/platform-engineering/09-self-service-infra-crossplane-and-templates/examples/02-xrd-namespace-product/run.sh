#!/usr/bin/env bash
# Example 02 — apply XRD + Composition + Claim for NamespaceProduct.
# Requires example 01 run first (crossplane + provider-kubernetes installed).
#
# Note: deliberately NO `set -o pipefail` — see example 01 run.sh for rationale.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="/tmp/plat-09-ex02"
mkdir -p "$WORK"

skip() { echo "SKIP: $1"; exit 0; }
command -v kubectl >/dev/null 2>&1 || skip "kubectl no instalado"
kubectl version --request-timeout=5s >/dev/null 2>&1 || skip "kubectl no alcanza apiserver"
kubectl get crd compositeresourcedefinitions.apiextensions.crossplane.io >/dev/null 2>&1 \
  || skip "Crossplane no instalado. Ejecuta examples/01-crossplane-install-in-kind/run.sh"

echo "== 1. apply XRD =="
kubectl apply -f "$HERE/xrd.yaml"
kubectl wait --for=condition=Established \
  xrd/xnamespaceproducts.platform.io --timeout=60s

echo "== 2. apply Composition =="
kubectl apply -f "$HERE/composition.yaml"

echo "== 3. ensure team-foo namespace exists (donde vive el claim) =="
kubectl create ns team-foo --dry-run=client -o yaml | kubectl apply -f -

echo "== 4. apply Claim =="
kubectl apply -f "$HERE/claim.yaml"

echo "== 5. espera reconcile (hasta 90s) =="
ok=0
for i in $(seq 1 18); do
  if kubectl get ns demo-ns >/dev/null 2>&1 \
     && kubectl -n demo-ns get resourcequota demo-ns-quota >/dev/null 2>&1 \
     && kubectl -n demo-ns get networkpolicy demo-ns-deny-all >/dev/null 2>&1; then
    ok=1; break
  fi
  sleep 5
done

echo
echo "== estado del claim =="
kubectl -n team-foo get namespaceproductclaim demo -o wide || true
echo
echo "== composite + MRs =="
kubectl get xnamespaceproduct -o wide || true
kubectl get object | grep -E '^(demo|demo-ns)' || true

if [ "$ok" -ne 1 ]; then
  echo "FAIL: no se materializaron todos los recursos esperados en 90s"
  echo "  Debug:"
  echo "    kubectl -n team-foo describe namespaceproductclaim demo"
  echo "    kubectl describe xnamespaceproduct"
  echo "    kubectl -n crossplane-system logs -l pkg.crossplane.io/provider=provider-kubernetes"
  exit 1
fi

echo
echo "OK: NamespaceProduct materializado:"
kubectl get ns demo-ns --show-labels
kubectl -n demo-ns get resourcequota demo-ns-quota -o jsonpath='{.spec.hard}' ; echo
kubectl -n demo-ns get networkpolicy demo-ns-deny-all -o jsonpath='{.spec.policyTypes}'; echo
