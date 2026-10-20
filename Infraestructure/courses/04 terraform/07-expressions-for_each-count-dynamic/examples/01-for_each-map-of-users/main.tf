terraform {
  required_version = ">= 1.3.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

resource "local_file" "user" {
  for_each = var.users

  filename        = "${path.module}/out/${each.key}.txt"
  file_permission = "0644"
  content         = <<-EOT
    name=${each.value.name}
    email=${each.value.email}
    groups=${join(",", each.value.groups)}
  EOT
}

output "created_files" {
  value = [for u in local_file.user : u.filename]
}
