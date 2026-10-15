terraform {
  required_version = ">= 1.6.0"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "s3" {}
}

resource "random_pet" "demo" {
  length = 2
}

output "pet" {
  value = random_pet.demo.id
}
