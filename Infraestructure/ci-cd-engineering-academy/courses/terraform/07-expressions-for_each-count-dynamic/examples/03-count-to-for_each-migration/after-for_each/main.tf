terraform {
  required_version = ">= 1.3.0"
  required_providers {
    local = { source = "hashicorp/local", version = "~> 2.5" }
  }
}

# PATRÓN CORRECTO: for_each con toset() usa el nombre como clave estable.
# Eliminar un elemento del medio NO toca a los demás.
resource "local_file" "user" {
  for_each = toset(var.users)

  filename        = "${path.module}/out/${each.key}.txt"
  file_permission = "0644"
  content         = "name=${each.key}\n"
}

output "addresses" {
  value = [for k in sort(tolist(toset(var.users))) : "local_file.user[\"${k}\"]"]
}
