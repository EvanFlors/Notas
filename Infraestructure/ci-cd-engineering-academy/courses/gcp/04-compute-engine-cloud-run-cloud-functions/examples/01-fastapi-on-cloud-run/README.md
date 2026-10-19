# Ejemplo 01 — FastAPI en Cloud Run (Dockerfile buildable local)

## Que demuestra

- Un servicio **FastAPI** empaquetado en Docker **que puedes construir y correr en tu laptop** sin tocar GCP.
- El Terraform equivalente para un `google_cloud_run_v2_service` en una region europea, con **service account dedicada** y lectura de `$PORT`.
- No se aplica a GCP real; solo se usa `terraform init -backend=false && terraform validate` para comprobarlo.

## Archivos

- `main.py` — app FastAPI con endpoints `GET /`, `GET /healthz`.
- `requirements.txt` — pinned.
- `Dockerfile` — multi-stage slim con usuario no-root, lee `$PORT`.
- `main.tf` — `google_cloud_run_v2_service` con un `template` y una SA dedicada.

## Prueba local (sin GCP)

```bash
cd examples/01-fastapi-on-cloud-run

# Build (tarda ~30s la primera vez)
docker build -t fastapi-local .

# Corre y mapea 8080
docker run --rm -p 8080:8080 -e PORT=8080 fastapi-local
```

En otra terminal:

```bash
curl -s localhost:8080/healthz
# {"status":"ok"}
```

Esto reproduce exactamente lo que haria Cloud Run al desplegar la imagen.

## Validar el Terraform

```bash
cd examples/01-fastapi-on-cloud-run
terraform init -backend=false -input=false
terraform validate
```

**No corras `terraform apply`.** No hay credenciales reales y el proyecto es un placeholder.
