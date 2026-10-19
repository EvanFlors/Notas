# Ejemplo 01 — Cloud SQL Postgres con Auth Proxy (stand-in local)

## Que demuestra

- Un **Postgres 15** corriendo en Docker en `localhost:5432` que **imita** el otro extremo del Cloud SQL Auth Proxy. El codigo cliente que te conectaria contra Cloud SQL + Auth Proxy es **identico**: cambia solo quien escucha en el socket.
- Un cliente Python (`client.py`) que abre conexion, crea tabla y hace un `SELECT`.
- Terraform (`main.tf`) de un `google_sql_database_instance` real con **IP publica deshabilitada** y una service account dedicada con `roles/cloudsql.client` para el patron Auth Proxy. **No se aplica** a GCP — solo `terraform init -backend=false` + `terraform validate`.

## Archivos

- `docker-compose.yml` — levanta `postgres:15-alpine` en `localhost:5432`.
- `client.py` — cliente `psycopg[binary]` que crea tabla `items`, inserta y lee.
- `requirements.txt` — pinned.
- `main.tf` — Terraform de la infra real (sin aplicar).

## Correr localmente (sin GCP, sin coste)

```bash
cd examples/01-cloud-sql-postgres-with-auth-proxy

# 1. Postgres local
docker compose up -d

# 2. Dependencias Python
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# 3. Cliente
export DATABASE_URL="postgresql://app:app@localhost:5432/appdb"
python client.py
# -> inserta y lista 3 items

# Limpieza
docker compose down -v
```

## Validar el Terraform (sin red, sin GCP)

```bash
terraform init -backend=false -input=false
terraform validate
```

Esto parsea los HCL y valida tipos sin tocar GCP. No se corre `terraform plan` real para evitar que un dia alguien pegue sus credenciales.

## Delta frente al servicio real

- En Cloud SQL real, el `localhost:5432` lo abre `cloud-sql-proxy` (sidecar/binario), que establece TLS mutuo con la instancia e intercambia token IAM. Aqui el `localhost:5432` lo abre el contenedor Postgres directamente.
- IAM database authentication requiere el servicio real; en local se usa password Postgres clasico.
- Backups/PITR/HA no existen en el contenedor; en Cloud SQL vienen por default.
