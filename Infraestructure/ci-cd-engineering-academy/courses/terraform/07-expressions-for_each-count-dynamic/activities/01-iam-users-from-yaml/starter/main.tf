terraform {
  required_version = ">= 1.3.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

locals {
  # TODO 1: carga users.yaml y conviértelo a un map keyed por username.
  # Pista:
  #   users_raw = yamldecode(file("${path.module}/users.yaml"))
  #   users     = { for u in local.users_raw : u.username => u }
  users_raw = []  # <--- reemplazar
  users     = {}  # <--- reemplazar
}

# TODO 2: declara el recurso local_file.user con for_each sobre local.users.
# Cada archivo debe:
#   - llamarse  "${path.module}/out/${each.key}.txt"
#   - contener  name=..., email=..., role=..., groups=... (join con coma)
#
# resource "local_file" "user" {
#   for_each = ...
#   filename = ...
#   content  = ...
# }

# TODO 3: declara un output "created_users" con las claves del map resultante.
# output "created_users" {
#   value = ...
# }
