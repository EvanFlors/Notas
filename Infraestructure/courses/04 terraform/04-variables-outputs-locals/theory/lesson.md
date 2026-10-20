# Lección: Variables, outputs y locals

> **ID:** `tf-04-variables-outputs-locals` · **Nivel:** fundamentos · **Duración:** 3 h
> **Prerrequisitos:** `tf-02-setup-hcl-first-provider`.

---

## 1. Introducción intuitiva

Terminaste `tf-03` con un stack hard-coded: nombres literales, rutas literales, decisiones literales. Funciona para una demo, pero el día que quieras desplegar "lo mismo pero en `prod`" tendrás dos opciones malas: duplicar los `.tf` (copia-y-pega + divergencia garantizada), o editar los literales a mano cada vez (y rezar para que nadie te interrumpa).

La solución es tratar al stack como una **función**: inputs (`variable`), lógica interna (`resource` + `locals`), outputs. Lo que cambia entre `dev` y `prod` es un puñado de inputs; el cuerpo del stack queda invariante. Terraform aporta el mecanismo (`variable`, `locals`, `output`) y la ergonomía (varias fuentes de valores con precedence predecible, tipos ricos, validación temprana, marcado de datos sensibles).

El hilo conductor del módulo es "cómo dejo de editar `.tf` para cambiar de ambiente, sin inventarme un sistema". A la vuelta de esa pregunta aparecen cinco cosas: el bloque `variable`, el bloque `output`, el bloque `locals`, la jerarquía de precedence, y una conversación incómoda — por qué `sensitive = true` **no** es gestión de secretos.

---

## 2. Fundamentos

### 2.1 `variable` es el contrato de entrada del root module

Un bloque `variable` declara un parámetro de tu stack. Tiene cuatro cosas que importan: `type`, `default`, `description`, y restricciones (`validation`, `sensitive`, `nullable`).

```hcl
variable "environment" {
  type        = string
  description = "Nombre lógico del ambiente (dev, stg, prod)."
  validation {
    condition     = contains(["dev", "stg", "prod"], var.environment)
    error_message = "environment debe ser uno de: dev, stg, prod."
  }
}
```

Sin `default`, es **obligatorio**: TF no puede planear sin un valor. Con `default`, es opcional. `description` es la documentación operacional — aparece en `terraform plan` cuando pregunta por un valor que falta.

### 2.2 `locals` son expresiones derivadas, no inputs

Un `local` **no se parametriza desde fuera**. Es una expresión interna que te sirve para no repetir, o para calcular un valor canónico que varios recursos van a usar.

```hcl
locals {
  common_tags = {
    environment = var.environment
    owner       = var.owner_team
    managed_by  = "terraform"
  }
  name_prefix = "${var.project}-${var.environment}"
}
```

Regla de dedo: si el operador debe poder cambiarlo desde fuera, es `variable`. Si es un cálculo derivado de otras cosas que el operador ya proveyó, es `local`.

### 2.3 `output` es el contrato de salida del root module

Un `output` expone un valor computado del stack: un ID, un ARN, una URL, una ruta de archivo generada, un dominio DNS. Dos usos:

- **Humano**: `terraform output` lista los outputs al final del `apply` para que los copies.
- **Programático**: `terraform output -json` o `-raw` para pipelines; `terraform_remote_state` para que otro stack lo lea.

```hcl
output "cert_pem_path" {
  value       = local_file.cert.filename
  description = "Ruta en disco del certificado emitido."
}

output "private_key_pem" {
  value       = tls_private_key.ca.private_key_pem
  description = "PEM de la llave privada (NO para producción, demo únicamente)."
  sensitive   = true
}
```

---

## 3. Contexto histórico

- **TF 0.6 (2015)** — bloques `variable` y `output` desde el día uno, pero sin tipos ricos: todo `string`, y las "listas" eran strings con separador.
- **TF 0.7–0.11** — aparecen `list` y `map` como tipos reales; `output` aprende `sensitive = true` (0.7); los `locals` llegan en 0.10 (2017) — hasta entonces, la gente usaba `null_resource` + `triggers` como un `local` improvisado.
- **TF 0.12 (2019)** — reescritura del lenguaje: tipos primitivos y colecciones completos (`object`, `tuple`, `set`), expresiones de primera clase, interpolación sin `${}` cuando no la necesitas; `variable` acepta `type = object({...})`.
- **TF 0.13 (2020)** — `variable` acepta `validation` blocks.
- **TF 1.0 (2021)** — compromiso de estabilidad del lenguaje; los bloques `variable`, `locals`, `output` quedan como contrato estable.
- **TF 1.3+ (2022–)** — `nullable = false` explícito, mejoras en mensajes de validación, output `-raw` y `-json`.

