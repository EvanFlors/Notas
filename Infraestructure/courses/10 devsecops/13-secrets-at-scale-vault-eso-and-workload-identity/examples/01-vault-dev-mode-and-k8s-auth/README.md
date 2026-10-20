# Example 01 — Vault en modo dev + autenticación Kubernetes

> Objetivo: levantar un Vault *in-memory* en Docker y configurar el método de autenticación **kubernetes** para que un ServiceAccount del cluster `kind` reciba un token Vault.

## 1. Qué vas a construir

```
   Docker host (tu laptop)
   ─────────────────────────────────────────────
      ┌──────────────────────┐    http://127.0.0.1:8200
      │  vault:1.15 (dev)    │◄─────── vault CLI ◄──── tú
      │  token=root (dev!)   │
      │  storage: inmemory   │
      └──────────┬───────────┘
                 │  (TokenReview via API server)
                 │
      ┌──────────▼───────────┐
      │  kind cluster        │
      │  sec-13-ex01         │
      │   ns: payments       │
      │   sa: payments-app   │
      └──────────────────────┘
```

**Advertencia:** el token `root` **se publica aquí a propósito**. Vale únicamente para el laboratorio local, en memoria, 1 contenedor que mañana ya no existe. Nunca uses esta receta en un entorno conectado a algo real.

## 2. Pre-requisitos

Herramientas: `docker`, `kind`, `kubectl`, `vault` CLI.

```bash
docker --version && kind --version && kubectl version --client && vault version
```

Si falta alguna, los pasos siguientes fallarán.

## 3. Paso a paso

### 3.1 Prepara un scratch dir y arranca Vault dev

```bash
export WORK=/tmp/sec-13-ex01
mkdir -p "$WORK" && cd "$WORK"

docker rm -f sec-13-vault 2>/dev/null || true
docker run -d --name sec-13-vault \
  --cap-add=IPC_LOCK \
  -p 8200:8200 \
  -e VAULT_DEV_ROOT_TOKEN_ID=root \
  -e VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200 \
  hashicorp/vault:1.15

# Espera 2 s a que Vault esté listo
sleep 2
```

Verifica desde fuera:

```bash
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=root
vault status
# Initialized=true, Sealed=false (dev mode salta estos pasos)
```

### 3.2 Crea el cluster kind y descubre el API server

```bash
kind create cluster --name sec-13-ex01

# IP del API server tal como la ven los contenedores Docker
export K8S_HOST="https://$(docker inspect -f '{{.NetworkSettings.IPAddress}}' sec-13-ex01-control-plane):6443"
echo "$K8S_HOST"
```

Vault **también** es un contenedor Docker; va a llamar al API server del cluster `kind` por su IP de red Docker, no por `127.0.0.1`.

Conecta Vault a esa misma red Docker para que la IP sea alcanzable:

```bash
docker network connect kind sec-13-vault || true
```

### 3.3 Crea el SA que será "la identidad" del Pod y el token-review SA

```bash
kubectl create namespace payments
kubectl -n payments create serviceaccount payments-app

# ServiceAccount que Vault usará para hacer TokenReview contra el API server
kubectl create serviceaccount vault-auth -n default
kubectl create clusterrolebinding vault-auth-tokenreview \
  --clusterrole=system:auth-delegator \
  --serviceaccount=default:vault-auth

# Genera un token de larga vida para que Vault lo use (versión simplificada)
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: vault-auth-token
  namespace: default
  annotations:
    kubernetes.io/service-account.name: vault-auth
type: kubernetes.io/service-account-token
EOF

# Espera a que K8s rellene el token
sleep 2

export SA_JWT="$(kubectl -n default get secret vault-auth-token -o jsonpath='{.data.token}' | base64 -d)"
export SA_CA="$(kubectl -n default get secret vault-auth-token -o jsonpath='{.data.ca\.crt}' | base64 -d)"
```

### 3.4 Habilita el método `kubernetes` en Vault

```bash
vault auth enable kubernetes

vault write auth/kubernetes/config \
  kubernetes_host="$K8S_HOST" \
  kubernetes_ca_cert="$SA_CA" \
  token_reviewer_jwt="$SA_JWT" \
  disable_iss_validation=true
```

### 3.5 Crea una policy y un role que la enlace al SA `payments-app`

```bash
# Secret estático que la app podrá leer
vault secrets enable -path=kv kv-v2
vault kv put kv/payments/stripe api_key=sk_test_abc123

# Policy que permite leer solo ese path
vault policy write payments-read - <<'EOF'
path "kv/data/payments/*" {
  capabilities = ["read"]
}
EOF

# Role: cualquier Pod con SA=payments-app en ns=payments recibe esta policy
vault write auth/kubernetes/role/payments \
  bound_service_account_names=payments-app \
  bound_service_account_namespaces=payments \
  policies=payments-read \
  ttl=1h
```

### 3.6 Prueba desde dentro del cluster

Lanza un Pod efímero con `curl` + `jq` que use el SA `payments-app`:

```bash
kubectl -n payments run tester --rm -it --restart=Never \
  --serviceaccount=payments-app \
  --image=alpine:3.19 \
  -- /bin/sh -lc '
    apk add --no-cache curl jq >/dev/null
    SA_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
    VAULT_URL=http://sec-13-vault:8200
    VAULT_TOKEN=$(curl -s --request POST \
      --data "{\"jwt\": \"$SA_TOKEN\", \"role\": \"payments\"}" \
      $VAULT_URL/v1/auth/kubernetes/login | jq -r .auth.client_token)
    echo "VAULT_TOKEN efímero obtenido: ${VAULT_TOKEN:0:12}..."
    curl -s -H "X-Vault-Token: $VAULT_TOKEN" \
      $VAULT_URL/v1/kv/data/payments/stripe | jq .data.data
  '
```

Resultado esperado: el Pod imprime `api_key = sk_test_abc123` **sin que ese valor haya tocado ningún `Secret` K8s, env var ni Git**.

## 4. Lo que acabas de demostrar

- Un **ServiceAccount token** proyectado por el cluster es suficiente para que Vault emita un token con policies específicas, vía `TokenReview`.
- La policy se enlaza a `(SA name, namespace)`. Un Pod del namespace `prod` con otro SA **no** recibirá ese acceso.
- El `api_key` existe en Vault y se materializa **solo dentro del Pod** cuando lo pide. No hay `Secret` K8s intermedio en este ejemplo (eso se añade en el `example-02` con ESO).

## 5. Limpieza

```bash
kind delete cluster --name sec-13-ex01
docker rm -f sec-13-vault
rm -rf /tmp/sec-13-ex01
```

## 6. Para profundizar

- Cambia el `bound_service_account_namespaces` a `default` y verifica que el `tester` deja de poder autenticarse.
- Añade un segundo path `kv/data/billing/*` y una policy `billing-read`, enlazada a un role distinto; comprueba que `payments-app` **no** puede leerlo (`403 permission denied`).
- Activa el audit device (`vault audit enable file file_path=/vault/logs/audit.log`) y revisa qué queda registrado al leer el secreto.
