terraform {
  required_version = ">= 1.6.0"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # TODO Paso 3: descomenta el backend una vez hecho el bootstrap.
  # backend "s3" {}
}

resource "random_pet" "demo" {
  length = 2
}

output "pet" {
  value = random_pet.demo.id
}
