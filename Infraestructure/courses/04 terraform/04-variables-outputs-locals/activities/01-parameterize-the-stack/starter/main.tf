# STARTER: hard-coded. Tu trabajo es parametrizarlo con variables + locals.
# Cuando termines, aquí NO debería aparecer ningún literal "dev", "prod" ni
# "payments_api".

resource "tls_private_key" "keys" {
  count = 1

  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_file" "manifest" {
  filename        = "${path.module}/out/payments_api-dev.txt"
  file_permission = "0644"
  content         = <<-EOT
    project         = payments_api
    environment     = dev
    key_count       = 1
    rsa_bits        = 2048
    effective_tags  = {"environment":"dev","project":"payments_api","managed_by":"terraform"}
  EOT
}
