# Lección: Módulos en Terraform

> **ID:** `tf-06-modules` · **Nivel:** intermedio · **Duración:** 5 h
> **Prerrequisitos:** `tf-03`, `tf-04`.

---

## 1. Introducción intuitiva

Hasta aquí todo tu código Terraform ha vivido en un único montón de `.tf` que `terraform init/plan/apply` lee de corrido. Funciona para 10 recursos. Deja de funcionar en cuanto quieres hacer **dos cosas razonables** al mismo tiempo:

1. Repetir la misma receta en varios lugares (p. ej. "un bucket con mis defaults seguros", "una VPC con subnets públicas y privadas") sin copiar-pegar.
2. Compartirle esa receta a otra persona (o a tu yo del lunes) con un contrato claro: "si me pasas estos inputs, te devuelvo estos outputs; lo de adentro no te interesa".

Los **módulos** son la respuesta a esas dos cosas. Un módulo es, literalmente, una **carpeta con archivos `.tf`** más algunas convenciones: `variables.tf` (los inputs del módulo), `outputs.tf` (los outputs), un cuerpo (`main.tf`) y un `README.md`. Cuando otro código `.tf` dice `module "x" { source = "./modules/vpc" }`, Terraform carga esa carpeta y evalúa su HCL dentro de un **namespace** llamado `module.x`.

No hay magia nueva. Lo que ya aprendiste de `resource`, `variable`, `output`, `locals` y `data` sigue aplicando dentro de un módulo. Lo nuevo es el **mecanismo de encapsulación** y, sobre todo, las **buenas (y malas) prácticas** de diseño.

---

## 2. Fundamentos

### 2.1 ¿Qué es un módulo?

Formalmente: **todo directorio con archivos `.tf` es un módulo.** Siempre. Cuando corres `terraform init` en una carpeta, esa carpeta es el **root module**. Cuando el root dice `module "x" { source = "./modules/vpc" }`, carga esa segunda carpeta como un **child module**.

Convenciones (no obligatorias, pero defendibles):

```
my-module/
├── README.md         # qué hace, inputs, outputs, ejemplo de uso
├── versions.tf       # required_version + required_providers
├── variables.tf      # inputs (lo que acepta)
├── main.tf           # cuerpo (recursos, data, otros module)
├── outputs.tf        # contrato de salida
└── examples/         # ejemplos ejecutables de consumo
    └── basic/
        ├── main.tf
        └── versions.tf
```

### 2.2 Qué un módulo **no** es

- **No es un paquete** en el sentido de npm/pip. No se "instala" (se vendorea en `.terraform/modules/`), no versiona su propio state, no corre solo.
- **No tiene state propio.** Todos los recursos de todos los módulos llamados por un mismo root viven en el **mismo** `terraform.tfstate` del root, prefijados por `module.<name>.`.
- **No tiene su propio backend** ni su propio provider "de verdad". Los **declara** (compatibilidad), los **inicializa** el root.

### 2.3 Root module vs child module

| Dimensión | Root | Child |
|-----------|------|-------|
| Backend (`terraform { backend "s3" {...} }`) | Sí, es el único | **No** |
| Provider configurado (`provider "aws" { region = ... }`) | Sí | **Evitar**; solo si realmente aporta |
| `required_providers` | Sí | Sí (declaración de compatibilidad) |
| State | Suyo | **Comparte el del root** |
| Se ejecuta solo con `init/plan/apply` | Sí | No; solo se consume |

### 2.4 El grafo se fusiona

Cuando Terraform evalúa el HCL, cada `resource`/`data`/`module` dentro de un child se añade al **mismo DAG** del root, con un path lógico. Lo verás en `terraform state list`:

```
module.network.aws_vpc.this
module.network.aws_subnet.public[0]
module.consumer.aws_instance.app
```

Un `terraform destroy` destruye **todo** el grafo. Un `terraform plan -target=module.network` planifica solo esa rama (y hereda las advertencias de `-target`: fragmenta el plan, úsalo como escape hatch).

---

## 3. Contexto histórico

- **2014** — Terraform 0.1 ya tenía módulos locales con `source = "./..."`.
- **2017** — Lanzamiento del **Terraform Registry** público (`registry.terraform.io`). Aparecen módulos "oficiales" (`terraform-aws-modules/*`) y "verified".
- **2019** — `for_each` sobre módulos (0.13); antes solo `count`, con todos los problemas de reindex.
- **2021** — Terraform 1.0: compromiso de estabilidad del lenguaje de módulos.
- **2022** — `moved` blocks: refactorizar módulos sin recrear recursos.
- **2023** — Fork **OpenTofu**: el Registry de OpenTofu (`search.opentofu.org`) es paralelo al de Terraform; muchos módulos son compatibles entre ambos (es solo HCL + providers).
- **2024+** — Convergencia funcional; divergencias puntuales (p. ej. `removed` block más amplio en OpenTofu, state encryption nativa, provider-defined functions).

