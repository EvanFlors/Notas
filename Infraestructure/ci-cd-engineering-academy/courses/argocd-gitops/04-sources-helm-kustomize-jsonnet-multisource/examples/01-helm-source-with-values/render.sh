#!/usr/bin/env bash
# Reproduce locally what the Argo CD repo-server would do for example 01.
# No cluster required. Writes to /tmp/argo-ex01-rendered.yaml.
#
# Note: no `set -o pipefail` because some checks pipe into `grep -q` which can
# SIGPIPE legitimate producers and spuriously fail.
set -eu

OUT="/tmp/argo-ex01-rendered.yaml"
WORK="/tmp/argo-ex01-work"

if ! command -v helm >/dev/null 2>&1; then
  echo "SKIP: helm not installed. Install with 'brew install helm' (macOS) or follow helm.sh."
  exit 0
fi

mkdir -p "$WORK"
cd "$WORK"

echo "Pulling bitnami/nginx chart..."
if ! helm pull oci://registry-1.docker.io/bitnamicharts/nginx --version 18.1.14 --untar --untardir . >/dev/null 2>&1; then
  echo "SKIP: unable to pull chart (network/registry restricted). Example remains documentary."
  exit 0
fi

cat > /tmp/argo-ex01-inline.yaml <<'EOF'
service:
  type: ClusterIP
resources:
  requests: {cpu: 50m, memory: 64Mi}
  limits:   {cpu: 200m, memory: 128Mi}
EOF

# Mirrors the merge order Argo CD uses:
#   valueFiles -> inline values -> parameters (as --set)
helm template nginx ./nginx \
  --namespace nginx-example \
  -f ./nginx/values.yaml \
  -f /tmp/argo-ex01-inline.yaml \
  --set replicaCount=2 \
  --set image.tag=1.27.3-debian-12-r0 \
  --set-string podAnnotations.build=20261013 \
  > "$OUT"

echo "OK: rendered manifests written to $OUT"
echo "Sample lines:"
head -n 20 "$OUT"
