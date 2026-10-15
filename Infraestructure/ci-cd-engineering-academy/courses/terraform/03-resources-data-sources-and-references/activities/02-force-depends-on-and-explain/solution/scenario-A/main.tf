terraform {
  required_version = ">= 1.5.0"
  required_providers {
    tls    = { source = "hashicorp/tls",      version = "~> 4.0" }
    docker = { source = "kreuzwerker/docker", version = "~> 3.0" }
  }
}

provider "docker" {}

resource "tls_private_key" "deploy" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "srv" {
  private_key_pem = tls_private_key.deploy.private_key_pem

  subject {
    common_name  = "tf-03-02.local"
    organization = "Academy"
  }

  validity_period_hours = 24
  allowed_uses          = ["server_auth"]
}

resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = false
}

resource "docker_container" "nginx" {
  name  = "tf-03-02-nginx"
  image = docker_image.nginx.image_id

  env = [
    # La referencia a tls_self_signed_cert.srv.subject[0].common_name
    # YA crea la arista implícita cert -> container en el DAG.
    "CERT_SUBJECT=${tls_self_signed_cert.srv.subject[0].common_name}",
  ]

  ports {
    internal = 80
    external = 18082
  }
}
