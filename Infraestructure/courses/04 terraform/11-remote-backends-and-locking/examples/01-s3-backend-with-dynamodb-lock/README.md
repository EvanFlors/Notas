# Ejemplo 01 — Backend S3 con lock en DynamoDB (dual-mode)

Configuración mínima y reproducible de un backend `s3` con bloqueo en DynamoDB. Dual-mode: por default usa **localstack** (sin coste, sin cuenta cloud); con `MODE=live` apunta a AWS real.

> Lectura, no actividad. La actividad guiada equivalente es `activities/01-bootstrap-remote-backend/`.

## Qué incluye

- `main.tf` — un recurso ficticio (`random_pet`) para que haya algo en el state.
- `backend.hcl.local` — config del backend apuntando a localstack (`http://localhost:4566`).
- `backend.hcl.live` — config del backend apuntando a AWS real.
- `bootstrap.sh` — script que arranca localstack (modo `local`) o verifica credenciales (modo `live`) y crea bucket + tabla.

## Uso rápido

### Modo local (default)

```bash
export MODE=local
bash bootstrap.sh                 # arranca localstack, crea bucket + tabla
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
terraform init -backend-config=backend.hcl.local
terraform apply -auto-approve
```

Verifica el state en localstack:

```bash
aws --endpoint-url=http://localhost:4566 s3 ls s3://tf-state-demo/
aws --endpoint-url=http://localhost:4566 dynamodb scan --table-name tf-lock-demo
```

Limpieza:

```bash
terraform destroy -auto-approve
docker rm -f tf11-localstack
```

### Modo live (AWS real)

```bash
export MODE=live
# Debes tener credenciales AWS exportadas o perfil activo.
bash bootstrap.sh                 # crea bucket + tabla reales
terraform init -backend-config=backend.hcl.live
terraform apply -auto-approve
```

**Costo**: bucket S3 vacío + tabla DynamoDB PAY_PER_REQUEST con un ítem puntual = esencialmente $0 dentro del Free Tier. Igualmente, limpia al terminar.

Limpieza:

```bash
terraform destroy -auto-approve
aws s3 rm s3://<tu-bucket> --recursive
aws s3api delete-bucket --bucket <tu-bucket>
aws dynamodb delete-table --table-name <tu-tabla>
```

## Qué mirar

- Durante `terraform apply`, en otra terminal, lanza `aws dynamodb scan` y verás **la fila del lock aparecer y desaparecer**. Es el mecanismo.
- Tras apply, el objeto `demo/terraform.tfstate` está en el bucket. Si bajas localstack y lo vuelves a levantar sin persistencia, lo pierdes (localstack efímero por default).
- `backend.hcl.local` incluye `use_lockfile = false` para forzar el camino con DDB (más didáctico).

## Archivos

```
.
├── README.md
├── main.tf
├── backend.hcl.local
├── backend.hcl.live
└── bootstrap.sh
```
