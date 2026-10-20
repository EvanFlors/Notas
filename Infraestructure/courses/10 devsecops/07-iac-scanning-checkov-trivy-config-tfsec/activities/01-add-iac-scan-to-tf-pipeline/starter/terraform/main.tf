// Terraform HCL only — NEVER run `terraform apply` for this activity.
// Intentional misconfigs so Checkov has something to flag.

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

// --- Misconfig 1: public S3 bucket (CKV_AWS_20) ---
resource "aws_s3_bucket" "public_data" {
  bucket = "example-sec-07-public-data"
}

resource "aws_s3_bucket_acl" "public_data" {
  bucket = aws_s3_bucket.public_data.id
  acl    = "public-read"
}

// --- Misconfig 2: wildcard IAM policy (CKV_AWS_1 / CKV_AWS_40) ---
resource "aws_iam_policy" "wide_open" {
  name = "wide_open"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = "*",
      Resource = "*"
    }]
  })
}

// --- Misconfig 3: SSH from 0.0.0.0/0 (CKV_AWS_24) ---
resource "aws_security_group" "open_ssh" {
  name        = "open-ssh"
  description = "demo"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
