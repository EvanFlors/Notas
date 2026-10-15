#!/usr/bin/env bash
# Scaffolding for tf-13-02-opentofu-eval.
# NOTE: no `set -o pipefail` to avoid SIGPIPE false positives from grep -q
# producers used later in validators.
set -eu

BASE="${1:-/tmp/tf-tofu-eval}"
rm -rf "$BASE"
mkdir -p "$BASE/project/stack" "$BASE/project/evidence" "$BASE/project/adr"

cat > "$BASE/project/stack/main.tf" <<'HCL'
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

resource "random_pet" "name" {
  length    = 2
  separator = "-"
}

resource "local_file" "greeting" {
  filename = "${path.module}/greeting.txt"
  content  = "hello, ${random_pet.name.id}\n"
}

output "pet" {
  value = random_pet.name.id
}
HCL

cat > "$BASE/project/README.md" <<'EOF'
# OpenTofu evaluation — starter (tf-13-02)

Tareas:
1. Instalar `tofu` (brew install opentofu / https://opentofu.org/docs/intro/install/).
2. Ejecutar los pasos de evidencia (ver tests/validate.sh y el README de la actividad).
3. Depositar las salidas en evidence/.
4. Escribir adr/0001-terraform-vs-opentofu.md.

Validar:
  bash tests/validate.sh /tmp/tf-tofu-eval
EOF

echo "Scaffolding ready at $BASE/project/"
find "$BASE/project" -type f | sort
