terraform {
  required_version = ">= 1.3.0"
  required_providers {
    random = { source = "hashicorp/random", version = "~> 3.6" }
    local  = { source = "hashicorp/local",  version = "~> 2.5" }
  }
  backend "local" {
    path = "terraform.tfstate"
  }
}