Nombres que la gente confunde:

- **`variable`** = input del root module.
- **`local`** = alias para una expresión interna; **no** es un input.
- **`output`** = valor expuesto hacia afuera (CLI, otros stacks).
- **`provider` vars** (`region`, `profile`, etc.) = parámetros del *provider*, se setean dentro del bloque `provider`, aunque suelen venir también de `variable` del stack.

---

## 4. Funcionamiento interno

### 4.1 Resolución de valores: la cadena de precedence

Cuando Terraform resuelve el valor de `var.foo`, consulta cinco fuentes en este orden (de **menor** a **mayor** prioridad):

```
┌──────────────────────────────────────────────┐
│ 5 (gana) CLI: -var 'foo=...'  y  -var-file=... │  (en el orden que aparecen)
├──────────────────────────────────────────────┤
│ 4       Variables de entorno: TF_VAR_foo       │
├──────────────────────────────────────────────┤
│ 3       Archivos *.auto.tfvars  (lexicográfico)│
├──────────────────────────────────────────────┤
│ 2       Archivo terraform.tfvars               │
├──────────────────────────────────────────────┤
│ 1 (base) default = ... en el bloque variable   │
└──────────────────────────────────────────────┘
```

Reglas finas:

- Dentro de un mismo archivo tfvars, si repites una variable, gana la **última** aparición.
- Dentro de la CLI, si pasas `-var foo=a -var foo=b`, gana `b` (último en orden de argumentos).
- Si no hay default y ninguna fuente provee valor, TF **te pregunta interactivamente** en el plan. En CI eso bloquea; usa `TF_INPUT=0` o `-input=false` para forzar error.
- Para variables de tipo complejo (`list`, `map`, `object`), `-var` acepta HCL inline: `-var 'tags={env="dev",team="payments"}'`.

### 4.2 `validation`: fallar temprano con un mensaje útil

El bloque `validation` corre en la fase de **resolución de variables**, antes de construir el grafo y antes de llamar al provider. Esto importa porque el error llega con tu mensaje — no con un error oscuro del provider 20 segundos después.

```hcl
variable "cidr_block" {
  type = string
  validation {
    condition     = can(cidrnetmask(var.cidr_block))
    error_message = "cidr_block debe ser un CIDR válido (ej. 10.0.0.0/16)."
  }
  validation {
    condition     = tonumber(split("/", var.cidr_block)[1]) <= 24
    error_message = "cidr_block debe tener máscara /24 o menor (más amplio)."
  }
}
```

Puedes tener **múltiples** `validation` por variable; se evalúan todas y se reportan todas las que fallan.

### 4.3 `sensitive`: qué sí y qué no

Marcar algo como `sensitive = true` tiene **dos** efectos observables:

1. En `plan`/`apply`, Terraform renderiza el valor como `(sensitive value)` en la salida.
2. En `output`, el valor no sale en `terraform output` sin flags; necesitas `-raw <name>` o `-json`.

Lo que **no** hace:

- No cifra el state. El `terraform.tfstate` guarda el valor en claro.
- No cifra el plan. El `terraform plan -out=plan.tfplan` guarda el valor en claro.
- No evita que un `local` o un `resource` que use el valor lo guarde en algún atributo computable.
- No evita que el provider lo envíe tal cual a la API remota.

El propósito real: evitar que un secreto se cuele en la salida del `plan` de un PR, o en los logs de CI. Es defensa superficial. Para secretos de verdad, el patrón es:

```hcl
# El secreto NO vive como variable; vive en un secret manager.
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod/payments/db"
}

resource "aws_db_instance" "payments" {
  password = data.aws_secretsmanager_secret_version.db_password.secret_string
}
```

Y el state se protege en el **backend**: bucket cifrado at-rest, acceso IAM mínimo, versionado para auditoría.

### 4.4 Tipos: por qué `object` suele ganar a muchas variables

Puedes modelar una config como 10 variables sueltas o como una variable `object`. Comparemos:

