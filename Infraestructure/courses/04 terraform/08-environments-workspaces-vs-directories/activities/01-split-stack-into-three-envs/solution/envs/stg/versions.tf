terraform {
  required_version = ">= 1.3.0"
  backend "local" {
    path = "terraform.tfstate"
  }
}
