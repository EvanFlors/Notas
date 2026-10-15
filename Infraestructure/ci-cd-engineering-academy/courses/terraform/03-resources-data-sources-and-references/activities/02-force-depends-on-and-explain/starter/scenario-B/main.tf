terraform {
  required_version = ">= 1.5.0"
  required_providers {
    null   = { source = "hashicorp/null",       version = "~> 3.0" }
    docker = { source = "kreuzwerker/docker",   version = "~> 3.0" }
  }
}

provider "docker" {}

# Prerequisito operacional: un archivo marker que debe existir en el host
# ANTES de que el contenedor se cree. En el mundo real sería "una política IAM
# aplicada", "un paquete instalado", "un namespace creado", etc.
resource "null_resource" "marker" {
  provisioner "local-exec" {
    command = "mkdir -p /tmp/tf-03-02 && echo 'ready' > /tmp/tf-03-02/scenario-B-marker.txt"
  }

  # Trigger constante: el provisioner solo corre al create. Si quieres forzarlo
  # a correr de nuevo, cambia este valor.
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
    # Nota: host_path es un string LITERAL — NO referencia null_resource.marker.
    # Resultado: Terraform no sabe que esto depende del null_resource.
    host_path      = "/tmp/tf-03-02/scenario-B-marker.txt"
    container_path = "/data/marker"
    read_only      = true
  }

  # TODO: añade aquí un depends_on necesario, con comentario que lo justifique.
  # Sin él, en un primer apply el contenedor puede crearse ANTES del marker
  # y fallar al montar el bind (o montar un directorio vacío creado por Docker).
}
