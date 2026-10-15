# tf-06 — Módulos

## Identificación

- **ID:** `tf-06-modules`
- **Curso:** `terraform`
- **Nivel:** intermedio
- **Duración estimada:** 5 h
- **Prerrequisitos:** `tf-03-resources-data-sources-and-references`, `tf-04-variables-outputs-locals`.

## Objetivo

**Encapsular y reutilizar configuración** con módulos. Al terminar deberías poder diseñar un módulo pequeño y cohesivo, consumirlo desde un root module, saber distinguir un módulo local de uno del Registry o de Git, versionarlo con criterio, y evaluar un módulo de la comunidad con una lista de preguntas antes de adoptarlo en producción.

## Alcance

Este módulo cubre:

- **Qué es** un módulo en Terraform: una carpeta con `.tf` que agrupa `variables` (inputs), `resources`/`data`/otros `module` (cuerpo) y `outputs` (contratos de salida).
- **Fuentes** (`source`): local (`./modules/x`), Registry (`terraform-aws-modules/vpc/aws`), Git (`git::https://...`), subcarpetas (`//modules/sub`).
- **Versiones** (`version = "~> 5.0"`) y el pin de versión como contrato.
- **Composición**: root module (único con backend y providers "de verdad") que compone módulos hijos; módulos hijos que a su vez consumen otros módulos.
- **Límites del buen diseño**: ni "mega-módulos" que abstraen una plataforma entera, ni "módulos con un solo recurso" que solo renombran atributos.
- **Evaluación** de módulos de terceros: criterios para adoptarlos o rechazarlos.

Lo que **no** cubre (se verá después):

- `for_each`/`count`/`dynamic` dentro de módulos → `tf-07`.
- Separar `dev/stg/prod` con los mismos módulos → `tf-08`.
- Múltiples `provider` con `alias` pasados al módulo → `tf-09`.
- `terraform test` sobre un módulo → `tf-12`.
- Module registry interno + SemVer disciplinada + "golden modules" → `tf-14`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`**:
  - `01-local-module-s3-bucket-safe-defaults/` — módulo local didáctico `safe-bucket` que simula un bucket S3 con "safe defaults" (versioning, encryption marker, access-log) usando los providers `local` y `random`. Enseña inputs, outputs y encapsulación sin tocar la nube.
  - `02-registry-module-vpc/` — walkthrough de **consumir** `terraform-aws-modules/vpc/aws` del Registry: pin de versión, inputs, outputs, qué pedirle `init`, y por qué no se corre `apply` (requiere credenciales AWS).
  - `03-compose-modules/` — root module que compone dos módulos locales (`network` y `consumer`) pasando outputs del primero como inputs del segundo; demuestra el patrón root ↔ child.
- **`activities/`**:
  - `01-write-your-first-module/` (guided-lab) — construyes tu propio módulo `greeting-site` reutilizable con inputs tipados, outputs, `README.md` y un ejemplo de uso. El validador comprueba estructura, documentación y que el ejemplo haga `init`/`plan` sin error.
  - `02-adopt-and-evaluate-a-registry-module/` (independiente) — eliges un módulo del Registry público, clonas su fuente, lo lees y escribes una `EVALUATION.md` con criterios objetivos (mantenimiento, pinning de providers, defaults de seguridad, tests, documentación). El validador comprueba la **estructura** de la evaluación, no tu veredicto.
- **`resources/links.md`** — documentación oficial, Registry, guías de diseño.

## Temas y subtemas

1. Qué es un módulo (y qué **no**)
   - Carpeta con `.tf` + convenciones (`main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `README.md`).
   - **No** es un paquete en sentido fuerte: no versiona su propio state; no tiene backend; no "corre" solo.
   - Root module ↔ child module: solo el root tiene backend y providers "de verdad".
2. Fuentes de módulo (`source`)
   - Local: `./modules/x`.
   - Registry público: `terraform-aws-modules/vpc/aws` (opcionalmente con `//modules/sub`).
   - Git: `git::https://github.com/org/repo.git//modules/x?ref=v1.2.3`.
   - HTTP, S3, GCS (menos frecuentes).
3. Versiones y pinning
   - `version = "~> 5.0"` (pessimistic constraint).
   - Lockfile `.terraform.lock.hcl` fija el **hash** del provider, no de la fuente del módulo.
   - Git usa `?ref=` (tag, SHA, branch).
4. Inputs: variables del módulo
   - `type`, `default`, `description`, `sensitive`, `validation`.
   - Qué debería ser input (eje de variación) y qué debería ser constante del módulo.
5. Outputs: contrato de salida
   - Expone solo lo que el consumidor necesita.
   - Si un output es sensible, márcalo `sensitive = true`.
6. Composición
   - El root compone módulos.
   - Un módulo puede llamar a otros módulos (child-of-child).
   - Paso de datos: `module.network.vpc_id` → `module.consumer.vpc_id`.
7. Providers dentro del módulo
   - Un módulo declara `required_providers` pero **no debería** configurar `provider "x" {...}` (es responsabilidad del root).
   - `configuration_aliases` cuando el módulo necesita un provider con alias explícito (p. ej. multi-región).
