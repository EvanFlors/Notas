# Ejemplo 02 — Contenedor Docker vía Terraform

## Concepto que demuestra

- Terraform como "cliente HTTP" del daemon de Docker a través del provider `kreuzwerker/docker`.
- Dos recursos (`docker_image` → `docker_container`) con una única arista implícita.
- Diferencia visual, en el state, entre lo que Terraform **pidió** y lo que el daemon **devolvió**.
- Orden de destroy: inverso al create.

## Contexto

En `dkr-02` ya corriste `docker run -d -p 8080:80 nginx:alpine` desde la CLI. Aquí haces lo mismo, pero **declarativamente**: no describes acciones, describes el estado deseado. Terraform traduce ese estado a llamadas al daemon.

## Objetivo

Al terminar sabrás:

- Declarar `docker_image` y `docker_container` enlazados por referencia.
- Entender por qué `image = docker_image.nginx.image_id` (y no `image = "nginx:1.27-alpine"`) es la forma correcta de ligar los dos recursos.
- Interpretar el state de un contenedor y distinguir campos que escribiste de campos que te devolvió el daemon.

## Prerrequisitos

- `terraform` >= 1.5.
- `docker` ≥ 20.10, con **daemon arriba** (`docker info` responde). En macOS puede ser Docker Desktop, colima u OrbStack; en Linux `dockerd` nativo o rootless.
- Puerto 18080 libre en el host.
- Sin coste (todo local).

## Código

Guarda esto en `/tmp/tf-03-ex02/main.tf`:

```hcl
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
  keep_locally = false   # borra la imagen al destroy del recurso
}

resource "docker_container" "web" {
  name  = "tf-03-ex02-web"
  image = docker_image.nginx.image_id   # arista implícita

  ports {
    internal = 80
    external = 18080
  }
}

output "container_ip" {
  value = docker_container.web.network_data[0].ip_address
}
```

## Ejecución

```bash
mkdir -p /tmp/tf-03-ex02 && cd /tmp/tf-03-ex02
# ... copia aquí el main.tf de arriba ...

terraform init
#   Descarga kreuzwerker/docker a .terraform/providers/

terraform plan
#   Verás:
#
#   # docker_image.nginx will be created
#     + id           = (known after apply)
#     + image_id     = (known after apply)
#     + name         = "nginx:1.27-alpine"
#     + keep_locally = false
#
#   # docker_container.web will be created
#     + name       = "tf-03-ex02-web"
#     + image      = (known after apply)      # <-- depende de docker_image.nginx
#     + id         = (known after apply)
#     + ip_address = (known after apply)
#     ...
#
#   Plan: 2 to add, 0 to change, 0 to destroy.

terraform apply -auto-approve
#   Pasos reales:
#     1. docker_image.nginx: provider llama a `docker pull nginx:1.27-alpine`.
#     2. docker_container.web: provider llama a `docker create` + `docker start`.
#   Ambas llamadas van al daemon vía el socket Unix.

# Verifica que el contenedor está vivo.
docker ps --filter name=tf-03-ex02-web
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:18080

terraform state list
# docker_container.web
# docker_image.nginx

terraform state show docker_container.web | head -30
#   Verás que escribiste: name, image, ports.
#   Rellenó el daemon/provider: id, hostname, entrypoint, env (defaults de nginx),
#   ip_address, network_data, bridge, log_driver, cgroupns_mode, pid_mode, ...
```

### Visualizar el DAG

```bash
terraform graph > graph.dot
```

ASCII equivalente:

```
   [docker_image.nginx]
            |
            v
   [docker_container.web]
```

### Destroy (orden inverso)

```bash
terraform destroy -auto-approve
#   1. docker_container.web se detiene y elimina (docker rm -f).
#   2. docker_image.nginx se elimina del cache local (docker rmi), porque keep_locally=false.
```

## Preguntas de reflexión

1. ¿Qué pasaría si en `image = ...` escribieras el literal `"nginx:1.27-alpine"` en vez de `docker_image.nginx.image_id`? Pista: el contenedor arrancaría igual, pero la arista del grafo desaparece. ¿Qué problema trae eso si cambias la versión de la imagen?
2. Si `keep_locally = true`, ¿qué cambia en el `destroy`? ¿Qué queda en tu disco?
3. Al mirar `terraform state show docker_container.web`, verás el campo `env` lleno con valores que **tú no escribiste**. ¿De dónde vienen?
4. Si otro proceso borra el contenedor por fuera (`docker rm -f tf-03-ex02-web`), ¿qué muestra el siguiente `terraform plan`? ¿Es el mismo output que si no hubiera cambiado nada?

## Limpieza

```bash
terraform destroy -auto-approve
cd ~ && rm -rf /tmp/tf-03-ex02
```
