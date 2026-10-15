resource "random_id" "vpc" {
  byte_length = 4
  keepers = {
    name = var.name
  }
}

locals {
  vpc_id = "vpc-${random_id.vpc.hex}"
}

resource "local_file" "network_json" {
  filename = "${var.base_path}/${var.name}/network.json"
  content = jsonencode({
    name   = var.name
    vpc_id = local.vpc_id
    cidr   = "10.0.0.0/16"
  })
}
