# tf-02 — Instalación, HCL y primer provider

## Identificación

- **ID:** `tf-02-setup-hcl-first-provider`
- **Curso:** `terraform`
- **Nivel:** fundamentos
- **Duración estimada:** 3 h
- **Prerrequisitos:** `tf-01-mental-model-and-plan-apply`. Línea de comandos básica. Git para versionar el repo.

## Objetivo

Instalar Terraform (binario o `tfenv`/`asdf`), aprender la **sintaxis mínima** de **HCL** (bloques, atributos, strings, heredocs, interpolación) y correr el **ciclo completo** `init → fmt → validate → plan → apply → destroy` contra providers **"didácticos"** — `null`, `random`, `local`, `http` — que no tocan ningún cloud y no cuestan nada. Al terminar deberías poder abrir una carpeta vacía, escribir `versions.tf` + `main.tf`, y producir recursos reales (archivos en disco, strings aleatorios, respuestas HTTP) sin credenciales ni cuenta cloud.

## Alcance

Este módulo cubre:

- Instalación en Linux, macOS y Windows (binario oficial, `tfenv`, `asdf`).
- Estructura mínima de un proyecto: `versions.tf`, `providers.tf`, `main.tf`, `outputs.tf`.
- `required_providers` y el **lockfile** `.terraform.lock.hcl`: qué fija y qué no.
- El ciclo `init → fmt → validate → plan → apply → destroy` paso a paso.
- Sintaxis HCL: bloques, atributos, listas, mapas, strings con interpolación `${}`, heredocs (`<<EOT`), comentarios.
- Providers didácticos sin coste: `hashicorp/null`, `hashicorp/random`, `hashicorp/local`, `hashicorp/http`.
- `.gitignore` para `.terraform/`, `*.tfstate*`, `*.tfvars` y por qué.

Lo que **no** cubre (se verá después):

- `resource` vs `data` a fondo, grafo de dependencias → `tf-03`.
- Variables, outputs, locals → `tf-04`.
- El state como artefacto de primer orden (`state list/mv/rm`, backends) → `tf-05`.

## Materiales

- **`theory/lesson.md`** — lección con 12 secciones (del binario al lockfile).
- **`examples/`**:
  - `01-random-pet-and-local-file/` — stack mínimo con `random_pet` + `local_file`; muestra `init → plan → apply → destroy` real.
  - `02-lockfile-anatomy/` — diseccion del `.terraform.lock.hcl` (bloques `provider`, `version`, `constraints`, `hashes`).
- **`activities/`**:
  - `01-first-apply/` (guided-lab) — tu primer `apply` end-to-end usando `null`, `random`, `local`.
  - `02-break-and-fix-hcl-syntax/` (debug guiado) — 4 errores de sintaxis/semánticos plantados; dejar `terraform validate` en verde.
- **`resources/links.md`** — docs oficiales, registry, y lecturas complementarias.

## Temas y subtemas

1. **Instalación**
   - Binario oficial descomprimido en `PATH`.
   - `tfenv` (manejador tipo `rbenv` para Terraform).
   - `asdf` con el plugin `terraform`.
   - Verificación: `terraform version`.
2. **Estructura mínima de un proyecto**
   - Un directorio = un *root module*.
   - Terraform concatena todos los `*.tf` del directorio — el nombre del archivo es organizativo, no semántico.
   - Convención: `versions.tf` (restricciones), `providers.tf` (configuración), `main.tf` (recursos), `outputs.tf`.
3. **`required_providers` y el lockfile**
   - `terraform { required_version, required_providers { source + version } }`.
   - `init` descarga providers a `.terraform/providers/` y escribe `.terraform.lock.hcl` con **versión exacta** y **hashes** por plataforma.
   - El lockfile se commitea; `.terraform/` no.
4. **El ciclo**
   - `init` (prepara backend y providers).
   - `fmt` (canonicaliza indentación).
   - `validate` (chequeo de sintaxis + referencias, offline).
   - `plan` (refresh + diff → operaciones).
   - `apply` (ejecuta el plan y actualiza el state).
   - `destroy` (es `apply` con todo marcado como `-`).
5. **Sintaxis HCL**
   - Bloques: `TYPE "LABEL" "LABEL" { ... }`.
   - Atributos: `nombre = expr`.
   - Tipos: `string`, `number`, `bool`, `list([ ])`, `map({ k=v })`, `object({...})`, `tuple([...])`, `set(...)`.
   - Strings: `"..."` con interpolación `${expr}`; heredocs `<<EOT ... EOT` y `<<-EOT` (indented).
   - Comentarios: `#`, `//`, `/* */`.
