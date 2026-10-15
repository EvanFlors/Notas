# tf-03-01 — Visualiza el DAG implícito

## 1. Identificación

- **ID:** `tf-03-01-dependency-graph-exercise`
- **Tecnología:** terraform
- **Módulo:** `03-resources-data-sources-and-references`
- **Dificultad:** beginner
- **Duración estimada:** 60 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a construir un stack local de **3 recursos interrelacionados**:

- Un `tls_private_key` (par RSA, puro HCL, no toca la red).
- Un `docker_image` (pull de `nginx:1.27-alpine`).
- Un `docker_container` que arranca nginx y recibe, como **variable de entorno**, el *fingerprint* MD5 de la llave pública que generó el `tls_private_key`.

Esa última arista es la que ilustra el modelo: `docker_container` depende de `tls_private_key` **no porque hagamos TLS en nginx**, sino porque pasamos el fingerprint por `env`. Es una referencia de verdad, con un atributo que viaja del padre al hijo. Terraform lo mete en el grafo igual que si fuera un `vpc_id`.

Al terminar visualizarás el DAG (vía `terraform graph` y una versión ASCII en este README), leerás el state y responderás tres preguntas de reflexión.

## 3. Objetivos

- Declarar un stack de 3 recursos cuya dependencia **se exprese toda por referencia** (sin `depends_on`).
- Correr `terraform init / plan / apply / destroy` localmente.
- Obtener el DAG con `terraform graph` y mapearlo a los recursos declarados.
- Leer `terraform state list` y `terraform state show` sobre al menos dos recursos.

## 4. Prerrequisitos

- Conocimientos: `tf-02` completado.
- Software:
  - `terraform` >= 1.5.
  - `docker` >= 20.10 con daemon arriba.
  - `bash`, `grep`, `awk`.
- Puertos: `18081` libre en el host.
- Sin coste.

> Si `docker` o el daemon no están disponibles, el validator saldrá con `SKIP` y no fallará. Pero no podrás terminar la actividad hasta tener Docker.

## 5. Instrucciones

Trabaja en `/tmp/tf-03-01/`. Copia los archivos de `starter/` a ese directorio:

```bash
mkdir -p /tmp/tf-03-01
cp -R starter/. /tmp/tf-03-01/
cd /tmp/tf-03-01
```

El `starter/main.tf` ya tiene:

- El bloque `terraform { required_providers {...} }` con `tls` y `docker`.
- El bloque `provider "docker" {}`.
- Los tres recursos **declarados con huecos marcados con `TODO`**.

Tu trabajo:

### Paso 1 — Rellenar los TODOs del `starter/main.tf`

1. En `docker_container.web`, el campo `name` ya está (`"tf-03-01-web"`). El campo `image` debe referenciar el `image_id` de `docker_image.nginx` (no el string literal).
2. En `docker_container.web`, dentro del bloque `env`, añade una entrada `"KEY_FINGERPRINT=<fingerprint>"` donde `<fingerprint>` viene del atributo `public_key_fingerprint_md5` de `tls_private_key.deploy`.

Pista de sintaxis para la referencia dentro del string:

```hcl
env = ["KEY_FINGERPRINT=${tls_private_key.deploy.public_key_fingerprint_md5}"]
```

El puerto ya está mapeado como `18081:80`.

### Paso 2 — Init / plan / apply

```bash
terraform init
terraform plan      # debe mostrar "Plan: 3 to add, 0 to change, 0 to destroy."
terraform apply -auto-approve
```

### Paso 3 — Inspeccionar el state

```bash
terraform state list
# Esperado:
#   docker_container.web
#   docker_image.nginx
#   tls_private_key.deploy

terraform state show docker_container.web | grep -E '^\s+(name|image|env)'
# Debes ver name, image y env con el fingerprint ya resuelto.

terraform state show tls_private_key.deploy | grep -E '^\s+(algorithm|rsa_bits|public_key_fingerprint_md5)'
```

