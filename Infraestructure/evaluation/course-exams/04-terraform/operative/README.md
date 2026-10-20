# Ejercicio operativo — nivel `terraform validate`

**Tiempo sugerido:** 35–45 min dentro del examen.

**Entorno:** máquina local con Terraform ≥ 1.6 (u OpenTofu equivalente). **Sin credenciales cloud.** Todos los providers son locales (`null`, `random`, `local`, `tls`).

**Comandos permitidos y únicos esperados:**

```bash
terraform fmt -recursive
terraform init -backend=false
terraform validate
```

**Prohibido:** `terraform apply`, `terraform plan` contra cloud, cualquier credencial real, cualquier `tfvars` con datos reales de tenant/cuenta.

---

## Problema

Recibes el stack en este directorio (`main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`). El equipo anterior lo dejó así:

- Mezcla `count` y `for_each` sin criterio.
- Renombró un recurso en el código sin preservar la identidad en el state.
- Declara variables sin tipo o sin `validation`.
- Un `output` que debería ser `sensitive` no lo es, y uno marcado `sensitive` no es realmente secreto.
- Un `lifecycle` mal puesto fuerza replace en cada plan.
- `provider "random"` sin `required_providers`.
- El `moved` block que debería acompañar al rename no existe.

El código **no pasa `terraform validate`** en su estado actual (hay errores de sintaxis y de tipo intencionales).

---

## Tu tarea

1. **Hacer que `terraform fmt -recursive && terraform init -backend=false && terraform validate` termine en `Success!`** sin crear archivos nuevos de providers remotos.
2. **Refactorizar `aws_null_users` para usar `for_each` sobre un `map(object)`** en lugar de `count` indexado por entero. Justifica en comentarios por qué.
3. **Agregar un `moved` block** para que el recurso `random_pet.app` (antes `random_pet.application`) no se recree.
4. **Agregar `variable "environment"` con `validation`** que acepte únicamente `dev`, `stg`, `prod`.
5. **Agregar `lifecycle { prevent_destroy = true }` en el `tls_private_key.ca`** y explicar en comentario cuándo removerlo.
6. **Corregir el `output` que fuga el `private_key_pem`**: debe estar marcado `sensitive`. El output `name_prefix` que estaba marcado `sensitive` sin razón debe dejar de estarlo.
7. **Declarar correctamente `required_providers`** en `versions.tf` con pinning `~>` en una minor estable.

## Entregables

- Los 4 archivos `.tf` modificados en este mismo directorio.
- Un bloque de comentarios al final de `main.tf` titulado `# NOTAS` con:
  - Por qué `for_each` sobre `count` aquí.
  - Qué garantiza y qué **no** garantiza `prevent_destroy`.
  - Qué garantiza y qué **no** garantiza `sensitive` en outputs (pista: state en claro).

## Validación automática (lo que corre el instructor)

```bash
cd operative/
terraform fmt -check -recursive                   # debe salir 0
terraform init -backend=false                      # debe inicializar sin red salvo registry de providers
terraform validate                                 # debe decir "Success!"
grep -q 'for_each' main.tf                         # debe existir
grep -q 'moved' main.tf                            # debe existir el bloque moved
grep -q 'prevent_destroy *= *true' main.tf         # debe existir
grep -q 'validation' variables.tf                  # debe existir
grep -q 'sensitive *= *true' outputs.tf            # debe existir en el output correcto
```

## Prohibiciones (red flags que invalidan la entrega)

- Hardcodear valores que parezcan secretos reales (tokens, access keys, incluso ficticios con formato real `AKIA...`).
- Usar `terraform state rm` o similares para "ocultar" el problema.
- Comentar bloques en vez de corregirlos.
- Agregar providers cloud (`aws`, `google`, `azurerm`): no son necesarios ni permitidos.
- Marcar todo como `sensitive` para "ir sobre seguro" (indica que no se entiende qué protege).
