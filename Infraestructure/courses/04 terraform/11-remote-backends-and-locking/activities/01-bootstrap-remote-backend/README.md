# tf-11-01 — Bootstrap de backend remoto S3 + DynamoDB (dual-mode)

## 1. Identificación

- **ID:** `tf-11-01-bootstrap-remote-backend`
- **Tecnología:** terraform
- **Módulo:** `11-remote-backends-and-locking`
- **Dificultad:** advanced
- **Duración estimada:** 75 min
- **Tipo:** guided-lab

## 2. Contexto

Tienes un stack con backend local (`terraform.tfstate` en disco). Vas a: crear el bucket S3 y la tabla DynamoDB para alojar el state remoto con locking, añadir el bloque `backend "s3" {}` al stack, migrar el state con `terraform init -migrate-state`, y verificar que el objeto quedó en el bucket y el lock vive en la tabla.

La actividad corre en **dual-mode**:

- `MODE=local` (default) — usa **localstack** en docker, sin cuenta cloud ni coste. Si docker no está, el validador hace `SKIP` graceful.
- `MODE=live` — contra AWS real. Costo esperado ~$0 (S3 vacío + DDB PAY_PER_REQUEST a este volumen cae en Free Tier). Igual limpia al terminar.

## 3. Objetivos

- Hacer bootstrap del backend (bucket + tabla) con `aws` CLI o script.
- Migrar un stack local a remoto con `-migrate-state`.
- Confirmar que el state remoto existe y es consistente.
- Observar el lock aparecer y desaparecer durante un `apply`.

## 4. Prerrequisitos

- `terraform` >= 1.6 (o `tofu` >= 1.6).
- `aws` CLI v2.
- `MODE=local`: `docker` corriendo. Si no está, la actividad hace SKIP.
- `MODE=live`: credenciales AWS (`AWS_PROFILE` o `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`) con permisos sobre S3 + DynamoDB.
- Puerto 4566 libre si usas `MODE=local`.
- Sin secretos reales en código.

## 5. Instrucciones

Trabaja en `/tmp/tf-11-01/`. Copia el starter:

```bash
mkdir -p /tmp/tf-11-01
cp -r courses/terraform/11-remote-backends-and-locking/activities/01-bootstrap-remote-backend/starter/* /tmp/tf-11-01/
cd /tmp/tf-11-01
```

### Paso 1 — primer apply con backend LOCAL

```bash
# Aún sin backend remoto configurado: terraform crea terraform.tfstate local.
terraform init
terraform apply -auto-approve
```

Verifica:

```bash
ls -la terraform.tfstate
terraform state list      # debe mostrar random_pet.demo (al menos)
```

### Paso 2 — bootstrap del backend

Hay un script `scripts/bootstrap-backend.sh` (lo copiaste desde el starter) que, según `MODE`:

- `MODE=local`: arranca localstack (`tf11-localstack`), crea `tf-state-tf11` y `tf-lock-tf11`.
- `MODE=live`: usa tus credenciales AWS para crear bucket y tabla reales con los nombres de las variables `BUCKET_LIVE` y `TABLE_LIVE` (defaults sugeridos en el script; **cámbialos** para que sean únicos en tu cuenta).

Córrelo:

```bash
MODE=local bash scripts/bootstrap-backend.sh
# o:
# MODE=live BUCKET_LIVE=tu-bucket-unico TABLE_LIVE=tu-tabla bash scripts/bootstrap-backend.sh
```

Al finalizar imprime qué variables de entorno exportar para que `terraform` hable con localstack. Expórtalas en tu shell (modo local):

```bash
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export AWS_ENDPOINT_URL_S3=http://localhost:4566
export AWS_ENDPOINT_URL_DYNAMODB=http://localhost:4566
```

### Paso 3 — añadir el bloque backend

En `main.tf` **descomenta** (o añade) el bloque `backend "s3" {}` vacío a propósito. Debe verse así:

