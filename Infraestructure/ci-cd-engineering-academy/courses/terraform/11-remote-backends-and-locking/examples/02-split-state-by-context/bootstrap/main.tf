# Bootstrap one-shot: crea el bucket de state y la tabla de lock del entorno dev.
# Se corre UNA VEZ, con backend local, antes de que los otros stacks puedan
# apuntar a este backend remoto. En producción vive en un repo aparte o en una
# carpeta /bootstrap que casi nadie toca.

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # backend local a propósito: el bucket aún no existe.
}

provider "aws" {
  region = "us-east-1"
}

variable "env" {
  type    = string
  default = "dev"
}

locals {
  bucket_name = "acme-tf-state-${var.env}"
  table_name  = "acme-tf-lock-${var.env}"
}

resource "aws_s3_bucket" "state" {
  bucket = local.bucket_name
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "lock" {
  name         = local.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}

output "bucket" {
  value = aws_s3_bucket.state.bucket
}

output "table" {
  value = aws_dynamodb_table.lock.name
}
