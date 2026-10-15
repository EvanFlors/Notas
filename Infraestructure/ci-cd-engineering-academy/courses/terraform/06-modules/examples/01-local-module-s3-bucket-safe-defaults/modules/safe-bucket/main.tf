# Sufijo random determinista por el nombre lógico: evita colisiones y
# ejemplifica cómo un módulo genera outputs no derivables de los inputs.
resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
  numeric = true

  keepers = {
    name = var.name
  }
}

locals {
  full_name   = "${var.name}-${random_string.suffix.result}"
  bucket_path = "${var.base_path}/${local.full_name}"
}

# Marcador "el bucket existe": en real sería aws_s3_bucket.
resource "local_file" "bucket_marker" {
  filename = "${local.bucket_path}/.bucket"
  content  = "name=${local.full_name}\ncreated_by=safe-bucket module\n"
}

# "Versioning habilitado": en real sería aws_s3_bucket_versioning.
resource "local_file" "versioning_marker" {
  count    = var.versioning_enabled ? 1 : 0
  filename = "${local.bucket_path}/.versions/.keep"
  content  = "versioning enabled\n"
}

# "Encryption habilitado": en real sería aws_s3_bucket_server_side_encryption_configuration.
resource "local_file" "encryption_marker" {
  count    = var.encryption_enabled ? 1 : 0
  filename = "${local.bucket_path}/.encryption-enabled"
  content  = "sse=AES256\n"
}

# Access log: en real sería aws_s3_bucket_logging.
resource "local_file" "access_log" {
  count    = var.access_log_enabled ? 1 : 0
  filename = "${local.bucket_path}/access.log"
  content  = ""
}

# Tags "materializados" como JSON.
resource "local_file" "tags" {
  filename = "${local.bucket_path}/tags.json"
  content  = jsonencode(merge({ "ManagedBy" = "terraform" }, var.tags))
}
