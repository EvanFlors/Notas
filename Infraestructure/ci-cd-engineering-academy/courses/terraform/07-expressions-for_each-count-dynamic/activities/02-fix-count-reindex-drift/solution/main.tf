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
  # Lista de objetos -> map keyed por name (clave estable del dominio).
  items_by_name = { for i in var.items : i.name => i }
}

resource "local_file" "item" {
  for_each = local.items_by_name

  filename        = "${path.module}/out/${each.key}.txt"
  file_permission = "0644"
  content         = <<-EOT
    name=${each.value.name}
    tier=${each.value.tier}
  EOT
}

output "created" {
  value = keys(local_file.item)
}
