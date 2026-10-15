#!/usr/bin/env bash
# Solución de referencia para tf-06-01-write-your-first-module.
# NO usamos `set -o pipefail`: pasos posteriores pueden hacer `... | grep -q`
# donde un match temprano produce SIGPIPE (exit 141), lo que pipefail
# marcaría como fallo falso.
set -eu

WORK="/tmp/tf-06-01/greeting-site"
rm -rf "/tmp/tf-06-01"
mkdir -p "$WORK/examples/basic"

# versions.tf del módulo
cat > "$WORK/versions.tf" <<'TF'
terraform {
  required_version = ">= 1.3.0"
  required_providers {
    local  = { source = "hashicorp/local",  version = "~> 2.4" }
    random = { source = "hashicorp/random", version = "~> 3.5" }
  }
}
TF

# variables.tf del módulo
cat > "$WORK/variables.tf" <<'TF'
variable "site_name" {
  type        = string
  description = "Slug kebab-case del sitio (3-40 chars). Se le añade un sufijo random."

  validation {
    condition     = can(regex("^[a-z0-9-]{3,40}$", var.site_name))
    error_message = "site_name debe ser kebab-case, 3-40 chars."
  }
}

variable "base_path" {
  type        = string
  description = "Directorio en el host donde se materializa el sitio."
  default     = "/tmp/tf-06-01/sites"
}

variable "allow_crawlers" {
  type        = bool
  description = "Si true, robots.txt permite crawl. Safe default: false."
  default     = false
}

variable "greeting" {
  type        = string
  description = "Mensaje embebido en el index.html."
  default     = "hello"
}
TF

# main.tf del módulo
cat > "$WORK/main.tf" <<'TF'
resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
  numeric = true
  keepers = {
    name = var.site_name
  }
}

locals {
  full_name = "${var.site_name}-${random_string.suffix.result}"
  site_dir  = "${var.base_path}/${local.full_name}"
}

resource "local_file" "index_html" {
  filename = "${local.site_dir}/index.html"
  content  = "<!doctype html><html><body><h1>${var.greeting}</h1></body></html>\n"
}

resource "local_file" "metadata" {
  filename = "${local.site_dir}/metadata.json"
  content = jsonencode({
    name           = local.full_name
    greeting       = var.greeting
    allow_crawlers = var.allow_crawlers
  })
}

resource "local_file" "robots" {
  filename = "${local.site_dir}/robots.txt"
  content  = var.allow_crawlers ? "User-agent: *\nAllow: /\n" : "User-agent: *\nDisallow: /\n"
}
TF

# outputs.tf del módulo
cat > "$WORK/outputs.tf" <<'TF'
output "site_name_effective" {
  description = "Nombre efectivo con el sufijo random."
  value       = local.full_name
}

output "site_path" {
  description = "Ruta en el host donde vive el sitio."
  value       = local.site_dir
}

output "index_file" {
  description = "Ruta al index.html."
  value       = local_file.index_html.filename
}
TF

# README.md del módulo
cat > "$WORK/README.md" <<'MD'
# Módulo `greeting-site`

> Didáctico. Materializa un "sitio" (index + metadata + robots) con providers `local` y `random`.

## Qué hace

Crea un directorio por sitio con `index.html`, `metadata.json` y `robots.txt`. Añade un sufijo random al nombre para evitar colisiones. Por default **bloquea crawlers** (safe default).

## Uso

```hcl
module "demo" {
  source = "./modules/greeting-site"

  site_name      = "my-demo"
  greeting       = "hola tf-06"
  allow_crawlers = false
}
```

## Inputs

| Nombre | Tipo | Default | Descripción |
|--------|------|---------|-------------|
| `site_name` | string | — | Slug kebab-case, 3-40 chars. |
| `base_path` | string | `/tmp/tf-06-01/sites` | Dónde se materializa. |
| `allow_crawlers` | bool | `false` | Safe default. |
| `greeting` | string | `hello` | Embebido en el H1. |

## Outputs

| Nombre | Descripción |
|--------|-------------|
| `site_name_effective` | Nombre con el sufijo random. |
| `site_path` | Ruta en el host. |
| `index_file` | Ruta al `index.html`. |
MD

# examples/basic
cat > "$WORK/examples/basic/versions.tf" <<'TF'
terraform {
  required_version = ">= 1.3.0"
  required_providers {
    local  = { source = "hashicorp/local",  version = "~> 2.4" }
    random = { source = "hashicorp/random", version = "~> 3.5" }
  }
}
TF

cat > "$WORK/examples/basic/providers.tf" <<'TF'
provider "local" {}
provider "random" {}
TF

cat > "$WORK/examples/basic/main.tf" <<'TF'
module "demo" {
  source = "../.."

  site_name = "my-demo"
  greeting  = "hola tf-06"
}
TF

echo "SETUP OK en $WORK"
echo "Siguiente paso: cd $WORK/examples/basic && terraform init -input=false && terraform validate"
