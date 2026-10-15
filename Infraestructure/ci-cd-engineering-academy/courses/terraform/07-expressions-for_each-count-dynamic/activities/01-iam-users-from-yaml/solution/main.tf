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
  users_raw = yamldecode(file("${path.module}/users.yaml"))
  users     = { for u in local.users_raw : u.username => u }
}

resource "local_file" "user" {
  for_each = local.users

  filename        = "${path.module}/out/${each.key}.txt"
  file_permission = "0644"
  content         = <<-EOT
    name=${each.value.name}
    email=${each.value.email}
    role=${each.value.role}
    groups=${join(",", each.value.groups)}
  EOT
}

output "created_users" {
  value = keys(local_file.user)
}
