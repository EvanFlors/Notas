#!/usr/bin/env bash
# Solution de referencia para helm-02-02-rollback-after-bad-upgrade.
# Deliberadamente SIN `set -o pipefail`: algunos checks usan `cmd | grep -q`
# y pipefail promovería un SIGPIPE del upstream a fallo del pipeline.
set -eu

WORK="/tmp/helm-02-02"
RELEASE="broken-app"
NS="rollback-lab"
CHART_REPO_NAME="ingress-nginx"
CHART_REPO_URL="https://kubernetes.github.io/ingress-nginx"
CHART="ingress-nginx/ingress-nginx"
CHART_VERSION="4.11.3"

mkdir -p "$WORK"

# 0. Preflight.
for bin in helm kubectl; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "Falta '$bin' en el PATH." >&2
    exit 1
  fi
done

# 1. Repo (idempotente).
helm repo add "$CHART_REPO_NAME" "$CHART_REPO_URL" 2>/dev/null || true
helm repo update "$CHART_REPO_NAME" >/dev/null

# 2. Revisión 1: install sano.
helm upgrade --install "$RELEASE" "$CHART" \
  --namespace "$NS" --create-namespace \
  --version "$CHART_VERSION" \
  --set controller.service.type=ClusterIP \
  --set controller.replicaCount=1 \
  --wait --timeout 5m

# 3. Revisión 2: upgrade "roto" (receta B: 0 réplicas).
#    Nota: NO usamos --atomic — queremos que el estado "malo" PERSISTA para
#    que el estudiante vea el problema y haga el rollback a mano.
helm upgrade --install "$RELEASE" "$CHART" \
  --namespace "$NS" \
  --version "$CHART_VERSION" \
  --set controller.service.type=ClusterIP \
  --set controller.replicaCount=0 \
  --wait --timeout 5m

# 4. Confirmar el "problema" (0 réplicas) y guardarlo para el ojo humano.
kubectl -n "$NS" get deploy -o custom-columns=NAME:.metadata.name,DESIRED:.spec.replicas

# 5. Rollback a la revisión 1 (genera la revisión 3).
helm rollback "$RELEASE" 1 -n "$NS" --wait --timeout 5m

# 6. Última revisión numérica.
LAST="$(helm history "$RELEASE" -n "$NS" -o json \
        | python3 -c 'import sys,json; print(max(r["revision"] for r in json.load(sys.stdin)))')"

# 7. Snapshot.
{
  echo "# snapshot helm-02-02"
  echo
  echo "## history"
  helm history "$RELEASE" -n "$NS"
  echo
  echo "## values-rev1"
  helm get values "$RELEASE" -n "$NS" --revision 1
  echo
  echo "## values-last"
  helm get values "$RELEASE" -n "$NS" --revision "$LAST"
  echo
  echo "## release-secrets"
  kubectl get secret -n "$NS" -l owner=helm
} > "$WORK/snapshot.md"

echo
echo "Solution aplicada. Correr validator:"
echo "  bash courses/helm/02-consume-charts-install-upgrade-rollback/activities/02-rollback-after-bad-upgrade/tests/validate.sh"
