# State: platform (dev). Cluster + addons. Depende de network.

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {}
}

provider "aws" {
  region = "us-east-1"
}

# Lee outputs del state 'network'.
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "acme-tf-state-dev"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}

# Stub: en un stack real aquí vendría aws_eks_cluster + addons.
output "vpc_id_consumed" {
  value = data.terraform_remote_state.network.outputs.vpc_id
}
