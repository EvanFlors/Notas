resource "random_pet" "codename" {
  length    = 3
  separator = "-"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "null_resource" "log" {
  triggers = {
    pet = random_pet.codename.id
  }
}

resource "local_file" "badge" {
  filename        = "/tmp/tf-02-01-out/${random_pet.codename.id}-${random_string.suffix.result}.txt"
  content         = <<-EOT
    codename: ${random_pet.codename.id}
    suffix:   ${random_string.suffix.result}
    EOT
  file_permission = "0644"
}

output "badge_path" {
  value = local_file.badge.filename
}

output "codename" {
  value = random_pet.codename.id
}
