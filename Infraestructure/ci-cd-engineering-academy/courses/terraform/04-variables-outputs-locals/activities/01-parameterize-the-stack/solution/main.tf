locals {
  name_prefix = "${var.project}-${var.environment}"

  base_tags = {
    environment = var.environment
    project     = var.project
    managed_by  = "terraform"
  }
  effective_tags = merge(local.base_tags, var.tags)
}

resource "tls_private_key" "keys" {
  count = var.key_count

  algorithm = "RSA"
  rsa_bits  = var.rsa_bits
}

resource "local_file" "manifest" {
  filename        = "${path.module}/out/${local.name_prefix}.txt"
  file_permission = "0644"
  content         = <<-EOT
    project         = ${var.project}
    environment     = ${var.environment}
    key_count       = ${var.key_count}
    rsa_bits        = ${var.rsa_bits}
    effective_tags  = ${jsonencode(local.effective_tags)}
  EOT
}
