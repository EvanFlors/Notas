terraform {
  required_version = ">= 1.3.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

# ===== ANTI-PATRÓN DIDÁCTICO: cambiar a for_each =====
# Este stack usa `count` sobre una lista de objetos con identidad propia.
# Al eliminar un elemento del medio, Terraform reindexa y planea
# destruir+recrear los que vinieron después.
#
# Tu tarea (ver README): refactorizarlo a for_each con claves estables.
resource "local_file" "item" {
  count = length(var.items)

  filename        = "${path.module}/out/${count.index}-${var.items[count.index].name}.txt"
  file_permission = "0644"
  content         = <<-EOT
    name=${var.items[count.index].name}
    tier=${var.items[count.index].tier}
  EOT
}

output "created" {
  value = local_file.item[*].filename
}
