# tf-08 — Ambientes: workspaces vs directorios

## Identificación

- **ID:** `tf-08-environments-workspaces-vs-directories`
- **Curso:** `terraform`
- **Nivel:** intermedio
- **Duración estimada:** 4 h
- **Prerrequisitos:** `tf-04-variables-outputs-locals`, `tf-05-state-basics`, `tf-06-modules`.

## Objetivo

Modelar `dev`, `stg` y `prod` **sin acoplar código con datos**: elegir y defender el patrón de separación de ambientes (directorios vs workspaces vs Terragrunt-like), entender por qué los workspaces de CLI **no** son un mecanismo de aislamiento fuerte, y entregar un stack de tres ambientes que comparte un módulo pero *no* comparte state ni credenciales.

## Alcance

Este módulo cubre:

- Qué es un **workspace de CLI** y qué significa realmente en el state remoto (un prefijo, no un sandbox).
- El patrón **directorios separados por ambiente** con módulos compartidos.
- El patrón **Terragrunt-like** (HCL fino por ambiente que apunta a módulos versionados).
- **Monorepo vs multi-repo** de infraestructura.
- Por qué un `if var.env == "prod"` dentro de un módulo es una señal de diseño roto.
- Diseño de **feature environments efímeros** usando workspaces de forma legítima.

Lo que **no** cubre (se verá después):

- Backend remoto con locking (S3/GCS/HCP) → `tf-11`.
- CI/CD con `plan` en PR y `apply` en merge → `tf-13`.

## Materiales

- **`theory/lesson.md`** — lección profunda, 12 secciones.
- **`examples/`**
  - `01-env-per-directory/` — `envs/{dev,stg,prod}/` cada uno con **su propio state local** y un módulo compartido en `modules/app/`.
  - `02-workspaces-ephemeral-envs/` — un único stack usado con `terraform workspace` para crear sandboxes efímeros tipo "feature/mi-rama".
- **`activities/`**
  - `01-split-stack-into-three-envs/` (guided-lab) — partir un stack monolítico en tres ambientes con módulo compartido; validador automático.
  - `02-adr-env-strategy/` (independent, ADR) — redactar un ADR eligiendo el patrón adecuado para una organización dada.
- **`resources/links.md`** — documentación oficial y lecturas.

## Temas y subtemas

1. Qué es un "ambiente" en IaC (no es un flag, es un *contrato operacional*).
2. Workspaces de CLI
   - `terraform workspace new/list/select/delete`.
   - `terraform.workspace` como expresión.
   - Qué cambia realmente en el backend (sólo el prefijo del state file).
3. Patrón **directorios por ambiente**
   - `envs/dev`, `envs/stg`, `envs/prod` cada uno root module.
   - `modules/<nombre>` compartidos.
   - Backend distinto por ambiente (bucket/key/credenciales).
4. Patrón **Terragrunt-like**
   - `terragrunt.hcl` por ambiente que apunta a un módulo versionado remoto.
   - Reduce la duplicación de boilerplate.
5. **Monorepo vs multi-repo** de infra.
6. **Anti-patrones**
   - `if var.environment == "prod"` dentro de módulos.
   - Un único workspace compartido por `stg` y `prod`.
   - Mismo backend/credenciales para todos los ambientes.
7. Feature environments **efímeros** con workspaces (uso legítimo).
8. Convenciones de nombres (`project-env-component`) y tags.
9. Secretos y configuración por ambiente (dónde viven *fuera* del repo).
10. Blast radius: qué pasa si corres `destroy` en el ambiente equivocado.
11. Promoción entre ambientes (los módulos se promueven por versión, los ambientes por `terraform apply`).
12. Criterios para elegir el patrón.

## Conceptos internos (fundamentos)

- Un **workspace de Terraform** sólo cambia el *key* del state en el backend (de `env:/default/path/to/key` a `env:/<nombre>/path/to/key`). **Nada más.** Las credenciales, el bucket, la cuenta cloud, los límites IAM — todo lo demás es el mismo. Esto los hace útiles para *sandboxes del mismo blast radius* (feature envs), y pésimos para separar prod del resto.
- Separar `envs/prod/` en un directorio con **su propio backend y sus propias credenciales** es la práctica más defensible: un pipeline mal configurado o un `apply` manual descuidado **no puede** tocar prod porque ni siquiera tiene credenciales para escribir en su backend.
- Un módulo con `count = var.environment == "prod" ? 1 : 0` acopla el *qué* con el *dónde*. El módulo pierde testabilidad (su comportamiento depende de un string mágico) y los ambientes dejan de ser datos — se vuelven ramas de código.
- La promoción `dev → stg → prod` **no** es "copiar `.tf` entre directorios". Es: *subir la versión del módulo que cada ambiente consume*. El código es el mismo; cambia el *pin* de versión.

## Competencias

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar qué cambia (y qué no) al hacer `terraform workspace new prod`. Explicar por qué un `if env == "prod"` en un módulo es una señal de diseño roto. |
| Operativa | Diseñar un stack con `envs/{dev,stg,prod}/` cada uno con su propio state, compartiendo módulos; promover un cambio entre ambientes vía versión. |
| Arquitectónica | Elegir y defender el patrón de ambientes para una organización dada (monorepo vs multi-repo, workspaces vs directorios, Terragrunt sí/no), listando riesgos específicos. |

## Entregables

- Un **ADR** (`activities/02-adr-env-strategy/`) con la estrategia elegida para una organización ficticia dada, listando trade-offs y riesgos.
- Un **stack de tres ambientes** (`activities/01-split-stack-into-three-envs/`) con `envs/{dev,stg,prod}/` compartiendo un módulo en `modules/app/`, cada ambiente con su propio `terraform.tfstate` local y `plan` limpio después del `apply` inicial.

## Criterios de evaluación

- Capacidad de enumerar **al menos tres riesgos concretos** de usar un único workspace para `prod` y `stg` (credenciales, blast radius, confusión operacional, imposibilidad de aplicar policies distintas por ambiente, imposibilidad de aplicar permisos IAM diferenciados sobre el backend, etc.).
- Capacidad de identificar en un módulo ajeno la presencia de `if env == "prod"` o similar y refactorizarlo para que el comportamiento viaje como *input* del módulo, no como ramificación interna.
- Capacidad de explicar, dado un pipeline de CI/CD, por qué separar los backends por ambiente limita el blast radius de una credencial comprometida.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo.
2. Reproduce `examples/01-env-per-directory/` corriendo `init/apply` en cada ambiente y observando que cada uno escribe su propio `terraform.tfstate` local.
3. Reproduce `examples/02-workspaces-ephemeral-envs/` creando dos workspaces (`feature-a`, `feature-b`) y observando el contenido de `terraform.tfstate.d/`.
4. Haz `activities/01-split-stack-into-three-envs/` (refactor).
5. Haz `activities/02-adr-env-strategy/` (ADR, independiente).

## Siguiente

→ `tf-09-providers-deep-and-lifecycle`: `alias`, `lifecycle`, `moved`, `import`, `removed`.
