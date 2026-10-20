#!/usr/bin/env bash
# Install Kyverno via Helm (idempotent).
set -euo pipefail

if ! command -v helm >/dev/null 2>&1; then
  echo "ERROR: helm no instalado" >&2
  exit 1
fi

helm repo add kyverno https://kyverno.github.io/kyverno/ >/dev/null 2>&1 || true
helm repo update >/dev/null

if helm status kyverno -n kyverno >/dev/null 2>&1; then
  echo "Kyverno ya instalado"
else
  echo "Instalando Kyverno..."
  helm install kyverno kyverno/kyverno \
    --namespace kyverno --create-namespace \
    --wait --timeout 5m
fi

kubectl -n kyverno rollout status deploy/kyverno-admission-controller --timeout=120s
echo "Kyverno listo."
