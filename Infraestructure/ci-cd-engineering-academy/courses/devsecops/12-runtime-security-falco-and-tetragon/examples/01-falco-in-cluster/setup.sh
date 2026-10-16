#!/usr/bin/env bash
# Idempotent setup for the Falco-in-kind demo.
# Degrades gracefully when kind/kubectl/helm are missing or the kernel driver fails.
#
# Note: no `set -o pipefail` on purpose. The checks below pipe into grep,
# which can emit SIGPIPE (exit 141) when the match is found early.
set -eu

CLUSTER="${CLUSTER:-sec-12-demo}"

need() { command -v "$1" >/dev/null 2>&1; }

if ! need kind; then
  echo "SKIP: 'kind' no instalado. Instala https://kind.sigs.k8s.io/ y vuelve."
  exit 0
fi
if ! need kubectl; then
  echo "SKIP: 'kubectl' no instalado."
  exit 0
fi
if ! need helm; then
  echo "SKIP: 'helm' no instalado."
  exit 0
fi

if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "Creating kind cluster: $CLUSTER"
  kind create cluster --name "$CLUSTER"
else
  echo "Reusing existing kind cluster: $CLUSTER"
fi

helm repo add falcosecurity https://falcosecurity.github.io/charts >/dev/null 2>&1 || true
helm repo update >/dev/null

helm upgrade --install falco falcosecurity/falco \
  --namespace falco --create-namespace \
  --set driver.kind=modern_ebpf \
  --set tty=true \
  --set falcosidekick.enabled=false

echo
echo "Esperando a que el DaemonSet este listo (max 120s)..."
if ! kubectl -n falco rollout status ds/falco --timeout=120s; then
  echo
  echo "WARN: Falco DaemonSet no quedo listo. Probablemente el kernel"
  echo "      del VM de Docker no soporta modern_ebpf. Opciones:"
  echo "      1) Reintenta con driver.kind=ebpf (legacy)."
  echo "      2) Usa sample-events.json para la actividad 01 en modo walkthrough."
  exit 0
fi

echo
echo "Falco listo. Logs:"
kubectl -n falco logs ds/falco --tail=20 || true
