# Starter stack for tf-05-02-inspect-state-of-a-provisioned-stack.
# Didactic providers only — no cloud, no cost.

resource "random_pet" "animal" {
  length    = 3
  separator = "_"
}

resource "random_integer" "port" {
  min = 10000
  max = 20000
}

# Didactic only. Do NOT use random_password for real secrets management.
resource "random_password" "admin" {
  length           = 20
  special          = true
  override_special = "!@#%&*"
}

resource "local_file" "config" {
  filename = "${path.module}/app.ini"
  content  = <<-EOT
    [service]
    name = ${random_pet.animal.id}
    port = ${random_integer.port.result}

    [admin]
    password = ${random_password.admin.result}
  EOT

  file_permission = "0600"
}

output "service_name" {
  description = "Non-sensitive output: safe to show in CLI."
  value       = random_pet.animal.id
}

output "admin_password" {
  description = "Marked sensitive: hidden by CLI, still cleartext in state."
  value       = random_password.admin.result
  sensitive   = true
}
