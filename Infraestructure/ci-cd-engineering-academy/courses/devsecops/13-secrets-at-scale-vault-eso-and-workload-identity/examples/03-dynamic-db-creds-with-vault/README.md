# Example 03 — Dynamic database credentials con Vault

> Objetivo: ver cómo Vault **emite** credenciales PostgreSQL con TTL corto y las **revoca** cuando expiran. Rotación como propiedad del TTL, no como evento operativo.

## 1. Qué vas a construir

```
  Docker host
  ──────────────────────────────────────────
                                          ┌──────────────────────┐
   ┌──────────────────────┐  config DB    │ postgres:16          │
   │  vault:1.15 (dev)    │◄──────────────│ user=vault_root      │
   │  token=root (dev!)   │  (puerto 5432)│ pw=vault_root_pw     │
   │                      │               │ db=payments          │
   │  engine: database/   │──┐            └──────────────────────┘
   └──────────────────────┘  │  CREATE ROLE "v-token-..." WITH LOGIN
                             │  PASSWORD '...' VALID UNTIL '...';
                             ▼
                       psql → tu laptop  (pide creds; vive 2 min; expira)
```

**Advertencia:** `vault_root_pw` existe aquí **a propósito** y **nunca** sale del laboratorio. Es la raíz que Vault usa para gestionar roles; en producción se rota con `vault write database/rotate-root/<db>` tras configurar, y nadie la vuelve a conocer.

## 2. Pre-requisitos

Herramientas: `docker`, `vault` CLI, `psql` (opcional, para probar las creds).

## 3. Paso a paso

### 3.1 Scratch dir y red Docker compartida

```bash
export WORK=/tmp/sec-13-ex03
mkdir -p "$WORK" && cd "$WORK"

docker network create sec-13-ex03-net 2>/dev/null || true
```

### 3.2 Arranca PostgreSQL

```bash
docker rm -f sec-13-pg 2>/dev/null || true
docker run -d --name sec-13-pg --network sec-13-ex03-net \
  -e POSTGRES_USER=vault_root \
  -e POSTGRES_PASSWORD=vault_root_pw \
  -e POSTGRES_DB=payments \
  -p 15432:5432 \
  postgres:16

sleep 5
docker exec sec-13-pg pg_isready -U vault_root -d payments
```

### 3.3 Arranca Vault y configúralo

```bash
docker rm -f sec-13-vault 2>/dev/null || true
docker run -d --name sec-13-vault --network sec-13-ex03-net \
  --cap-add=IPC_LOCK \
  -p 8200:8200 \
  -e VAULT_DEV_ROOT_TOKEN_ID=root \
  -e VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200 \
  hashicorp/vault:1.15

sleep 2
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=root
vault status
```

### 3.4 Habilita `database/` y conecta Vault a Postgres

```bash
vault secrets enable database

vault write database/config/payments-db \
  plugin_name=postgresql-database-plugin \
  allowed_roles="payments-app" \
  connection_url="postgresql://{{username}}:{{password}}@sec-13-pg:5432/payments?sslmode=disable" \
  username="vault_root" \
  password="vault_root_pw"
```

### 3.5 Define el role `payments-app`

```bash
vault write database/roles/payments-app \
  db_name=payments-db \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
                       GRANT CONNECT ON DATABASE payments TO \"{{name}}\"; \
                       GRANT USAGE ON SCHEMA public TO \"{{name}}\"; \
                       GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  revocation_statements="REVOKE ALL PRIVILEGES ON DATABASE payments FROM \"{{name}}\"; \
                         REVOKE ALL ON SCHEMA public FROM \"{{name}}\"; \
                         DROP ROLE IF EXISTS \"{{name}}\";" \
  default_ttl="2m" max_ttl="10m"
```

### 3.6 Pide una credencial efímera

```bash
vault read database/creds/payments-app
# Key                Value
# ---                -----
# lease_id           database/creds/payments-app/XXXX
# lease_duration     2m
# username           v-token-payments-app-abc...
# password           <aleatoria>
```

Guárdala en vars para probarla:

```bash
CREDS_JSON=$(vault read -format=json database/creds/payments-app)
DB_USER=$(echo "$CREDS_JSON" | jq -r .data.username)
DB_PASS=$(echo "$CREDS_JSON" | jq -r .data.password)
LEASE_ID=$(echo "$CREDS_JSON" | jq -r .lease_id)
echo "user=$DB_USER  lease=$LEASE_ID"
```

### 3.7 Verifica que el rol existe y conecta

```bash
docker exec sec-13-pg psql -U vault_root -d payments -c "\du" | grep "$DB_USER"
# Deberías ver el role con "VALID UNTIL" en el futuro próximo.

PGPASSWORD="$DB_PASS" docker exec -e PGPASSWORD -i sec-13-pg \
  psql -U "$DB_USER" -d payments -c "SELECT current_user, now();"
```

### 3.8 Observa la expiración

Espera a que pase el TTL:

```bash
echo "Esperando 130s (TTL=2m)..."
sleep 130

# Vault debería haber ejecutado los revocation_statements
docker exec sec-13-pg psql -U vault_root -d payments -c "\du" | grep "$DB_USER" || echo "ROL ELIMINADO ✓"

# Intentar conectar con la creds vieja debe fallar
PGPASSWORD="$DB_PASS" docker exec -e PGPASSWORD -i sec-13-pg \
  psql -U "$DB_USER" -d payments -c "SELECT 1;" || echo "LOGIN REVOCADO ✓"
```

### 3.9 Revocación anticipada manual

```bash
# Pide otra credencial
NEW=$(vault read -format=json database/creds/payments-app)
NEW_LEASE=$(echo "$NEW" | jq -r .lease_id)

# Revócala ya sin esperar al TTL
vault lease revoke "$NEW_LEASE"
```

## 4. Lo que acabas de demostrar

- Vault emite credenciales PostgreSQL **efímeras**: `CREATE ROLE ... VALID UNTIL ...`.
- La **rotación** no es un evento operativo: es simplemente el TTL expirando. Vault ejecuta los `revocation_statements` sin intervención humana.
- Una fuga tiene **blast radius ≤ TTL** (2 min aquí; en producción típicamente 1 h, elegido para no estresar el pool de conexiones).
- La raíz (`vault_root`/`vault_root_pw`) **no sale** nunca del par Vault↔Postgres. Las apps ni la conocen.

## 5. Limpieza

```bash
docker rm -f sec-13-vault sec-13-pg
docker network rm sec-13-ex03-net
rm -rf /tmp/sec-13-ex03
```

## 6. Para profundizar

- Añade un segundo role `payments-reporter` con `GRANT SELECT ON SCHEMA reports` únicamente; comprueba el aislamiento.
- Rota la raíz: `vault write -f database/rotate-root/payments-db`. Confirma que `vault_root_pw` ya no funciona desde fuera y que Vault sigue emitiendo creds.
- Usa `creation_statements` para generar un usuario con `pg_read_all_settings` y mide cuánto tarda Vault en emitir cada credencial (p99 latency es relevante para apps que piden al pool).
