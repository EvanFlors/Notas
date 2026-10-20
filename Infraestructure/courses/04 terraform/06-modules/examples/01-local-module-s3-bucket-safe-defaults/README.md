# Ejemplo 01 — Módulo local `safe-bucket` con safe defaults

## Concepto que demuestra

Un módulo **local** que encapsula varios recursos relacionados detrás de un contrato pequeño (inputs + outputs), con **safe defaults** opinados. Usamos los providers didácticos `local` y `random` para simular, sin tocar la nube, lo que haría un módulo real sobre `aws_s3_bucket` + sus satélites (versioning, encryption, public-access-block).

El objetivo no es "aprender S3" (eso es un curso aparte); es **aprender la forma de un módulo**: inputs, outputs, encapsulación, safe defaults, documentación y ejemplo de uso.

## Qué simula

Un "bucket" aquí es un directorio en el host (`local_file` lo crea). Un bucket "con versioning habilitado" es un subdirectorio `.versions/`. "Encryption habilitado" es un archivo marcador `.encryption-enabled`. "Access log" es `access.log`. Nada seguro de verdad — es **didáctico**.

Lo que sí es real:

- La **forma del módulo**: `variables.tf`, `main.tf`, `outputs.tf`, `versions.tf`, `README.md`.
- Los **safe defaults** (versioning y encryption activos a menos que el consumidor los apague).
- La **validación** de inputs con `validation {}`.
- El **output** con sufijo random pegado al nombre.
- La **ausencia** de `provider "..." {}` dentro del módulo.

## Estructura

```
01-local-module-s3-bucket-safe-defaults/
├── modules/
│   └── safe-bucket/
│       ├── README.md
│       ├── versions.tf
│       ├── variables.tf
│       ├── main.tf
│       └── outputs.tf
└── root/
    ├── versions.tf
    ├── providers.tf
    ├── main.tf
    └── outputs.tf
```

El `root/` es el root module: tiene `providers.tf` (configura `local` y `random` "de verdad"), consume el módulo con `source = "../modules/safe-bucket"`, y expone los outputs al final.

## Ejecución

> Si no tienes Terraform instalado, el ejemplo se **lee**: la lección sigue siendo útil. Para correrlo:
> - Linux/macOS: `brew install terraform` o `brew install opentofu`, o binario de <https://developer.hashicorp.com/terraform/install>.
> - Verifica: `terraform version` (≥ 1.3).

```bash
cd root
rm -rf .terraform terraform.tfstate* /tmp/tf-06-ex01   # entorno limpio

terraform init
#   Carga el módulo local (vendorea en .terraform/modules/).
#   Baja providers local y random (los pin del root).

terraform plan
#   Deberías ver que creará:
#     - directorio del bucket
#     - .versions/ (versioning ON por default)
#     - .encryption-enabled (encryption ON por default)
#     - access.log vacío
#   Todo con un sufijo random de 4 chars pegado al nombre.

terraform apply -auto-approve

ls /tmp/tf-06-ex01/
#   Debería existir el bucket con los marcadores.

terraform output
#   bucket_name y bucket_path.
```

## Qué mirar en el código

1. `modules/safe-bucket/versions.tf` **declara** `required_providers` pero no `provider "..." {}`. Es el root quien los configura.
2. `modules/safe-bucket/variables.tf` tiene `type`, `description` y `validation` — contrato explícito.
3. `modules/safe-bucket/main.tf` usa `random_string` para un sufijo determinista por `keepers`.
4. `modules/safe-bucket/outputs.tf` expone solo `bucket_name` y `bucket_path`, no atributos internos.
5. `root/main.tf` consume el módulo con `source = "../modules/safe-bucket"` y pasa inputs claros.
6. Nota el `.terraform/modules/modules.json` tras `init`: es cómo Terraform "resuelve" el `source` local.

## Limpieza

```bash
terraform destroy -auto-approve
rm -rf .terraform terraform.tfstate* /tmp/tf-06-ex01
```

## Preguntas de reflexión

1. ¿Qué pasaría si el módulo tuviera `provider "local" { ... }` dentro? ¿Qué pierde el root?
2. ¿Por qué los outputs del módulo exponen `bucket_name` ya con el sufijo random, y no el `var.name` crudo?
3. Si el consumidor hace `versioning_enabled = false`, ¿qué `+/-/~` muestra el `plan` sobre un bucket ya aplicado con el default?
4. ¿Qué agregarías para que `safe-bucket` sea aún más defendible como módulo de producción (si fuera AWS real, no `local_file`)?
