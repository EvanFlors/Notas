#!/usr/bin/env bash
# Render cluster-spoke.yaml by provisioning the argocd-manager SA on the spoke,
# extracting a bearer token, discovering the API-server address reachable from the hub
# (kind-on-docker), and templating a declarative cluster Secret for the hub to apply.
#
# NOTE: no `set -o pipefail` because some pipelines use `grep -q` and may receive SIGPIPE.
set -eu

SPOKE_CTX="${SPOKE_CONTEXT:-kind-argo-spoke}"
HUB_CTX="${HUB_CONTEXT:-kind-argo-hub}"
NS="${NS:-argocd-manager}"
SA="${SA:-argocd-manager}"
OUT="${OUT:-cluster-spoke.yaml}"
TMPL="${TMPL:-cluster-spoke.yaml.tmpl}"

# 1) Create SA + binding on the spoke (idempotent)
kubectl --context "$SPOKE_CTX" get ns "$NS" >/dev/null 2>&1 \
  || kubectl --context "$SPOKE_CTX" create ns "$NS"
kubectl --context "$SPOKE_CTX" -n "$NS" get sa "$SA" >/dev/null 2>&1 \
  || kubectl --context "$SPOKE_CTX" -n "$NS" create sa "$SA"
kubectl --context "$SPOKE_CTX" get clusterrolebinding "$SA" >/dev/null 2>&1 \
  || kubectl --context "$SPOKE_CTX" create clusterrolebinding "$SA" \
       --clusterrole=cluster-admin \
       --serviceaccount="$NS:$SA"

# 2) Mint a token (K8s ≥ 1.24 — SA tokens are no longer auto-provisioned)
TOKEN="$(kubectl --context "$SPOKE_CTX" -n "$NS" create token "$SA" --duration=24h)"

# 3) CA bundle, base64
CA_B64="$(kubectl --context "$SPOKE_CTX" config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')"
if [ -z "$CA_B64" ]; then
  CA_PATH="$(kubectl --context "$SPOKE_CTX" config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority}')"
  CA_B64="$(base64 < "$CA_PATH" | tr -d '\n')"
fi

# 4) Discover spoke API-server endpoint reachable from the hub Pod network.
#    With kind, both clusters share the host docker network; the spoke control-plane
#    container exposes 6443 on its container IP (not the host-forwarded port).
SPOKE_NAME="${SPOKE_CTX#kind-}"
SPOKE_CONTAINER="${SPOKE_NAME}-control-plane"
SPOKE_IP="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$SPOKE_CONTAINER")"
if [ -z "$SPOKE_IP" ]; then
  echo "ERROR: could not resolve IP for $SPOKE_CONTAINER" >&2
  exit 1
fi
SERVER_URL="https://${SPOKE_IP}:6443"

# 5) Render template
sed \
  -e "s|__SERVER__|${SERVER_URL}|g" \
  -e "s|__TOKEN__|${TOKEN}|g" \
  -e "s|__CA_B64__|${CA_B64}|g" \
  "$TMPL" > "$OUT"

echo "Rendered $OUT (apply with: kubectl --context $HUB_CTX apply -f $OUT)"