```hcl
# Opción A: variables sueltas
variable "db_engine"           { type = string }
variable "db_instance_class"   { type = string }
variable "db_allocated_storage"{ type = number }
# ... x7 más

# Opción B: un object
variable "database" {
  type = object({
    engine            = string
    instance_class    = string
    allocated_storage = number
    multi_az          = optional(bool, false)
    tags              = optional(map(string), {})
  })
}
```

La opción B es más legible desde fuera (`-var 'database={engine="postgres",...}'` o un `terraform.tfvars` con una sola estructura), permite `optional(...)` con defaults, y evita el acoplamiento accidental entre variables que "siempre van juntas".

Regla de dedo: si N variables siempre se setean a la vez y describen una misma cosa, agrúpalas en un `object`.

---

## 5. Ejemplo mínimo

Un `main.tf` que ilustra las cuatro ideas (variable, local, output, sensitive) en un stack de 15 líneas:

```hcl
# versions.tf
terraform {
  required_version = ">= 1.3.0"
  required_providers {
    random = { source = "hashicorp/random", version = "~> 3.5" }
    local  = { source = "hashicorp/local",  version = "~> 2.4" }
  }
}

# variables.tf
variable "environment" {
  type        = string
  description = "dev | stg | prod"
  validation {
    condition     = contains(["dev", "stg", "prod"], var.environment)
    error_message = "environment debe ser dev, stg o prod."
  }
}

variable "pet_length" {
  type        = number
  default     = 2
  description = "Palabras en el nombre del pet."
  validation {
    condition     = var.pet_length >= 1 && var.pet_length <= 5
    error_message = "pet_length debe estar entre 1 y 5."
  }
}

# main.tf
locals {
  name_prefix = "demo-${var.environment}"
}

resource "random_pet" "name" {
  length    = var.pet_length
  separator = "-"
  prefix    = local.name_prefix
}

resource "local_file" "manifest" {
  filename        = "${path.module}/out/${local.name_prefix}.txt"
  content         = "name=${random_pet.name.id}\nenv=${var.environment}\n"
  file_permission = "0644"
}

# outputs.tf
output "pet_name" {
  value       = random_pet.name.id
  description = "Nombre generado."
}

output "manifest_path" {
  value       = local_file.manifest.filename
  description = "Ruta del archivo generado."
}

output "secret_token_demo" {
  value       = "fake-token-NOT-A-REAL-SECRET"
  sensitive   = true
  description = "Demo: aparece como <sensitive> en la CLI, PERO queda en claro en tfstate."
}
```

Prueba la precedence:

```bash
# default → "dev" en terraform.tfvars → "prod" en TF_VAR → "stg" en CLI (gana)
echo 'environment = "dev"' > terraform.tfvars
TF_VAR_environment=prod terraform plan -var environment=stg
# El plan usará "stg".
```

Y mira el state después del apply:

```bash
terraform apply -auto-approve -var environment=dev
terraform output                    # verás secret_token_demo = <sensitive>
grep -o 'fake-token[^"]*' terraform.tfstate   # ... pero aquí está, en claro.
```

---

## 6. Implementación progresiva

### Nivel 0 — una `variable` sin tipo

```hcl
variable "name" {}
```

Funciona. Pero sin `type`, sin `description`, sin `validation`, sin `default`. En cuanto alguien más lo use, se preguntarán qué espera.

### Nivel 1 — contrato explícito

```hcl
variable "name" {
  type        = string
  description = "Nombre del recurso (snake_case, 3-20 chars)."
  default     = "demo"
}
```

Ya es revisable en PR: tipo, propósito, default razonable.

### Nivel 2 — validación

```hcl
variable "name" {
  type        = string
  description = "Nombre del recurso (snake_case, 3-20 chars)."
  default     = "demo"
  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{2,19}$", var.name))
    error_message = "name debe ser snake_case, 3-20 chars, iniciar con letra."
  }
}
```

Ahora el error llega **antes** del `plan`, con un mensaje accionable.

### Nivel 3 — agrupar en `object` + usar `locals` para derivadas

```hcl
variable "service" {
  type = object({
    name        = string
    environment = string
    tags        = optional(map(string), {})
  })
  validation {
    condition     = contains(["dev", "stg", "prod"], var.service.environment)
    error_message = "service.environment debe ser dev/stg/prod."
  }
}

locals {
  canonical_name = "${var.service.name}-${var.service.environment}"
  effective_tags = merge({
    environment = var.service.environment
    managed_by  = "terraform"
  }, var.service.tags)
}
```

