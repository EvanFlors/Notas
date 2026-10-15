# tf-04-01 — Parametriza el stack por ambiente

## 1. Identificación

- **ID:** `tf-04-01-parameterize-the-stack`
- **Tecnología:** terraform
- **Módulo:** `04-variables-outputs-locals`
- **Dificultad:** beginner
- **Duración estimada:** 60 min
- **Tipo:** guided-lab

## 2. Contexto

En `tf-03` montaste un stack con valores literales. Hoy lo refactorizas para que **el mismo código** sirva para `dev` y para `prod`, sin ediciones a los `.tf`. Vas a:

1. Extraer todas las decisiones variables a bloques `variable`.
2. Separar los valores por ambiente en `envs/dev.tfvars` y `envs/prod.tfvars`.
3. Usar `locals` para los valores derivados (nombres canónicos, tags efectivos).
4. Exponer outputs útiles.
5. Comprobar empíricamente la jerarquía de precedence.

El stack usa providers **locales** (`tls`, `random`, `local`) — no toca ninguna cloud. Genera una llave TLS self-signed por ambiente y escribe un manifest en disco.

## 3. Objetivos

Al terminar deberías poder:

- Declarar `variable` con `type` rico (`object` + `optional`), `description` y `validation`.
- Estructurar `envs/<env>.tfvars` como la fuente de verdad por ambiente.
- Resolver mentalmente qué valor gana cuando conviven `terraform.tfvars`, `-var-file`, `TF_VAR_*` y `-var`.
- Documentar un output con `description`.

## 4. Prerrequisitos

- Terraform >= 1.3.0 (`terraform version`). OpenTofu también sirve (los `.tf` son idénticos).
- `bash`, `grep`, `jq` (opcional).
- Sin costo (providers locales).
- Puertos: ninguno.

## 5. Instrucciones

Trabaja en `/tmp/tf-04-01/`. Copia el starter:

```bash
mkdir -p /tmp/tf-04-01
cp -r courses/terraform/04-variables-outputs-locals/activities/01-parameterize-the-stack/starter/* /tmp/tf-04-01/
cd /tmp/tf-04-01
```

El starter contiene:

```
versions.tf        # ya listo (required_providers)
main.tf            # recursos con literales hard-coded, PENDIENTE de parametrizar
variables.tf       # vacío (crea las variable aquí)
outputs.tf         # vacío (crea los output aquí)
envs/
  dev.tfvars       # vacío
  prod.tfvars      # vacío
```

### Paso 1 — identificar qué parametrizar

Lee `main.tf`. Identifica los literales que **deberían** variar por ambiente y los que **no**. Reglas:

- Varía por ambiente: nombre del ambiente, cantidad de llaves (`key_count`), tamaño de bits de la llave RSA, tags.
- NO varía: la lógica del stack (que haya un `tls_private_key` por cada "key_count", que se escriba un manifest, el formato del manifest).

### Paso 2 — declarar las variables en `variables.tf`

Crea estas variables (nombres exactos, el validador los chequea):

| Nombre | Tipo | Requerida | Observaciones |
|---|---|---|---|
| `environment` | `string` | sí (sin default) | `validation`: debe ser `dev`, `stg` o `prod`. |
| `project` | `string` | sí (sin default) | `validation`: `snake_case`, 3-30 chars, inicia con letra. |
| `key_count` | `number` | con default `1` | `validation`: entre 1 y 5. |
| `rsa_bits` | `number` | con default `2048` | `validation`: ∈ {2048, 3072, 4096}. |
| `tags` | `map(string)` | con default `{}` | sin validation. |

Cada variable DEBE tener `description`.

### Paso 3 — usar `locals` para los valores derivados

En `main.tf` (o en un `locals.tf` si prefieres), agrega:

```hcl
locals {
  name_prefix = "${var.project}-${var.environment}"

  base_tags = {
    environment = var.environment
    project     = var.project
    managed_by  = "terraform"
  }
  effective_tags = merge(local.base_tags, var.tags)
}
```

### Paso 4 — refactorizar `main.tf` para usar variables y locals

- `tls_private_key.keys` debe generar `var.key_count` llaves (usa `count = var.key_count`; `for_each` se verá en `tf-07`).
- `rsa_bits = var.rsa_bits`.
- `local_file.manifest.filename = "${path.module}/out/${local.name_prefix}.txt"`.
- El contenido del manifest debe incluir: `project`, `environment`, `key_count`, `rsa_bits`, y `effective_tags` (`jsonencode`).

### Paso 5 — definir los outputs en `outputs.tf`

Nombres exactos (el validador los pide):

- `name_prefix` → `local.name_prefix` (description).
- `manifest_path` → `local_file.manifest.filename` (description).
- `key_fingerprints` → una `list(string)` con el SHA256 de la llave pública de cada `tls_private_key`. Pista: `[for k in tls_private_key.keys : sha256(k.public_key_pem)]`.
- `effective_tags` → `local.effective_tags` (description).

