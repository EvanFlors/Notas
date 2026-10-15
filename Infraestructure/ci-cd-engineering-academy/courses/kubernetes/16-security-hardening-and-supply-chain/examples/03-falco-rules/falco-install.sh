#!/usr/bin/env bash
# Install Falco DaemonSet via Helm, modern-bpf driver, loading our custom rule.
set -euo pipefail

if ! command -v helm >/dev/null 2>&1; then
  echo "ERROR: helm no instalado" >&2
  exit 1
fi

helm repo add falcosecurity https://falcosecurity.github.io/charts >/dev/null 2>&1 || true
helm repo update >/dev/null

if helm status falco -n falco >/dev/null 2>&1; then
  echo "Falco ya instalado; actualizando valores"
  CMD=upgrade
else
  CMD=install
fi

helm "$CMD" falco falcosecurity/falco \
  --namespace falco --create-namespace \
  --set driver.kind=modern-bpf \
  --set tty=true \
  --set falcoctl.artifact.install.enabled=true \
  --set falcoctl.artifact.follow.enabled=true \
  --values shell_in_container_custom.yaml \
  --wait --timeout 5m \
  || { echo "WARN: Falco rollout fallo. Puede ser por kernel sin BTF o entorno restringido. Documenta y continua." >&2; exit 2; }

kubectl -n falco rollout status ds/falco --timeout=120s
echo "Falco listo."
