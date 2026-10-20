# Actividad `cap-06-02-bootstrap-backend-local`

Validar los tres stacks de Terraform (AWS, GCP, Azure) sin aplicar nada en una cuenta real.

## Pasos

1. Instalar Terraform `>= 1.6`:

   ```bash
   terraform -v
   ```

2. Formato en los tres clouds:

   ```bash
   cd projects/capstone/stages/06-terraform-local-to-cloud-minimum
   terraform -chdir=terraform/aws   fmt -check -recursive
   terraform -chdir=terraform/gcp   fmt -check -recursive
   terraform -chdir=terraform/azure fmt -check -recursive
   ```

3. `terraform validate` sin backend remoto (ningún recurso creado):

   ```bash
   for d in terraform/aws terraform/gcp terraform/azure; do
     terraform -chdir="$d" init -backend=false -input=false
     terraform -chdir="$d" validate
   done
   ```

4. (Opcional) `init` real contra **LocalStack** para AWS:

   ```bash
   docker run --rm -d -p 4566:4566 --name ls localstack/localstack
   terraform -chdir=terraform/aws init \
     -backend-config="bucket=cap-state-local" \
     -backend-config="dynamodb_table=cap-lock-local" \
     -backend-config="region=us-east-1"
   docker stop ls
   ```

5. Correr el validador:

   ```bash
   bash activities/02-bootstrap-backend-local/tests/validate.sh
   ```

## Qué chequea el validador

- Los cinco archivos (`main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `backend.tf`) existen en los tres clouds.
- `backend.tf` **no** tiene valores embebidos (bucket real, project id, storage account, etc.).
- Ningún `.tf` menciona IDs plausiblemente reales (12 dígitos AWS, tenant GUID, project id arbitrario).
- Si `terraform` está en `PATH`, corre `terraform validate` *opt-in* (si falla pero el binario no está, el test lo marca como SKIP, no FAIL).

## Nota de costo

Este lab se completa en `$0` — ningún recurso cloud real se crea. LocalStack corre en Docker y se destruye con `docker stop`.
