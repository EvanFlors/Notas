# Actividad 01 — Conectar FastAPI a Cloud SQL via Auth Proxy (stand-in local)

## 1. Identificacion

- **ID:** `gcp-05-01-connect-fastapi-to-cloud-sql`
- **Tecnologia:** `gcp`
- **Modulo:** `gcp-05-data-cloud-sql-firestore-bigtable-spanner`
- **Dificultad:** intermediate
- **Duracion:** 80–100 min
- **Tipo:** guided-lab (independiente de la actividad 02)

## 2. Contexto

El equipo `checkout` quiere migrar su API de pagos a GCP. Decidieron **Cloud SQL Postgres** por simplicidad y por que ya tienen Postgres en AWS RDS. Tu tarea en esta fase: montar **la forma** del despliegue — codigo cliente + Terraform de la DB con los flags correctos — **sin tocar ningun proyecto GCP real** y sin gastar un euro. El codigo deberia funcionar sin cambios el dia que la DB real este arriba y el Auth Proxy conectado.

Por eso: usa Postgres en Docker en `localhost:5432` como stand-in del otro extremo del proxy. El codigo cliente es ciego: solo ve `DATABASE_URL`.

## 3. Objetivos

Al terminar deberias poder, sin consultar la leccion:

- Explicar por que `ipv4Enabled = false` + Auth Proxy es el default correcto en Cloud SQL.
- Escribir una app FastAPI con DAL minima contra Postgres y healthcheck que valide la conexion.
- Escribir el Terraform de la instancia con HA, backups, PITR e IAM auth habilitado, y una SA + binding `roles/cloudsql.client`.
- Justificar en 1 pagina Postgres vs AlloyDB.

## 4. Prerrequisitos

- Haber leido `../../theory/lesson.md` (secciones 1, 2, 3).
- Haber recorrido `examples/01-cloud-sql-postgres-with-auth-proxy/`.
- Herramientas: `bash`, `docker` + `docker compose`, `python3` >= 3.10, `terraform` >= 1.3, `jq`.

**Costos**: cero. Postgres corre en tu laptop; Terraform no se aplica.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/gcp-05-01
cd /tmp/gcp-05-01
```

Puedes usar otro directorio; en ese caso: `bash tests/validate.sh /tu/ruta`.

### 5.2 Codigo FastAPI (`main.py`, `requirements.txt`)

- **`main.py`** debe exponer:
  - `GET /healthz` -> 200 si la conexion a Postgres va. Debe hacer `SELECT 1`.
  - `POST /items` con JSON `{"name": "foo"}` -> inserta y devuelve el `id`.
  - `GET /items` -> lista en orden de insercion.
  - La conexion debe leer **`DATABASE_URL`** del env (no hardcode).
  - Debe crear la tabla `items (id SERIAL PK, name TEXT)` al arrancar si no existe.
- **`requirements.txt`** debe incluir `fastapi`, `uvicorn`, y un cliente Postgres (`psycopg[binary]` o `asyncpg`).

### 5.3 Terraform (`main.tf`)

Debe declarar:

- `terraform` + `required_providers` con `google` (version >= 5.0).
- `provider "google"` con `project = "example-project-id"` (placeholder) y una `region` que empiece con `europe-`.
- `resource "google_service_account" "app_sa"` dedicada.
- `resource "google_project_iam_member"` con `role = "roles/cloudsql.client"` bindeado a esa SA.
- `resource "google_sql_database_instance" "primary"`:
  - `database_version = "POSTGRES_15"` (o `POSTGRES_14`/`16` aceptados).
  - `region` empezando con `europe-`.
  - `deletion_protection = true`.
  - `settings.ip_configuration.ipv4_enabled = false`.
  - `settings.backup_configuration.enabled = true` y `point_in_time_recovery_enabled = true`.
  - `settings.database_flags` con `cloudsql.iam_authentication = on`.
- `resource "google_sql_database" "appdb"`.
- `resource "google_sql_user"` con `type = "CLOUD_IAM_SERVICE_ACCOUNT"` apuntando a la SA.

> **Importante**: `project` placeholder. **No** uses project IDs reales. El validador rechaza strings que parezcan nombres reales de orgs.

### 5.4 ADR (`ADR-DB-CHOICE.md`)

Formato ADR estandar con secciones:

- `## Estado`
- `## Contexto`
- `## Decision`
- `## Consecuencias`
- `## Alternativas`

Contenido minimo (el validador lo exige):

- Mencion explicita de **Cloud SQL** y de **AlloyDB**.
- Mencion de **Auth Proxy** (o `cloud-sql-proxy`).
- Mencion de **Europa** / `eu-west` / `europe-`.
- Al menos **3 criterios** de comparacion: coste, operacion, rendimiento, lock-in, HA, PITR...
- Al menos **2 alternativas** descartadas (incluir "self-managed Postgres en GCE" y/o "Spanner").

### 5.5 Entregables

```
/tmp/gcp-05-01/
├── main.py
├── requirements.txt
├── main.tf
└── ADR-DB-CHOICE.md
```

### 5.6 Correr la app en local (humo manual)

```bash
docker run -d --rm --name gcp05-pg \
  -e POSTGRES_USER=app -e POSTGRES_PASSWORD=app -e POSTGRES_DB=appdb \
  -p 5432:5432 postgres:15-alpine

python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

export DATABASE_URL="postgresql://app:app@localhost:5432/appdb"
uvicorn main:app --port 8000 &
sleep 2

curl -s localhost:8000/healthz
curl -s -X POST -H 'content-type: application/json' \
  -d '{"name":"alpha"}' localhost:8000/items
curl -s localhost:8000/items

kill %1
docker rm -f gcp05-pg
```

## 6. Validacion

```bash
bash tests/validate.sh /tmp/gcp-05-01
```

Comprueba archivos, campos minimos de Terraform y secciones del ADR. **No** aplica Terraform, **no** corre la app.

## 7. Preguntas de reflexion

1. ¿Que pasa si pones `ipv4Enabled = true` "solo para dev"? ¿Como lo detecta Security?
2. ¿Que te da `cloudsql.iam_authentication = on` que un password Postgres no?
3. Si el requerimiento es "multi-region con tx fuertes", ¿sigues con Cloud SQL? ¿Por que no?
4. ¿Donde pones el `cloud-sql-proxy` cuando la app corre en Cloud Run? ¿Y en GKE?

## 8. Limpieza

```bash
docker rm -f gcp05-pg 2>/dev/null || true
rm -rf /tmp/gcp-05-01
```
