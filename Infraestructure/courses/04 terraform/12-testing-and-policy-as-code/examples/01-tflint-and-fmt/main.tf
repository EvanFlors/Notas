terraform {
  required_version = ">= 1.6.0"
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

# NOTE: intentionally misformatted lines below (extra spaces, misaligned =).
# `terraform fmt -check -diff` should report a diff.
resource "aws_instance" "demo" {
  ami            = "ami-0abcdef1234567890"
  instance_type  =    "t99.huge"           # tflint: this type does not exist
  tags = {
    Name= "demo"
    Env ="dev"
  }
}
