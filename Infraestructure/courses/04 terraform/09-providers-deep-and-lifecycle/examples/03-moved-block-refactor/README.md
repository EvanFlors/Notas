# Ejemplo 03 — `moved {}` para renombrar sin recrear

## Concepto que demuestra

Un rename de recurso que, **sin** `moved`, produce `destroy + create`. **Con** `moved`, el plan queda limpio (`No changes.`) y el state actualiza solo el address.

## Prerrequisitos

- Terraform ≥ 1.5 o OpenTofu ≥ 1.6.
- Permiso de escritura en `/tmp/`.

## Ejecución

```bash
rm -rf /tmp/tf-09-ex03 && mkdir -p /tmp/tf-09-ex03 && cd /tmp/tf-09-ex03
```

### Paso 1 — stack inicial

Crea `main.tf`:

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    local = { source = "hashicorp/local", version = "~> 2.5" }
  }
}

resource "local_file" "old_name" {
  filename = "/tmp/tf-09-ex03/greeting.txt"
  content  = "hola\n"
}
```

Apply inicial:

```bash
terraform init
terraform apply -auto-approve
terraform state list
#   local_file.old_name
```

### Paso 2 — rename NAÏVE (sin `moved`)

Edita `main.tf` y renombra el recurso a `new_name`:

```hcl
resource "local_file" "new_name" {
  filename = "/tmp/tf-09-ex03/greeting.txt"
  content  = "hola\n"
}
```

Plan:

```bash
terraform plan
```

Vas a ver:

```
# local_file.new_name will be created
+ resource "local_file" "new_name" { ... }

# local_file.old_name will be destroyed
- resource "local_file" "old_name" { ... }

Plan: 1 to add, 0 to change, 1 to destroy.
```

Para `local_file` no pasa nada; para una base de datos sería un desastre.

### Paso 3 — agregar `moved {}`

Agrega al final de `main.tf`:

```hcl
moved {
  from = local_file.old_name
  to   = local_file.new_name
}
```

Plan de nuevo:

```bash
terraform plan
```

Ahora:

```
Terraform will perform the following actions:

  # local_file.old_name has moved to local_file.new_name
    resource "local_file" "new_name" {
        id = "..."
        # (otros atributos sin cambios)
    }

Plan: 0 to add, 0 to change, 0 to destroy.
```

Y si aplicas:

```bash
terraform apply -auto-approve
terraform state list
#   local_file.new_name
```

El state fue actualizado. La realidad no se tocó. El commit queda en Git como constancia del refactor.

### Paso 4 — propagación y limpieza del bloque

Una vez que el `apply` corrió en TODOS los backends donde ese recurso existía (dev, stg, prod), el bloque `moved` puede eliminarse del código. Mientras alguien no haya aplicado todavía, hay que dejarlo.

## Limpieza

```bash
terraform destroy -auto-approve
rm -rf /tmp/tf-09-ex03
```

## Observación

`moved {}` es equivalente **versionado** de `terraform state mv`. La diferencia operativa es completa:

| | `terraform state mv` | `moved {}` |
|---|---|---|
| Dónde vive | Shell history | Repositorio Git |
| Revisable en PR | No | Sí |
| Reproducible | No | Sí (todos aplican el mismo HCL) |

Regla: siempre `moved`.