```hcl
terraform {
  required_version = ">= 1.6.0"
  backend "s3" {}
  required_providers { ... }
}
```

El archivo `backend.hcl` (ya en el starter) tiene la config apuntando al bucket/tabla locales. Para `MODE=live` edita `backend.hcl` con tus nombres.

### Paso 4 — migrar el state

```bash
terraform init -backend-config=backend.hcl -migrate-state
```

Terraform preguntará si quieres copiar el state local al backend remoto. Responde `yes`. Al terminar:

- Debe aparecer el objeto en el bucket:
  ```bash
  aws --endpoint-url=${AWS_ENDPOINT_URL_S3:-} s3 ls s3://tf-state-tf11/tf-11-01/
  ```
- El `terraform.tfstate` local **ya no se usa** (puedes borrarlo tras verificar).

### Paso 5 — observar el lock

En una terminal arranca un `apply` lento (añade un `random_pet` extra en `main.tf` para forzar diff):

```bash
terraform apply -auto-approve
```

En otra terminal, mientras tanto:

```bash
aws --endpoint-url=${AWS_ENDPOINT_URL_DYNAMODB:-} dynamodb scan --table-name tf-lock-tf11
```

Debes ver una fila con `LockID` apuntando a tu key del bucket. Al terminar el apply, la fila desaparece.

### Paso 6 — validar

```bash
MODE=local bash tests/validate.sh
```

Debe imprimir `RESULT: PASS`.

## 6. Resultado esperado

- `tf-state-tf11` existe en S3 (localstack o AWS real) con versioning activo.
- `tf-lock-tf11` existe en DynamoDB con PK `LockID`.
- `tf-11-01/terraform.tfstate` existe como objeto en el bucket.
- `terraform state list` desde `/tmp/tf-11-01/` muestra los recursos (indicando que lee del backend remoto).
- `.terraform/terraform.tfstate` (metadata del backend) refleja `"backend": "s3"`.

## 7. Criterios de aceptación

- `tests/validate.sh` imprime `RESULT: PASS`.
- No queda `terraform.tfstate` local con contenido real (solo backup opcional).
- El bucket tiene versioning habilitado (ambos modos lo configuran automáticamente).

## 8. Validación

```bash
MODE=local bash courses/terraform/11-remote-backends-and-locking/activities/01-bootstrap-remote-backend/tests/validate.sh
```

Si `docker` o `aws` CLI no están instalados → `SKIP` controlado (exit 0).

## 9. Preguntas de reflexión

1. ¿Por qué el bootstrap del backend tiene que vivir fuera del propio stack (o con backend local)?
2. ¿Qué pasa exactamente durante `terraform init -migrate-state`? ¿Qué requests hace a S3 y a DynamoDB?
3. Si hubieras cambiado el `backend "s3" {}` sin `-migrate-state`, ¿qué habría ocurrido en el próximo `plan`?
4. ¿Qué política IAM mínima necesitaría el principal que corre este Terraform? (describe acciones y recursos específicos).
5. Compara `use_lockfile = true` (S3 native locking) con DDB. ¿Qué sacrificas al eliminar la tabla?

## 10. Extensiones

- Repite la actividad con `use_lockfile = true` en lugar de DDB. Verifica que el objeto `.tflock` aparece durante apply.
- Añade `aws_s3_bucket_lifecycle_configuration` al bootstrap para expirar versiones no-actuales a 90 días.
- Cambia a `MODE=live` y mide: ¿cuánto tarda el `init -migrate-state` real vs localstack?

## 11. Limpieza

```bash
# dentro de /tmp/tf-11-01/
terraform destroy -auto-approve || true

# modo local:
docker rm -f tf11-localstack >/dev/null 2>&1 || true

# modo live (cuidado — borra bucket y tabla REALES):
# aws s3 rm s3://tu-bucket --recursive
# aws s3api delete-bucket --bucket tu-bucket
# aws dynamodb delete-table --table-name tu-tabla

rm -rf /tmp/tf-11-01
```
