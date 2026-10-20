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

# INTENTIONAL misconfigurations for teaching:
#  - no server_side_encryption_configuration
#  - no versioning
#  - no public access block
#  - no access logging
resource "aws_s3_bucket" "bad" {
  bucket = "example-bad-bucket-tf12-demo"
}
