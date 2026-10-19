# Ejemplo 03 — Cloud Run jobs

## Que demuestra

- `google_cloud_run_v2_job`: contenedor que corre hasta completarse (exit 0), **no** escucha HTTP.
- Util para migraciones de DB, batch nocturno, reproceso de datos.

## Prueba local

El `job.py` es un script Python puro — corrible local sin Docker:

```bash
cd examples/03-cloud-run-jobs
python3 job.py
# [job] processed 10 items in 0.XXs
```

Opcionalmente, con Docker:

```bash
docker build -t cr-job-local .
docker run --rm cr-job-local
```

## Validar Terraform

```bash
terraform init -backend=false -input=false
terraform validate
```
