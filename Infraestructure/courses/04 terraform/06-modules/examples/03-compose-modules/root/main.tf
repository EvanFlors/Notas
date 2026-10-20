module "network" {
  source = "../modules/network"
  name   = "demo"
}

module "consumer" {
  source   = "../modules/consumer"
  app_name = "web"

  # Dependencia implícita: Terraform garantiza que network se cree antes.
  vpc_id = module.network.vpc_id
}
