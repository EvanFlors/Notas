terraform {
  required_version = ">= 1.3.0"
  required_providers {
    local = { source = "hashicorp/local", version = "~> 2.5" }
  }
}

# ANTI-PATRÓN DIDÁCTICO: count sobre una lista con identidad.
# Reordenar o eliminar en el medio causa cascada de replace+destroy.
resource "local_file" "user" {
  count = length(var.users)

  filename        = "${path.module}/out/${count.index}-${var.users[count.index]}.txt"
  file_permission = "0644"
  content         = "name=${var.users[count.index]}\n"
}

output "addresses" {
  value = [for i in range(length(var.users)) : "local_file.user[${i}]"]
}
