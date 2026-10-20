#!/usr/bin/env bash
# Reproduces what the Argo CD repo-server does for example 02:
#   kustomize build with the Application-level overrides applied in-process.
# No cluster required. Writes /tmp/argo-ex02-rendered.yaml.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="/tmp/argo-ex02-rendered.yaml"

# Prefer standalone kustomize, fall back to `kubectl kustomize` which ships
# with kubectl >= 1.14 and is good enough for most of what Argo CD does here.
if command -v kustomize >/dev/null 2>&1; then
  KBUILD="kustomize build"
elif command -v kubectl >/dev/null 2>&1; then
  KBUILD="kubectl kustomize"
else
  echo "SKIP: neither kustomize nor kubectl installed."
  exit 0
fi

WORK="$(mktemp -d /tmp/argo-ex02-work.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# Mirror the overlay but add the overrides Argo CD would inject.
cp -r "$HERE"/base "$WORK"/base
mkdir -p "$WORK/overlay"
cat > "$WORK/overlay/kustomization.yaml" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: api-dev
namePrefix: dev-
commonLabels:
  app.kubernetes.io/env: dev
commonAnnotations:
  owner: platform
images:
  - name: ghcr.io/acme/api
    newName: ghcr.io/acme/api
    newTag: "1.4.2"
replicas:
  - name: api
    count: 2
resources:
  - ../base
EOF

$KBUILD "$WORK/overlay" > "$OUT"
echo "OK: rendered manifests at $OUT"
echo "First deployment image line:"
grep 'image: ' "$OUT" | head -n 1
