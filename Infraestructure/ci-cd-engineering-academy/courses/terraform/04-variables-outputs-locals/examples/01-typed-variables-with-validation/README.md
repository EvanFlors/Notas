# Ejemplo 01 — Variables tipadas con validation

## Concepto que demuestra

Un bloque `variable` completo: `type` (incluyendo `object` con `optional()`), `default`, `description`, y **múltiples `validation`** que fallan temprano con mensajes útiles.

## Contexto

El stack genera un nombre canónico (`random_pet`) y lo escribe en un archivo local. No toca red ni nube: todo pasa en tu disco. El objetivo no es el output, es ver qué pasa cuando pasas valores que respetan y que violan las validaciones.

## Objetivo

Al terminar sabrás:

- Declarar una `variable` con cada tipo primitivo y con `object({ ... })`.
- Usar `validation` con `can(regex(...))` y con `contains(...)`.
- Leer el error exacto que lanza TF cuando una validación falla.
- Diferenciar los defaults del bloque `variable` de un `terraform.tfvars`.

## Prerrequisitos

- Terraform >= 1.3.0 (`terraform version`). OpenTofu también sirve.
- `bash`, `grep`.
- Sin costo (providers locales: `random`, `local`).

## Archivos

```
versions.tf        # required_version + required_providers (random, local)
variables.tf       # cuatro variables, tres con validation
main.tf            # random_pet + local_file
outputs.tf         # dos outputs
terraform.tfvars   # ejemplo de valores válidos (ambiente dev)
```

## Ejecución

```bash
cd courses/terraform/04-variables-outputs-locals/examples/01-typed-variables-with-validation/

# 1. Inicializa (descarga providers; crea .terraform/).
terraform init

# 2. Caso feliz: usa los valores de terraform.tfvars.
terraform plan
#    Verás que creará random_pet.name y local_file.manifest.

# 3. Rompe validaciones a propósito:

#    a) environment inválido
terraform plan -var environment=qa
#    => Error: environment debe ser dev, stg o prod.

#    b) pet_length fuera de rango
terraform plan -var pet_length=9
#    => Error: pet_length debe estar entre 1 y 5.

#    c) service.name con caracteres prohibidos
terraform plan -var 'service={name="BadName!",team="payments"}'
#    => Error: service.name debe ser snake_case (3-20 chars, inicio con letra).

# 4. Aplica el caso feliz y mira el output:
terraform apply -auto-approve
terraform output
ls out/
cat out/*.txt

# 5. Limpia (opcional).
terraform destroy -auto-approve
```

## Qué mirar

- El error de `validation` **llega antes del plan real** — no se construye el grafo.
- Puedes tener más de una `validation` por variable: todas se evalúan.
- `optional(string, "defaultvalue")` dentro de un `object` evita tener que declarar todos los campos en el tfvars.
- `random_pet.name.id` y `local_file.manifest.filename` son atributos computados que ves después del `apply`; en `plan` aparecen como `(known after apply)`.

## Limpieza

```bash
terraform destroy -auto-approve
rm -rf .terraform .terraform.lock.hcl terraform.tfstate* out/
```
