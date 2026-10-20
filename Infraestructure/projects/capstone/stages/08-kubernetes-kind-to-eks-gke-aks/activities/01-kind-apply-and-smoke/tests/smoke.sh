#!/usr/bin/env bash
# Smoke test: valida que la base y los 3 overlays son renderizables
# por kubectl sin requerir cluster. Idempotente: puede correrse N veces.
#
# NOTE: deliberately NO `set -o pipefail`. Varios checks usan
# `cmd | grep -q ...` y pipefail reportaria SIGPIPE (141) espurio
# cuando grep sale al primer match.
set -eu

STAGE_DIR="${STAGE_DIR:-$(cd "$(dirname "$0")/../../.." && pwd)}"
cd "$STAGE_DIR"

echo "== smoke: dry-run cliente de los overlays =="
for env in dev staging prod; do
  if command -v kubectl >/dev/null 2>&1; then
    # `kubectl kustomize` corre offline (no requiere apiserver).
    kubectl kustomize "k8s/overlays/$env" >/dev/null
    echo "  OK  overlay=$env (kubectl kustomize)"
  elif command -v kustomize >/dev/null 2>&1; then
    kustomize build "k8s/overlays/$env" >/dev/null
    echo "  OK  overlay=$env (kustomize build)"
  else
    echo "  SKIP overlay=$env (ni kubectl ni kustomize instalados)"
  fi
done

echo "smoke OK"