8. Diseño: límites del buen módulo
   - **No** mega-módulo (abstrae todo; se vuelve inflexible).
   - **No** wrapper trivial de un recurso (no agrega valor).
   - Sí: unidad **cohesiva** (una responsabilidad clara) con **safe defaults** opinados.
9. Evaluación de módulos de terceros
   - Mantenimiento (commits recientes, issues respondidos, CI).
   - Pinning de providers (`required_providers { aws = { version = "~> 5.0" } }`).
   - Defaults de seguridad (encryption, public access block, least-privilege IAM).
   - Tests (`terraform test`, Terratest, examples/).
   - Documentación (`README.md`, generado con `terraform-docs`).
   - Semver respetado.
10. Patrones comunes
    - "Wrapper opinionado" (ajusta defaults de un recurso complejo a tu política).
    - "Primitiva reusable" (una pieza de red, un bucket, un rol).
    - "Golden path" (más propio de `tf-14`).

## Conceptos internos (fundamentos)

- El módulo es **una unidad de encapsulación de HCL + variables + outputs**. Es casi un namespace: cada `module "x" {}` crea una instancia aislada con su propio grafo de recursos, pero **ese grafo se fusiona** con el del root en un único DAG y un único state.
- **Un módulo no tiene su propio state file.** Todos los recursos de todos los módulos llamados por un mismo root viven en el mismo `terraform.tfstate` del root, prefijados por el `module.<name>.` path. Esto es importante: no hay "aislamiento operacional" entre módulos del mismo root — un `terraform destroy` destruye todo.
- **Solo el root tiene backend y providers "de verdad".** Los módulos **declaran** qué providers necesitan (`required_providers`) para compatibilidad; los **inicializa** el root. Si un módulo configura `provider "aws" {region = "us-east-1"}`, el root no puede sobreescribirlo limpiamente — es una mala práctica.
- El contrato del módulo son **variables + outputs**, no la estructura interna. Si cambias un `resource` por otro pero mantienes los mismos outputs con los mismos tipos, los consumidores no notan nada. Si cambias una variable obligatoria, rompes a todos los consumidores (breaking change → major version).
- Los **outputs** son lazy: no se calculan hasta que alguien los lee o hasta `terraform output`. Pero sí viven en el state, visibles con `terraform state show`.
- `source` es **puramente estático** en la configuración (no acepta variables ni interpolación). Terraform tiene que resolverlo durante `init`, antes de evaluar el resto del HCL. Por eso el `version` del Registry también es estático.

## Competencias

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar que un módulo es encapsulación de HCL + variables + outputs, no un paquete versionado con state propio. Explicar por qué solo el root tiene backend y providers "de verdad". Explicar cuándo un módulo rompe su contrato (cambio en inputs obligatorios o en tipos/semántica de outputs). |
| Operativa | Escribir un módulo local con `variables.tf`, `outputs.tf`, `main.tf`, `versions.tf`, `README.md`. Consumirlo desde un root. Pin de versión al consumir un módulo del Registry. Pasar outputs de un módulo como inputs de otro. |
| Arquitectónica | Decidir si un bloque de código merece ser módulo (cohesión, reuso real) o no. Evaluar un módulo de la comunidad con criterios objetivos antes de adoptarlo. Reconocer "mega-módulos" y wrappers triviales y evitarlos. |

## Entregables

- **Módulo propio** (`activities/01`) con:
  - `README.md` que documenta qué hace, inputs, outputs y un ejemplo de uso.
  - `variables.tf` con `type` y `description` en toda variable.
  - `outputs.tf` con `description`.
  - `versions.tf` con `required_version` y `required_providers`.
  - Un subdirectorio `examples/basic/` que lo consume.
- **Evaluación de un módulo de terceros** (`activities/02`): `EVALUATION.md` con las secciones mínimas y veredicto justificado.
- Los dos `tests/validate.sh` de las actividades deben pasar.

## Criterios de evaluación

- Capacidad de diseñar un módulo con **una** responsabilidad clara (no "stack entero", no "wrapper de un recurso").
- Capacidad de **documentar** inputs y outputs sin ambigüedad (tipo, descripción, default razonable, validaciones donde aplique).
- Capacidad de **evaluar** un módulo público con los criterios: ¿mantenido?, ¿pin de providers?, ¿safe defaults de seguridad?, ¿tests?, ¿docs?, ¿respeta semver?
- Capacidad de **justificar un rechazo** (p. ej. "no lo adopto porque no pinnea el provider y hace un `public-read` por default sin flag explícito").

## Secuencia recomendada

1. Lee `theory/lesson.md` completo.
2. Reproduce `examples/01-local-module-s3-bucket-safe-defaults/` (sin red, con providers `local`/`random`).
3. Lee `examples/02-registry-module-vpc/` (walkthrough; no se aplica).
4. Reproduce `examples/03-compose-modules/`.
5. Haz `activities/01-write-your-first-module/`.
6. Haz `activities/02-adopt-and-evaluate-a-registry-module/`.
7. Responde las preguntas de evaluación sin consultar.

## Siguiente

→ `tf-07-expressions-for_each-count-dynamic`: ahora que sabes agrupar código, aprendes a **repetir recursos** (y módulos) con `for_each`/`count` sin convertir el HCL en un enredo.