Esto es ya el patrón que verás en módulos profesionales.

### Nivel 4 — separar por ambiente con `*.tfvars`

```
stacks/
  main.tf
  variables.tf
  outputs.tf
  envs/
    dev.tfvars
    stg.tfvars
    prod.tfvars
```

Despliegue:

```bash
terraform plan  -var-file=envs/dev.tfvars
terraform apply -var-file=envs/prod.tfvars
```

El código es uno; los datos viven en `envs/*.tfvars`. Es la forma más simple de ambientes separados sin workspaces.

---

## 7. Aplicación profesional

En un repositorio productivo verás este patrón para cada stack:

```
stack/
  versions.tf         # required_version + required_providers
  providers.tf        # provider blocks (region, profile, aliases)
  variables.tf        # TODOS los variable { } bien documentados y validados
  locals.tf           # derivadas; común: naming, tags, red CIDRs
  main.tf             # recursos; en stacks grandes se parte en varios .tf por dominio
  outputs.tf          # TODOS los output { } con description
  envs/
    dev.tfvars
    stg.tfvars
    prod.tfvars
  README.md           # "para desplegar X, correr: terraform apply -var-file=envs/X.tfvars"
```

Reglas que te vas a encontrar escritas (o no, pero vigentes):

- **Toda variable sin `default` debe venir del tfvars**. Nunca pedir inputs interactivos en CI.
- **Toda variable con `default` debe tener `description`** que explique cuándo cambiar el default.
- **Todo output que exponga identificadores (IDs, ARNs, URLs)** se documenta y se trata como contrato — romperlo rompe stacks aguas abajo.
- **Nunca pongas secretos en tfvars de prod**. Van a Vault/SSM/Secrets Manager y se leen con `data`. Los tfvars pueden entrar a Git; los secretos no.
- **`terraform.tfvars` suele estar en `.gitignore`** cuando se usa para datos locales del operador; los `envs/*.tfvars` sí entran a Git porque son el ambiente declarado.

Consumo entre stacks (patrón `terraform_remote_state`):

```hcl
# stack-consumer/main.tf
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "tf-states-prod"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}

resource "aws_instance" "app" {
  subnet_id = data.terraform_remote_state.network.outputs.private_subnet_ids[0]
}
```

El output del stack `network` es el contrato que el stack `app` consume. Cambia el output y rompes el consumer — por eso es contrato.

---

## 8. Trade-offs

| Decisión | Pros | Contras |
|---|---|---|
| Muchas `variable` sueltas | Fácil de ver cada parámetro | Explota; se pierden las relaciones entre ellas |
| Una `variable` de tipo `object` | Agrupa cosas que van juntas; permite `optional()` con defaults | Más verboso en `-var` desde CLI; errores de tipo menos localizados |
| `terraform.tfvars` en Git | Reproducible, revisable en PR | Si contiene secretos, los filtras |
| `terraform.tfvars` en `.gitignore` | Permite overrides locales del operador | Pierdes trazabilidad; `envs/*.tfvars` es mejor camino |
| `-var` en CLI | Overrides puntuales en desarrollo | Fácil de olvidar y producir drift entre lo "aplicado" y lo "en Git" |
| `TF_VAR_*` env vars | Útil para secretos de corta vida en CI | Invisible en el repo; se filtra con `env` en logs; usar con cuidado |
| `sensitive = true` | Oculta de la CLI y de logs superficiales | **No** cifra; crea falsa sensación de seguridad si lo tomas por secret management |
| `locals` abundantes | DRY; expresiones legibles | Si abusas, el stack se vuelve una cadena de alias; dificulta el debugging |

---

## 9. Errores frecuentes

- **"Lo marqué `sensitive`, está seguro"** — No. El state tiene el valor en claro. Verifica tú mismo con `grep` sobre `terraform.tfstate`.
- **Convertir una `variable` en `local` para "simplificar"** — Si lo necesita el operador desde fuera, debe ser `variable`. Pasar a `local` lo hace invisible al CLI.
- **No usar `validation` y descubrir el error en el provider** — El provider devuelve un mensaje genérico 30 s después. Validación temprana ahorra iteraciones.
- **Reutilizar `terraform.tfvars` para datos de distinto ambiente** — Cuando aplicas al ambiente equivocado, aplicas valores equivocados. Separa por archivo (`envs/dev.tfvars`, etc.).
- **Confundir `-var-file=foo.tfvars` con `foo.auto.tfvars`** — El `.auto.tfvars` se carga **automáticamente** si está en el directorio; el `-var-file` requiere pedirlo explícitamente. Si tienes ambos, pueden pelearse.
- **Olvidar `nullable = false`** — Por default una variable puede recibir `null` y eso puede propagarse a atributos computados con efectos sorprendentes.
- **Exponer todo como `output`** — Los outputs son contrato. Si expones demasiado, cualquier refactor rompe consumers.

