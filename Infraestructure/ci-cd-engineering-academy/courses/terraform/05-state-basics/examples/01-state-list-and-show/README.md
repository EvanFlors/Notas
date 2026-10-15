# Ejemplo 01 — `terraform state list` y `terraform state show`

## Concepto que demuestra

Cómo recorrer un state de Terraform con los dos comandos de inspección fundamentales: **`terraform state list`** (lista las *addresses* de todos los recursos) y **`terraform state show <address>`** (imprime los atributos conocidos de un recurso).

## Contexto

En cualquier incidente operacional ("¿por qué el plan quiere destruir esto?", "¿cuál es la IP de la DB?", "¿este recurso está realmente gestionado por este stack?") el primer reflejo es `terraform state list | grep ...` seguido de `terraform state show <address>`. Dominar estos dos comandos es la base para no abrir el `.tfstate` con un editor.

## Objetivo

Al terminar sabrás:

- Listar todas las addresses del state.
- Mostrar los atributos de un recurso concreto, incluidos los **computados** por el provider.
- Diferenciar `state list` (barato, local) de abrir el JSON (verboso, propenso a errores).
- Correlacionar los `instances[]` del JSON con las entradas de `state list`.

## Prerrequisitos

- Terraform ≥ 1.5 instalado (`terraform version`).
- Shell Bash o equivalente.
- `/tmp/` escribible.
- Sin coste, sin cloud (`random`, `local`).

## Archivos de este ejemplo

Están en `files/`:

- `versions.tf` — pin de versiones de providers.
- `main.tf` — tres recursos: `random_pet`, `random_integer`, `local_file`.

## Ejecución

Copia el stack a `/tmp/` y síguelo paso a paso. **Lee la salida antes del siguiente comando.**

```bash
# Preparar
WORK=/tmp/tf-05-ex01
rm -rf "$WORK" && mkdir -p "$WORK"
cp -R files/. "$WORK/"
cd "$WORK"

# 1) Ciclo normal
terraform init
terraform apply -auto-approve

# 2) Listar addresses
terraform state list
# random_integer.port
# random_pet.greeting
# local_file.hello

# 3) Mostrar un recurso
terraform state show random_pet.greeting
# # random_pet.greeting:
# resource "random_pet" "greeting" {
#     id        = "funny-rabbit"
#     length    = 2
#     separator = "-"
# }

terraform state show random_integer.port
# # random_integer.port:
# resource "random_integer" "port" {
#     id     = "12345"
#     max    = 65535
#     min    = 1024
#     result = 12345
# }

terraform state show local_file.hello
# # local_file.hello:
# resource "local_file" "hello" {
#     content              = "hola funny-rabbit en puerto 12345\n"
#     content_base64sha256 = "..."
#     content_base64sha512 = "..."
#     content_md5          = "..."
#     content_sha1         = "..."
#     content_sha256       = "..."
#     content_sha512       = "..."
#     directory_permission = "0777"
#     file_permission      = "0777"
#     filename             = "/tmp/tf-05-ex01/hello.txt"
#     id                   = "..."
# }

# 4) El state crudo (solo para interiorizar — en el día a día NO)
head -40 terraform.tfstate

# 5) Jq amigable
command -v jq >/dev/null && jq '.resources[] | {type, name, attrs: .instances[0].attributes}' terraform.tfstate
```

## Resultado esperado

- `terraform state list` imprime 3 addresses: `random_integer.port`, `random_pet.greeting`, `local_file.hello`.
- `terraform state show` imprime, por recurso, **todos los atributos conocidos**, incluidos los **computados** por el provider (`id`, `result`, los `content_sha*` del `local_file`, etc.) que **no** escribiste en el HCL.
- `terraform.tfstate` existe en el directorio y es JSON legible.

## Interpretación

- `state list` responde "¿qué hay bajo gestión de este stack?". Es la primera consulta en 9 de cada 10 debugging sessions.
- `state show` responde "¿qué sabe Terraform de este recurso específico?". Es tu lupa.
- Los atributos **computados** (`id`, `result`, hashes) son los que *solo existen tras `apply`*. El HCL no los pone — el provider los devuelve y Terraform los guarda en el state. Por eso el state es necesario: sin él, un `plan` posterior no tendría forma de saber si el `id` cambió.
- El `local_file.content` del state muestra el contenido literal del archivo. Esto importa: cualquier cosa que pase por un `local_file.content` o un `random_password.result` **vive en claro en el `.tfstate`**.

## Errores frecuentes

- **"No state file found"**: olvidaste `terraform apply` antes de `state list`.
- **`state show <address>` dice "No instance found"**: la address está mal escrita (atención a `module.X.<type>.<name>`, `[idx]` en `count`, `["key"]` en `for_each`).
- **`terraform.tfstate` enorme**: normal; cada recurso aporta decenas de atributos. No es "basura", es información que Terraform necesita para los diffs futuros.

## Relación con escenarios reales

- Debugging de un plan sorprendente: `state show` del recurso que Terraform quiere destruir — a menudo revela el atributo que cambió.
- Auditar un stack heredado: `state list` da el inventario en segundos.
- Correlacionar un recurso del cloud con su gestor de IaC: `state list -id=<regex>` con una porción del ARN.

## Limpieza

```bash
cd "$WORK"
terraform destroy -auto-approve
cd /
rm -rf "$WORK"
```
