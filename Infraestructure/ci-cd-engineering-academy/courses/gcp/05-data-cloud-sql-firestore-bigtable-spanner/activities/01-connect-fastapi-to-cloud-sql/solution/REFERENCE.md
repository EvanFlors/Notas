# Referencia — gcp-05-01

Esta carpeta contiene una solucion valida. Comparate contra ella:

- `main.py` — FastAPI con lifespan que crea tabla, `/healthz` con `SELECT 1`, `POST /items`, `GET /items`.
- `requirements.txt` — fastapi + uvicorn + psycopg[binary] + pydantic.
- `main.tf` — Cloud SQL Postgres 15 en `europe-west1`, HA regional, PITR, IAM auth, Auth Proxy only (`ipv4_enabled = false`), SA dedicada con `roles/cloudsql.client`.
- `ADR-DB-CHOICE.md` — ADR con las 5 secciones, decision Cloud SQL + alternativas AlloyDB / Spanner / self-managed descartadas.

Validador: `bash tests/validate.sh /tmp/gcp-05-01`.
