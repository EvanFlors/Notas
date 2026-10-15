# State: app-payments (dev). Microservicio. Depende de network y platform.

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

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "acme-tf-state-dev"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "platform" {
  backend = "s3"
  config = {
    bucket = "acme-tf-state-dev"
    key    = "platform/terraform.tfstate"
    region = "us-east-1"
  }
}

# Stub: en un stack real aquí irían aws_lb_target_group, aws_iam_role del pod,
# kubernetes_deployment, etc.
output "wiring_ok" {
  value = {
    vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
    platform_in = data.terraform_remote_state.platform.outputs.vpc_id_consumed
  }
}