---

## 4. Fuentes de módulo (`source`)

La cadena `source = "..."` es **estática**: no acepta variables ni interpolación, porque Terraform tiene que resolverla durante `init`, antes de evaluar el resto del HCL.

### 4.1 Local

```hcl
module "safe_bucket" {
  source = "./modules/safe-bucket"
  name   = "logs"
}
```

Útil para módulos **privados** del repo. No necesitas publicar nada; Terraform los carga directo del filesystem. Es el 80 % del uso real en una empresa que no mantiene un module registry interno.

### 4.2 Terraform Registry

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "demo"
  cidr = "10.0.0.0/16"
  # ...
}
```

Formato: `<NAMESPACE>/<MODULE>/<PROVIDER>`. El `version` es un constraint (`~> 5.0` significa "≥ 5.0, < 6.0"). Terraform descarga el módulo durante `init` y lo cachea en `.terraform/modules/`.

### 4.3 Git

```hcl
module "shared" {
  source = "git::https://github.com/myorg/tf-modules.git//modules/vpc?ref=v1.2.3"
}
```

Permite consumir módulos de un repo privado sin publicarlos en un Registry. `?ref=` puede ser **tag**, **branch** o **SHA**. Fija siempre tag o SHA en producción; `?ref=main` es un misil.

### 4.4 Otras fuentes

- Subcarpeta de un paquete: `source = "git::...//modules/sub"`.
- HTTP: `source = "https://.../archive.tar.gz"`.
- S3/GCS: `source = "s3::https://..."` / `gcs::https://...`.

Usadas para registries internos sencillos (p. ej. módulos empaquetados a S3 por CI).

---

## 5. Versiones y pinning

### 5.1 ¿Qué fija qué?

- **`version = "~> 5.0"` del módulo (Registry):** el constraint lo evalúa `init`; descarga la última compatible.
- **`?ref=v1.2.3` en Git:** lo mismo pero contra tags/SHAs del repo.
- **`.terraform.lock.hcl`:** fija versiones y hashes **de providers**, no de módulos. Si quieres reproducibilidad total del módulo, usa un tag específico (no un constraint abierto).

### 5.2 Operadores de constraint útiles

| Operador | Significado |
|----------|-------------|
| `= 5.1.0` | exactamente 5.1.0 |
| `>= 5.0, < 6.0` | rango explícito |
| `~> 5.1` | ≥ 5.1, < 6.0 (pessimistic a nivel major) |
| `~> 5.1.0` | ≥ 5.1.0, < 5.2.0 (pessimistic a nivel minor) |

Regla de dedo:

- Para consumir un módulo **tuyo** del Registry: `~> X.Y` (pessimistic a minor).
- Para consumir un módulo de **terceros** sin lock: pin **exacto** y actualiza con PR.

---

## 6. Inputs: variables del módulo

Todas las reglas de `tf-04` (`type`, `description`, `default`, `sensitive`, `validation`) aplican. Lo nuevo es la **disciplina de diseño**:

1. **Diferencia eje de variación vs constante.** Si "casi nunca va a cambiar", no lo hagas input; déjalo hardcoded. Cada input es una obligación para el consumidor.
2. **Pon `default` sensato** cuando exista uno. Si no hay default razonable, no pongas `default` — oblígame a pensarlo.
3. **`description` obligatoria.** Es lo primero que `terraform-docs` extrae.
4. **`validation {}` para fallar temprano.** Un mapa mal formado detectado en `plan` es mejor que un provider gritando en `apply`.
5. **`sensitive = true`** si vas a aceptar un secreto como input, aunque recuerda que **el state lo guarda en claro** (ver `tf-05`).

Ejemplo:

```hcl
variable "name" {
  type        = string
  description = "Nombre lógico del bucket (slug kebab-case, 3-63 chars)."
  validation {
    condition     = can(regex("^[a-z0-9-]{3,63}$", var.name))
    error_message = "name debe ser kebab-case, 3-63 chars."
  }
}

variable "versioning_enabled" {
  type        = bool
  description = "Habilita versioning. Safe default."
  default     = true
}
```

---

## 7. Outputs: contrato de salida

