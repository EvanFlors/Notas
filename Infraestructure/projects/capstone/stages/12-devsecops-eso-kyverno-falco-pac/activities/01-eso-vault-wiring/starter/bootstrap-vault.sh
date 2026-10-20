#!/usr/bin/env bash
# Dev-mode Vault bootstrap for cap-12-01. NO reproducir en produccion.
# Levanta Vault en modo -dev dentro de la red docker de kind y crea el
# role eso-capstone + un KV con valores dummy.
set -eu

CONTAINER="${CONTAINER:-capstone-vault-dev}"
NET="${NET:-kind}"
TOKEN="${TOKEN:-dummy_root_token_change_me}"

docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
docker run -d --name "$CONTAINER" --network "$NET" \
  -e VAULT_DEV_ROOT_TOKEN_ID="$TOKEN" \
  -p 8200:8200 \
  hashicorp/vault:1.17

echo "Vault corriendo. Para sembrar los secretos:"
cat <<'EOF'
  export VAULT_ADDR=http://127.0.0.1:8200
  export VAULT_TOKEN=dummy_root_token_change_me
  vault secrets enable -path=kv kv-v2 || true
  vault kv put kv/capstone/app \
    database_url='postgres://capstone:dummy_pw_change_me@db:5432/capstone' \
    jwt_signing_key='dummy_jwt_signing_key_change_me'
  vault auth enable kubernetes || true
  vault write auth/kubernetes/role/eso-capstone \
    bound_service_account_names=external-secrets \
    bound_service_account_namespaces=external-secrets \
    policies=default ttl=1h
EOF