---

## 10. Buenas prácticas

- **Un `variables.tf` canónico** por stack con todas las variables. Nada de `variable` dispersas en `main.tf`.
- **Siempre** `type` + `description` + `validation` cuando el valor tenga un dominio restringido.
- **Agrupa en `object`** lo que siempre va junto; usa `optional(T, default)` para campos con default.
- **`envs/<nombre>.tfvars`** por ambiente, en Git; `terraform.tfvars` queda para overrides locales (o `.gitignore`).
- **Nunca** pongas secretos en `.tfvars` que entren a Git. Secretos → secret manager → `data`.
- **`sensitive = true`** en todo output que lo haga razonable, aunque sepas que no cifra: evita filtración por consola/logs.
- **Protege el state en el backend**: encriptación at-rest, IAM mínimo, versionado del bucket.
- **Outputs documentados** con `description`; piensa en ellos como una API pública.

---

## 11. Ejercicios recomendados

1. Toma una variable del Nivel 0 y haz la progresión completa hasta Nivel 3 (object + locals derivadas + validation).
2. Monta un stack con `envs/dev.tfvars` y `envs/prod.tfvars` y haz `plan` con cada uno; observa el diff en los recursos generados.
3. Fuerza una colisión de precedence: pon un valor en `terraform.tfvars`, uno en `TF_VAR_*` y uno en `-var`; predice qué gana y verifica.
4. Marca un output como `sensitive = true` con un valor obviamente dummy; corre `terraform output`, `terraform output -raw`, y `grep` sobre `terraform.tfstate`. Documenta qué viste.
5. Escribe dos `validation` sobre la misma variable (una por formato, otra por rango) y provoca que ambas fallen; observa que TF las reporta juntas.
6. Diseña el contrato de outputs de un stack "network" (VPC + subnets) para que un stack "app" lo consuma con `terraform_remote_state`.

---

## 12. Evaluación

Responde sin consultar:

1. Enumera los 5 niveles de precedence de valores de variables, de menor a mayor prioridad.
2. Dado un `terraform.tfvars` con `env = "dev"`, una env var `TF_VAR_env=stg`, y un flag `-var env=prod`, ¿qué valor usa el `plan`?
3. ¿Qué diferencia hay entre `variable` y `local`? ¿Cuándo elegirías uno sobre el otro?
4. Marcas un `output` con `sensitive = true`. Enumera dos lugares donde el valor **sigue estando en claro**.
5. ¿Por qué `validation` corre antes que el grafo, y por qué eso importa en CI?
6. Describe el patrón correcto para proveer una contraseña de base de datos a Terraform sin que entre a Git ni al state en claro de forma "cómoda".
7. ¿Qué pasa si una variable no tiene `default` y nadie provee valor, en una ejecución de CI con `-input=false`?
8. Diseña un `variable "database"` de tipo `object` con 4 campos (dos obligatorios, dos con default), e incluye una `validation`.

---

## Referencias

- Documentación oficial Terraform — bloques [`variable`](https://developer.hashicorp.com/terraform/language/values/variables), [`locals`](https://developer.hashicorp.com/terraform/language/values/locals), [`output`](https://developer.hashicorp.com/terraform/language/values/outputs).
- Documentación oficial — [Variable precedence](https://developer.hashicorp.com/terraform/language/values/variables#variable-definition-precedence).
- Documentación oficial — [Sensitive input variables](https://developer.hashicorp.com/terraform/language/values/variables#suppressing-values-in-cli-output) y [Sensitive data in state](https://developer.hashicorp.com/terraform/language/state/sensitive-data).
- OpenTofu docs — mismos bloques, compatibilidad total con lo visto.
- Gruntwork — "How to manage Terraform secrets" (artículo de referencia sobre el patrón `data` + secret manager).