Un `output "x" { value = ... }` es parte del **contrato público** del módulo. Si cambias el tipo o la semántica, rompes a todos los consumidores.

Reglas:

1. **Expón solo lo necesario.** Un consumidor pide IDs/ARNs/URLs. No le expongas atributos triviales derivables de los inputs.
2. **`description` obligatoria.**
3. **`sensitive = true`** si el valor es sensible (p. ej. clave privada generada). Oculta en CLI pero sigue en state.
4. **Tipo estable.** Devolver `string` vs `list(string)` vs `map(string)` no es intercambiable — cambia la forma de consumirlo.

```hcl
output "bucket_name" {
  description = "Nombre efectivo del bucket, incluye sufijo random."
  value       = local.full_name
}
```

Los outputs son **lazy**: no se calculan hasta que alguien los lee (por otro módulo, por el root, por `terraform output`). Pero sí viven en el state, visibles con `terraform state show module.x`.

---

## 8. Composición: root ↔ child, y child-of-child

El patrón clásico:

```hcl
# root
module "network" {
  source = "./modules/network"
  cidr   = "10.0.0.0/16"
}

module "consumer" {
  source = "./modules/consumer"
  vpc_id = module.network.vpc_id   # output de un módulo → input de otro
}
```

Puntos:

- La referencia `module.network.vpc_id` crea una **dependencia implícita**: Terraform construye el grafo correcto automáticamente (`network` antes que `consumer`).
- Un **child module puede llamar a otro módulo** (child-of-child). Terraform lo soporta, pero cuida la profundidad: cuanto más profundo, más confuso el error cuando algo rompe.
- No pases "todo el objeto" si no lo necesitas; pasa el ID/ARN concreto. Minimiza el acoplamiento.

---

## 9. Providers dentro del módulo

Un child module **declara** sus providers requeridos:

```hcl
# modules/safe-bucket/versions.tf
terraform {
  required_version = ">= 1.3.0"
  required_providers {
    local  = { source = "hashicorp/local",  version = "~> 2.4" }
    random = { source = "hashicorp/random", version = "~> 3.5" }
  }
}
```

Y **no configura** `provider "local" {}` ni `provider "random" {}`: eso es tarea del root. Si el módulo necesita que el root le pase un provider con alias (p. ej. multi-región):

```hcl
# modules/replica/versions.tf
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.replica]
    }
  }
}

# root
module "replica" {
  source = "./modules/replica"
  providers = {
    aws = aws.replica
  }
}
```

Regla operativa: **si el módulo configura su propio `provider "aws" { region = "us-east-1" }`, el consumidor pierde control.** Es un anti-patrón salvo contadas excepciones (p. ej. módulos de bootstrap de cuenta nueva).

---

## 10. Diseño: límites del buen módulo

### 10.1 Anti-patrón 1 — Mega-módulo

Un módulo "plataforma" que abstrae VPC + EKS + IAM + RDS + ALB + Route53 + monitoreo en un solo paquete. Se vuelve **inflexible** (si quieres cambiar algo, hay que exponerlo como input), con un **radius de blast** gigante y una API de inputs tan grande que es ilegible. Si lo usas una vez, bien. Si lo usas dos, cada uso pelea con el otro.

### 10.2 Anti-patrón 2 — Wrapper trivial

```hcl
# modules/bucket/main.tf
resource "aws_s3_bucket" "this" {
  bucket = var.name
}
```

Un módulo con un solo recurso que no agrega safe defaults, no reduce acoplamiento, no agrupa recursos relacionados. **No agrega valor.** Es peor que no tener módulo: añade una capa de indirección sin beneficio.

### 10.3 El buen módulo

- **Una responsabilidad clara.** Puedes nombrarla en una frase: "un bucket S3 con versioning, encryption, public-access-block y lifecycle sensato".
- **Agrupa recursos relacionados.** Un bucket real son 5-10 recursos (`aws_s3_bucket`, `aws_s3_bucket_versioning`, `aws_s3_bucket_server_side_encryption_configuration`, `aws_s3_bucket_public_access_block`, `aws_s3_bucket_lifecycle_configuration`, ...). Agruparlos aporta.
- **Safe defaults opinados.** Habilita versioning, encryption y block public access **por default**. Permite al consumidor desactivarlos con flag explícito.
- **API pequeña.** 5-10 inputs esenciales, no 40. Si necesitas 40, probablemente son dos módulos.
- **Outputs estables.** Expón lo que un consumidor pide: `id`, `arn`, `name`, `url`.

### 10.4 Heurística rápida

> "¿Si corto este bloque y lo pego dos veces en el repo, aporta valor abstraerlo?"
> Si sí → módulo. Si no → `locals` o nada.

