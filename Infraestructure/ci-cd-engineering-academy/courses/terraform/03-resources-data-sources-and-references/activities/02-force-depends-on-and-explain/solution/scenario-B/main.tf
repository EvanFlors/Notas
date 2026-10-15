terraform {
  required_version = ">= 1.5.0"
  required_providers {
    null   = { source = "hashicorp/null",     version = "~> 3.0" }
    docker = { source = "kreuzwerker/docker", version = "~> 3.0" }
  }
}

provider "docker" {}

resource "null_resource" "marker" {
  provisioner "local-exec" {
    command = "mkdir -p /tmp/tf-03-02 && echo 'ready' > /tmp/tf-03-02/scenario-B-marker.txt"
  }

  triggers = {
    once = "v1"
  }
}

resource "docker_image" "alpine" {
  name         = "alpine:3.20"
  keep_locally = false
}

resource "docker_container" "app" {
  name    = "tf-03-02-app"
  image   = docker_image.alpine.image_id
  command = ["sh", "-c", "cat /data/marker && sleep 30"]

  volumes {
    host_path      = "/tmp/tf-03-02/scenario-B-marker.txt"
    container_path = "/data/marker"
    read_only      = true
  }

  # depends_on NECESARIO: host_path es un string literal, no referencia atributo
  # alguno de null_resource.marker, por lo que Terraform no infiere la arista.
  # Sin esto, el contenedor podria crearse ANTES de que el provisioner escriba
  # el marker en disco; el bind mount fallaria o montaria un dir vacio creado
  # por Docker.
  depends_on = [null_resource.marker]
}