### Paso 6 — rellenar los `envs/*.tfvars`

**`envs/dev.tfvars`:**

```hcl
environment = "dev"
project     = "payments_api"
key_count   = 1
rsa_bits    = 2048
tags = {
  cost_center = "cc-dev-0001"
  owner       = "payments-team"
}
```

**`envs/prod.tfvars`:**

```hcl
environment = "prod"
project     = "payments_api"
key_count   = 3
rsa_bits    = 4096
tags = {
  cost_center = "cc-prod-0001"
  owner       = "payments-team"
  compliance  = "pci"
}
```

### Paso 7 — correr y verificar

```bash
cd /tmp/tf-04-01
terraform init

# dev
terraform plan  -var-file=envs/dev.tfvars
terraform apply -var-file=envs/dev.tfvars -auto-approve
terraform output
cat out/payments_api-dev.txt

# limpia antes de reaplicar con prod (evita que el state mezcle ambientes)
terraform destroy -var-file=envs/dev.tfvars -auto-approve

# prod
terraform apply -var-file=envs/prod.tfvars -auto-approve
cat out/payments_api-prod.txt
```

### Paso 8 — probar la precedence a mano

Con el stack ya aplicado en `prod`, haz solo `plan` (no apply) alternando fuentes:

```bash
# 1. default + envs/prod.tfvars → environment = "prod"
terraform plan -var-file=envs/prod.tfvars

# 2. añade TF_VAR_* → gana sobre el tfvars
TF_VAR_environment=stg terraform plan -var-file=envs/prod.tfvars
#    En el plan verás que environment = "stg".

# 3. añade -var en CLI → gana sobre TF_VAR y sobre tfvars
TF_VAR_environment=stg terraform plan -var-file=envs/prod.tfvars -var environment=dev
#    environment = "dev".
```

### Paso 9 — ejecutar el validador

```bash
bash courses/terraform/04-variables-outputs-locals/activities/01-parameterize-the-stack/tests/validate.sh
```

El validador:

- Verifica estructura (archivos, variables declaradas con `type`, `description`, `validation` donde corresponde).
- Verifica outputs (nombres exactos con `description`).
- Verifica contenido de `envs/dev.tfvars` y `envs/prod.tfvars`.
- Si `terraform` está instalado, ejecuta `init` y 3 planes para probar la precedence experimentalmente.
- Si `terraform` no está, hace **SKIP** del plan y marca los checks estructurales.

## 6. Resultado esperado

- `terraform apply -var-file=envs/prod.tfvars` crea 3 llaves y un manifest.
- `terraform output -json | jq '.key_fingerprints.value | length'` devuelve `3`.
- `cat out/payments_api-prod.txt` muestra `environment = prod`, `key_count = 3`, `rsa_bits = 4096`.
- La precedence es la esperada en los 3 planes del Paso 8.

## 7. Criterios de aceptación

- `tests/validate.sh` imprime `RESULT: PASS`.
- Ningún valor literal "dev", "prod" o "payments_api" aparece hard-coded en `main.tf` ni en `outputs.tf`.
- Las validaciones fallan temprano: `terraform plan -var environment=qa -var-file=envs/dev.tfvars` da error con el mensaje de la variable.

## 8. Validación

```bash
bash courses/terraform/04-variables-outputs-locals/activities/01-parameterize-the-stack/tests/validate.sh
```

Variable opcional: `WORK_DIR=/otra/ruta` para apuntar a otro directorio de trabajo.

## 9. Preguntas de reflexión

1. ¿Qué pasaría si **no** destruyes antes de pasar de `dev` a `prod` en el mismo `.tfstate`? ¿Por qué el patrón "un state por ambiente" es más seguro?
2. ¿Qué validaciones de las que escribiste podrían vivir también en una policy OPA/Rego? ¿Por qué dejarlas igualmente en `validation`?
3. Imagina que `rsa_bits = 4096` tarda 10 s por llave y en `prod` tienes `key_count = 3`. ¿Qué cambiaría si marcas una variable como `nullable = false`?
4. ¿Qué outputs **no** expondrías si el stack se consume con `terraform_remote_state`? ¿Por qué menos es más?

## 10. Extensiones

- Añade un `envs/stg.tfvars` con valores intermedios y verifica que el stack funciona sin tocar código.
- Convierte `tags` en un `object` con campos obligatorios (`cost_center`, `owner`) y opcionales (`compliance`), con `validation`.
- Modifica el stack para que `key_count` acepte `0`; verifica que `terraform plan` no crea recursos (y que los outputs manejan la lista vacía).
- Pasa un override de `tags` solo por `-var` y verifica que gana sobre el `tfvars`.

## 11. Limpieza

```bash
cd /tmp/tf-04-01 && terraform destroy -var-file=envs/prod.tfvars -auto-approve 2>/dev/null || true
rm -rf /tmp/tf-04-01
```