---

## 11. Evaluación de módulos de terceros

Antes de poner `source = "terraform-aws-modules/vpc/aws"` en producción, pregúntate:

1. **¿Está mantenido?** Último commit, issues recientes respondidas, CI verde, releases cada pocos meses.
2. **¿Pinnea sus providers?** `required_providers { aws = { version = "~> 5.0" } }`. Si no, cualquier upgrade de provider puede romperlo.
3. **¿Qué safe defaults aplica?** Un módulo que crea un bucket **no debería** dejarlo público. Un módulo que crea un SG **no debería** abrir `0.0.0.0/0:22`. Lee el `main.tf`.
4. **¿Tiene tests?** `terraform test` nativo, Terratest, al menos `examples/` ejecutables.
5. **¿Tiene documentación?** `README.md` legible, idealmente generado con `terraform-docs` (inputs/outputs tabulados).
6. **¿Respeta SemVer?** ¿Los breaking changes van a major? Lee el CHANGELOG.
7. **¿Tiene una superficie razonable?** 400 inputs es señal de mega-módulo. 1 input es señal de wrapper trivial.
8. **¿Lo necesitas?** A veces copiar 30 líneas al repo es más barato que arrastrar una dependencia externa.

Esta evaluación es lo que harás en `activities/02`. No hay un veredicto único; hay una lista de criterios aplicada con honestidad.

---

## 12. Problemas comunes y antídotos

### 12.1 "Cambié el nombre del módulo y recreó todo"

Causa: `module.old` → `module.new` cambia el path del state. Terraform **no sabe** que es el mismo módulo.
Antídoto: `moved` block (ver `tf-09`):

```hcl
moved {
  from = module.old
  to   = module.new
}
```

### 12.2 "Terraform init me descarga el módulo pero no se actualiza"

Causa: cambiaste el `version` del módulo pero `init` tiene cache en `.terraform/modules/`.
Antídoto: `terraform init -upgrade`.

### 12.3 "El módulo configura su propio provider y no puedo cambiar la región"

Causa: anti-patrón del autor del módulo. Si publicó un `provider "aws" { region = "us-east-1" }` dentro del módulo, estás atado.
Antídoto: fork el módulo o abre un PR. Mejor aún, elige otro.

### 12.4 "Pasé `null` como input y el provider se enojó"

Causa: pasar `null` tiene semántica de "usar el default", pero no todos los recursos lo soportan en todos los atributos.
Antídoto: `coalesce(var.x, "default")` o condicionales con `can(...)`.

### 12.5 "Tengo un state gigante con 300 recursos de un solo root"

Causa: un root con 20 módulos y todo acoplado. Se vuelve lento y peligroso.
Antídoto: dividir por **bounded context** (`tf-08`/`tf-11`) y usar `data` para leer outputs de otro state (remote state data source) o pasar valores por parámetro vía CI.

### 12.6 "Instalé un módulo del Registry y me introdujo un AMI público para los workers"

Causa: no leíste el módulo. Confías en el nombre.
Antídoto: la lista de la sección 11. Siempre.

---

## Preguntas de evaluación

Responde sin consultar:

1. ¿Por qué un módulo no tiene su propio state file? ¿Dónde van entonces sus recursos?
2. Un compañero propone `module "aws_s3_bucket_wrapper" { source = "./modules/bucket" }` con un `main.tf` que solo contiene `resource "aws_s3_bucket" "this" { bucket = var.name }`. ¿Qué le dirías y por qué?
3. ¿Qué diferencia hay entre `version = "~> 5.0"` y `version = "~> 5.1.0"` en un `module` del Registry? Da un ejemplo donde la diferencia importe.
4. Dentro de un child module quieres crear buckets en dos regiones AWS. ¿Qué necesitas declarar en el child y qué debe hacer el root?
5. Un módulo del Registry no tiene commits en 18 meses pero "funciona en nuestra prueba". Lista cinco preguntas que haces antes de adoptarlo.
6. Explica por qué `source = "git::https://.../repo.git?ref=main"` es peligroso en producción.
7. Cambias el tipo de un output de `string` a `list(string)`. ¿Es breaking change? ¿Qué deberías hacer con la versión del módulo?

---

## Siguiente lectura

- `tf-07` — `for_each`/`count`/`dynamic`: cómo instanciar N recursos (y N módulos) a partir de datos.
- `tf-09` — `moved` blocks: refactorizar módulos sin recrear recursos.
- `tf-14` — module registry interno, SemVer de módulos y "golden path" a escala.
