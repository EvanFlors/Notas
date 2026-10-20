#!/usr/bin/env bash
# Configura Vault para que ESO (SA external-secrets/external-secrets) pueda
# autenticarse y leer kv/payments/stripe. Siembra el valor inicial.
#
# Note: we deliberately do NOT enable `set -o pipefail` because some checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
set -eu

CLUSTER=sec-13-capstone
CTX="kind-$CLUSTER"

for tool in vault kubectl docker kind; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "SKIP: $tool not installed."
    exit 0
  fi
done

if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "SKIP: cluster '$CLUSTER' does not exist. Run ./02-create-cluster.sh first."
  exit 0
fi
if ! docker ps --format '{{.Names}}' | grep -qx 'sec-13-vault'; then
  echo "SKIP: sec-13-vault container not running. Run ./01-start-vault.sh first."
  exit 0
fi

export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=root

echo "== Bootstrapping Vault (DEV MODE, token=root) =="

# 1) kv-v2 engine
if ! vault secrets list -format=json 2>/dev/null | grep -q '"kv/"'; then
  vault secrets enable -path=kv kv-v2
fi

# 2) seed secret
vault kv put kv/payments/stripe api_key=sk_test_INIT >/dev/null
echo "Seeded kv/payments/stripe (api_key=sk_test_INIT — DEV ONLY)."

# 3) namespace payments
kubectl --context "$CTX" create namespace payments --dry-run=client -o yaml | kubectl --context "$CTX" apply -f -

# 4) k8s auth setup — ESO's SA will be reviewed via TokenReview
kubectl --context "$CTX" create serviceaccount vault-auth -n default --dry-run=client -o yaml | kubectl --context "$CTX" apply -f -
kubectl --context "$CTX" create clusterrolebinding vault-auth-tokenreview \
  --clusterrole=system:auth-delegator \
  --serviceaccount=default:vault-auth --dry-run=client -o yaml | kubectl --context "$CTX" apply -f -

cat <<'EOF' | kubectl --context "$CTX" apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: vault-auth-token
  namespace: default
  annotations:
    kubernetes.io/service-account.name: vault-auth
type: kubernetes.io/service-account-token
EOF
sleep 3

SA_JWT="$(kubectl --context "$CTX" -n default get secret vault-auth-token -o jsonpath='{.data.token}' | base64 -d)"
SA_CA="$(kubectl --context "$CTX" -n default get secret vault-auth-token -o jsonpath='{.data.ca\.crt}' | base64 -d)"

# API server IP, as visible from Vault container (both share the 'kind' docker network)
K8S_HOST="https://$(docker inspect -f '{{.NetworkSettings.Networks.kind.IPAddress}}' "${CLUSTER}-control-plane"):6443"

if ! vault auth list -format=json 2>/dev/null | grep -q '"kubernetes/"'; then
  vault auth enable kubernetes
fi

vault write auth/kubernetes/config \
  kubernetes_host="$K8S_HOST" \
  kubernetes_ca_cert="$SA_CA" \
  token_reviewer_jwt="$SA_JWT" \
  disable_iss_validation=true >/dev/null

# 5) policy + role for ESO
vault policy write payments-read - <<'EOF'
path "kv/data/payments/*" {
  capabilities = ["read"]
}
EOF

vault write auth/kubernetes/role/eso-payments \
  bound_service_account_names=external-secrets \
  bound_service_account_namespaces=external-secrets \
  policies=payments-read \
  ttl=1h >/dev/null

# 6) Print the Vault URL the manifests must use (Vault's IP on the 'kind' network)
VAULT_IP="$(docker inspect -f '{{.NetworkSettings.Networks.kind.IPAddress}}' sec-13-vault)"
cat <<EOF

== Vault bootstrap complete ==
Vault address (from host):     http://127.0.0.1:8200   (token=root, DEV ONLY)
Vault address (from cluster):  http://${VAULT_IP}:8200

👉 Use this URL in starter/manifests/secret-store.yaml for spec.provider.vault.server:
    http://${VAULT_IP}:8200

👉 role to use: eso-payments
EOF