### Paso 4 — Visualizar el grafo

```bash
terraform graph > graph.dot
head -40 graph.dot
```

Busca aristas (lineas con `->`) entre los tres recursos. En ASCII:

```
    [tls_private_key.deploy]       [docker_image.nginx]
                \                           /
                 v                         v
                   [docker_container.web]
```

Si tienes graphviz instalado:

```bash
dot -Tpng graph.dot -o graph.png
open graph.png   # macOS; en Linux: xdg-open
```

### Paso 5 — Verificar con el validator

```bash
bash tests/validate.sh
# Debe reportar PASS en todos los checks.
```

### Paso 6 — Destroy y limpieza

```bash
terraform destroy -auto-approve
cd ~ && rm -rf /tmp/tf-03-01
```

## 6. Resultado esperado

- `terraform apply` imprime `Apply complete! Resources: 3 added, 0 changed, 0 destroyed.`.
- `terraform state list` lista exactamente los 3 recursos esperados.
- `docker ps --filter name=tf-03-01-web` muestra el contenedor corriendo.
- `curl -s -o /dev/null -w "%{http_code}" http://localhost:18081` devuelve `200`.
- `tests/validate.sh` reporta todos los checks en `OK`.

## 7. Criterios de aceptación

- Las tres dependencias del grafo se expresan por **referencia**: no hay un solo `depends_on` en tu `main.tf`.
- La variable `KEY_FINGERPRINT` en el contenedor contiene un valor real (no un string vacío ni un placeholder) tras el `apply`.
- `terraform destroy` elimina los 3 recursos en orden inverso sin errores.
- Puedes dibujar el DAG en una servilleta sin consultar `terraform graph`.

## 8. Validación

```bash
bash tests/validate.sh
```

El script:

1. Verifica que existan `terraform` y `docker` (SKIP amigable si falta alguno).
2. Corre `terraform init && plan && apply` sobre `/tmp/tf-03-01/`.
3. Comprueba que el state liste los 3 recursos.
4. Comprueba que el contenedor esté arriba y responda `HTTP 200` en `18081`.
5. Comprueba que la env `KEY_FINGERPRINT` del contenedor **no esté vacía** y no contenga `${` (sería un string sin interpolar).
6. Comprueba que `main.tf` **no contenga** `depends_on` (la gracia del ejercicio es que todo sea implícito).
7. Hace `terraform destroy -auto-approve` y limpia.

## 9. Preguntas de reflexión

Responde en 3-5 líneas cada una (puedes anotarlas al final de tu `main.tf` como comentario `#`):

1. ¿En qué orden crea Terraform los 3 recursos? ¿Alguno se crea en paralelo con otro? ¿Por qué?
2. Si borraras la línea `env = [...]` del contenedor, ¿cambiaría el grafo? Dibújalo en ASCII antes y después.
3. ¿Qué pasaría si en vez de `image = docker_image.nginx.image_id` escribieras `image = "nginx:1.27-alpine"` (literal)? El `apply` funcionaría igual — ¿qué pierdes?

## 10. Extensiones

- **E1:** añade un segundo `docker_container` que use la misma imagen pero puerto `18082`. ¿Cuántas aristas tiene ahora el DAG? ¿Se crean los dos contenedores en paralelo?
- **E2:** sustituye el `tls_private_key` por un `tls_self_signed_cert` que firme con esa misma llave privada. Observa cómo crece el grafo (y como no necesitas `depends_on`).
- **E3:** destruye solo el contenedor con `terraform destroy -target=docker_container.web` y comenta por qué `-target` es un *escape hatch* peligroso en producción (ver `tf-10`).

## 11. Limpieza

```bash
cd /tmp/tf-03-01 2>/dev/null && terraform destroy -auto-approve || true
docker rm -f tf-03-01-web >/dev/null 2>&1 || true
cd ~ && rm -rf /tmp/tf-03-01
```
