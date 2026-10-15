# Ejemplo 01 — `create_before_destroy` con nombre derivado

## Concepto que demuestra

- Un recurso con **nombre único** (unicidad global) que, al cambiarse "en caliente", normalmente causaría downtime porque TF destruye antes de crear.
- `lifecycle { create_before_destroy = true }` invierte el orden.
- **Pero** si el nombre es fijo, el reemplazo colisiona consigo mismo y el `create` falla. La solución es un **nombre derivado** (random suffix, timestamp, prefix).

Usamos `local_file` (sin coste, sin cloud) como stand-in de un "balanceador con nombre único". El archivo del disco es el "recurso con nombre único".

## Prerrequisitos

- Terraform ≥ 1.5 **o** OpenTofu ≥ 1.6. Verifica: `terraform version` o `tofu version`.
- Permiso de escritura en `/tmp/`.

> En el resto del ejemplo usamos `terraform`. Si tienes `tofu`, sustituye el comando.

## Ejecución

```bash
# 0. Entorno limpio
rm -rf /tmp/tf-09-ex01 && mkdir -p /tmp/tf-09-ex01 && cd /tmp/tf-09-ex01
```

Crea `main.tf`:

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    local  = { source = "hashicorp/local",  version = "~> 2.5" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

# "Versión" del archivo. Cambiar este valor fuerza reemplazo.
variable "version_label" {
  type    = string
  default = "v1"
}

# Sufijo random atado a version_label. Al cambiar el label, cambia el sufijo
# y por lo tanto el filename -> no colisiona en create_before_destroy.
resource "random_id" "suffix" {
  byte_length = 2
  keepers = {
    version_label = var.version_label
  }
}

resource "local_file" "lb" {
  # Nombre DERIVADO. Si fuera fijo ("/tmp/tf-09-ex01/lb.conf"), el reemplazo
  # con create_before_destroy colisionaría consigo mismo.
  filename = "/tmp/tf-09-ex01/lb-${random_id.suffix.hex}.conf"
  content  = "listener=${var.version_label}\n"

  lifecycle {
    create_before_destroy = true
  }
}

output "lb_file" {
  value = local_file.lb.filename
}
```

Primer apply:

```bash
terraform init
terraform apply -auto-approve
ls -1 /tmp/tf-09-ex01/
```

Verás un archivo tipo `lb-abcd.conf`.

Ahora **cambia la versión**, lo que fuerza reemplazo:

```bash
terraform apply -auto-approve -var 'version_label=v2'
ls -1 /tmp/tf-09-ex01/
```

En el plan verás:

```
# local_file.lb must be replaced
+/- resource "local_file" "lb" { ... }
```

El símbolo `+/-` (en vez de `-/+`) indica que **primero crea el nuevo y después destruye el viejo** — eso es `create_before_destroy` en acción. Si miras el `ls`, verás que, durante el apply, los dos archivos coexisten brevemente.

## Qué pasa si el nombre fuera fijo

Edita `filename` a algo fijo:

```hcl
filename = "/tmp/tf-09-ex01/lb.conf"
```

(y elimina el `random_id` y su interpolación). Vuelve a aplicar y cambia el `content`:

```bash
terraform apply -auto-approve
# edita main.tf cambiando content a "listener=v3\n"
terraform apply -auto-approve
```

Para `local_file` esto no colisiona porque el provider sobrescribe el archivo. Pero para un `aws_lb` con `name = "prod-lb"`, el `create` fallaría con "ya existe un LB con ese nombre". Esa es la trampa: `create_before_destroy` requiere que no haya restricción de unicidad entre viejo y nuevo.

## Limpieza

```bash
terraform destroy -auto-approve -var 'version_label=v2'
rm -rf /tmp/tf-09-ex01
```

## Observación

Mira el símbolo del plan:

- `-/+` → **primero destruye**, después crea. Downtime posible.
- `+/-` → **primero crea**, después destruye. Sin downtime, si la unicidad lo permite.

Esos dos caracteres son el valor completo del ejemplo.
