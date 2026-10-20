terraform {
  required_version = ">= 1.5.0"
  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

resource "tls_private_key" "deploy" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = false
}

resource "docker_container" "web" {
  name  = "tf-03-01-web"
  image = docker_image.nginx.image_id

  env = [
    "KEY_FINGERPRINT=${tls_private_key.deploy.public_key_fingerprint_md5}",
  ]

  ports {
    internal = 80
    external = 18081
  }
}
