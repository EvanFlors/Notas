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

# --- Recurso 1: par de llaves RSA generado en memoria (no toca la red). ---
resource "tls_private_key" "deploy" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# --- Recurso 2: imagen nginx cacheada en el daemon local. ---
resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = false
}

# --- Recurso 3: contenedor que arranca nginx y recibe el fingerprint por env. ---
resource "docker_container" "web" {
  name = "tf-03-01-web"

  # TODO (paso 1): referencia el atributo image_id del recurso de imagen
  # (ver README). Reemplaza el null por la referencia correcta.
  image = null  # <-- cámbialo

  # TODO (paso 2): dentro del list env, interpola el fingerprint MD5
  # de la clave pública que generó tls_private_key.deploy.
  # Formato esperado: "KEY_FINGERPRINT=aa:bb:cc:..."
  env = []  # <-- rellénalo

  ports {
    internal = 80
    external = 18081
  }
}
