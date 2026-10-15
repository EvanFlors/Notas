terraform {
  required_version = ">= 1.5.0"
  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

# El provider github usa GITHUB_TOKEN del entorno.
provider "github" {}

# --- Recurso 1: par de llaves generado localmente, sin red. ---
resource "tls_private_key" "deploy" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# --- Recurso 2: repo privado en GitHub. ---
resource "github_repository" "demo" {
  name        = "tf-03-demo"
  description = "Demo repo for tf-03 (safe to delete)"
  visibility  = "private"
  auto_init   = true
}

# --- Recurso 3: deploy key que ata los dos anteriores. ---
#     Dependencias implícitas via las dos referencias de abajo.
resource "github_repository_deploy_key" "demo" {
  title      = "ci-key"
  repository = github_repository.demo.name
  key        = tls_private_key.deploy.public_key_openssh
  read_only  = true
}

output "deploy_key_fingerprint" {
  value = tls_private_key.deploy.public_key_fingerprint_md5
}
