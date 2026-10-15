# Ejemplo 04 — `terraform test` nativo

## Concepto que demuestra

Un **módulo** mínimo con tests nativos `*.tftest.hcl` (Terraform ≥ 1.6). Usamos el provider `random` para que `command = apply` sea **gratis y sin cloud**.

## Prerrequisitos

- `terraform` ≥ 1.6.

## Archivos

- `main.tf` — módulo que genera un `random_pet` con un `length` parametrizable y lo expone como output.
- `variables.tf`, `outputs.tf`.
- `tests/basic.tftest.hcl` — dos `run` blocks: uno `plan`, uno `apply`.

## Ejecución

```bash
cd examples/04-terraform-test-module

terraform init
terraform test
```

Salida esperada (abreviada):

```
tests/basic.tftest.hcl... in progress
  run "plan_defaults"... pass
  run "apply_short_name"... pass
tests/basic.tftest.hcl... tearing down
tests/basic.tftest.hcl... pass

Success! 2 passed, 0 failed.
```

## Qué debes observar

- `command = plan` evalúa aserciones contra el plan sin aplicar.
- `command = apply` ejecuta de verdad el provider (`random`), expone outputs reales, y Terraform **destruye** al final automáticamente.
- Variables pueden sobrescribirse por `run`.
- Las aserciones son expresiones HCL evaluadas en el contexto post-plan/post-apply.

## Patrón para módulos cloud

Si tu módulo depende de AWS, considerá:

- Dejar `command = plan` por defecto (sin credenciales → sin coste).
- Marcar `command = apply` solo en un `run` con un provider override contra un sandbox (`provider "aws" { alias = "sandbox" ... }`).

## Limpieza

```bash
rm -rf .terraform .terraform.lock.hcl terraform.tfstate*
```
