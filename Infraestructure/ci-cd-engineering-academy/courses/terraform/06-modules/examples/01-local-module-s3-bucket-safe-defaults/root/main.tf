module "logs_bucket" {
  source = "../modules/safe-bucket"

  name = "logs"
  tags = {
    Env   = "dev"
    Owner = "tf-06-example"
  }
}

module "artifacts_bucket" {
  source = "../modules/safe-bucket"

  name               = "artifacts"
  access_log_enabled = false

  tags = {
    Env     = "dev"
    Purpose = "ci-artifacts"
  }
}
