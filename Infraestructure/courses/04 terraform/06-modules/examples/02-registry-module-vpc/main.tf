# Consumo de un módulo del Terraform Registry.
#
# - source: NAMESPACE/MODULE/PROVIDER
# - version: constraint pessimistic a major (acepta 5.x, rechaza 6.0)
#
# init descarga el módulo a .terraform/modules/vpc/ y lo cachea.
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "tf-06-demo"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  # Safe-ish defaults: NAT Gateway deshabilitado para evitar sorpresas de factura.
  # En un stack real, poner true + single_nat_gateway = true en dev.
  enable_nat_gateway = false

  tags = {
    Env     = "demo"
    Course  = "tf-06"
    Example = "02-registry-module-vpc"
  }
}