6. **Providers didácticos**
   - `hashicorp/null` — recurso "noop" útil para orquestar `provisioner "local-exec"` y para enseñar.
   - `hashicorp/random` — `random_pet`, `random_string`, `random_id` (sin red).
   - `hashicorp/local` — `local_file`, `local_sensitive_file`; `data "local_file"`.
   - `hashicorp/http` — `data "http"` para traer una URL (sí usa red, pero sin credenciales).
7. **`.gitignore`**
   - `.terraform/` — proveedores descargados, grandes y específicos de plataforma.
   - `*.tfstate*` — contiene valores reales, posibles secretos.
   - `*.tfvars` — valores de entrada que suelen contener credenciales.
   - El lockfile **sí se commitea**.

## Conceptos internos (fundamentos)

- **Qué hay en `.terraform/` tras `init`**: un directorio `providers/<registry>/<ns>/<name>/<version>/<platform>/` con el binario del provider (p. ej. `terraform-provider-random_v3.6.0_x5`). También `terraform.tfstate` apunta al backend si lo tienes remoto (en local no se crea ahí; el state vive en `./terraform.tfstate`).
- **Qué fija el lockfile**: la **versión exacta** resuelta a partir de tus `version` constraints, más los **hashes `h1:`** (SHA256 del zip del provider) por cada plataforma que hayas inicializado. Fija la *reproducibilidad del provider*; **no fija** la versión de Terraform core (eso lo hace `required_version`), **no fija** nada del state, **no fija** las versiones de los binarios externos invocados por `provisioner "local-exec"`.
- **Por qué `tfstate` nunca va a Git**: el state contiene atributos reales de los recursos, incluidos valores computados y a veces **secretos devueltos por los providers en claro** (passwords generados, keypairs, tokens). Commitearlo filtra esos datos y, además, cualquier merge/conflicto rompe la correspondencia entre código y estado. En equipos: backend remoto con locking (se verá en `tf-11`).
- **`validate` vs `plan`**: `validate` es **offline** (no habla con providers, no refresca, no toca APIs). Solo chequea sintaxis y que las referencias cierren. `plan` **sí refresca** contra las APIs del provider; por eso puede detectar drift y es *infinitamente* más caro.

## Competencias

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la diferencia entre `validate` y `plan`; explicar qué fija y qué no fija el lockfile; justificar por qué `tfstate` no va a Git. |
| Operativa | Correr `init → fmt → validate → plan → apply → destroy` en un directorio nuevo usando solo providers didácticos; interpretar la salida de cada comando. |
| Arquitectónica | Decidir qué archivos van a Git y cuáles no; separar `versions.tf`, `providers.tf`, `main.tf`, `outputs.tf` según convención del equipo. |

## Entregables

- Un repo mínimo propio (fuera del árbol del curso) con `versions.tf` + `main.tf` + `.gitignore` + `.terraform.lock.hcl` commiteado y evidencia (`terraform.tfstate` en `.gitignore` y ausente del repo).
- Las dos `tests/validate.sh` de las actividades deben pasar (o reportar `SKIP` claro si no tienes Terraform instalado).

## Criterios de evaluación

- Explicar en 3 frases qué fija el lockfile y qué no. Si tu respuesta incluye "la versión de Terraform" estás equivocado — eso lo fija `required_version`.
- Describir qué contiene `.terraform/` tras `init` y por qué no se commitea.
- Correr el ciclo completo sin consultar la cheatsheet, en un directorio vacío.

## Secuencia recomendada

1. Lee `theory/lesson.md` secciones 1–4.
2. Instala Terraform (sección 2 de la lección) y verifica con `terraform version`.
3. Reproduce `examples/01-random-pet-and-local-file/`.
4. Lee `examples/02-lockfile-anatomy/` con el lockfile del ejemplo anterior abierto.
5. Haz `activities/01-first-apply/`.
6. Haz `activities/02-break-and-fix-hcl-syntax/`.
7. Responde las preguntas de evaluación sin consultar.

## Siguiente

→ `tf-03-resources-data-sources-and-references`: dejamos los providers "de juguete" y empezamos a modelar recursos reales con dependencias explícitas.
