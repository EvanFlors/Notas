# State: network (dev). VPC + subnets. Cambia pocas veces al año.
# Expone vpc_id y subnet_ids a los otros states via terraform_remote_state.

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

# Stub mínimo: en un stack real aquí irían aws_vpc, aws_subnet, aws_nat_gateway,
# aws_route_table, etc. Lo dejamos como data para que el ejemplo sea legible.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

output "vpc_id" {
  value = data.aws_vpc.default.id
}

output "subnet_ids" {
  value = data.aws_subnets.default.ids
}
