terraform {
  required_version = ">= 1.5.0"
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = false
}

resource "docker_container" "web" {
  name  = "tf-03-ex02-web"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = 18080
  }
}

output "container_ip" {
  value = docker_container.web.network_data[0].ip_address
}
