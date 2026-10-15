# tf-05 — State basics

## Identificación

- **ID:** `tf-05-state-basics`
- **Curso:** `terraform`
- **Nivel:** fundamentos
- **Duración estimada:** 3 h
- **Prerrequisitos:** `tf-02-setup-hcl-first-provider` (saber ejecutar el ciclo `init → plan → apply → destroy` localmente).

## Objetivo

Entender el **state de Terraform como artefacto operacional de primer orden**: qué guarda, por qué guarda valores en claro, cómo se inspecciona (`list`, `show`), cómo se mueve (`mv`) y se saca (`rm`) sin romper nada, y por qué el backend donde vive determina la postura de seguridad del equipo entero.

## Alcance

Este módulo cubre:

- Formato del state: JSON versionado, `serial`, `lineage`, `resources[]`.
- Comandos: `terraform state list`, `show`, `mv`, `rm`, `pull`, `push`.
- Backend **local** por default; introducción conceptual al backend remoto (se profundiza en `tf-11`).
- Por qué el state contiene **valores en claro** (atributos computados, outputs, incluso los marcados `sensitive`).
- **Locking**: concepto y cuándo se usa (detalle en `tf-11`).
- `terraform refresh` y por qué es **implícito** en `plan` (y por qué desactivarlo es peligroso).
- `terraform import` **conceptual** (adopción de recursos preexistentes; detalle en `tf-09`/`tf-14`).

Lo que **no** cubre (va después):

- Backends remotos reales (`s3+DynamoDB`, `gcs`, `azurerm`, HCP) → `tf-11`.
- Internals del algoritmo del plan y del grafo → `tf-10`.
- `moved`/`removed` blocks como alternativa a `state mv` → `tf-09`.
- Workspaces y state por ambiente → `tf-08`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`** — ejemplos ejecutables localmente, sin coste y sin cloud:
  - `01-state-list-and-show/` — pasear por un state con los comandos de inspección.
  - `02-sensitive-in-state-demo/` — demostración de que `sensitive = true` oculta la CLI pero **no** cifra el state.
- **`activities/`** — dos actividades:
  - `01-rename-resource-with-state-mv/` — guided-lab: refactor de nombre en HCL + `terraform state mv` para que el plan quede en no-op.
  - `02-inspect-state-of-a-provisioned-stack/` — independent: aprovisionar un stack chico y extraer atributos con `terraform state show`.
- **`resources/links.md`** — referencias oficiales.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar qué guarda el state y por qué una herramienta declarativa lo necesita. Diferenciar `estado deseado` (HCL) de `estado real conocido` (state) de `estado real` (cloud). Explicar qué es *drift*. Justificar por qué `sensitive = true` **no** sustituye a un sistema de secretos. |
| Operativa | Navegar un state con `list` y `show`; renombrar un recurso en HCL **sin** destroy+create usando `state mv`; sacar un recurso del state (`rm`) con criterio; distinguir cuándo basta refactor y cuándo hace falta `import`. |
| Arquitectónica | Justificar por qué el state **nunca va a Git**; proponer los controles mínimos (acceso, cifrado, versionado, locking, auditoría) para un backend remoto. |

## Criterios de evaluación

- Stack del ejemplo 01 aplicado y state inspeccionado con `terraform state list` + `show` (notas con 2–3 recursos).
- Actividad 01 cerrada con `terraform plan` en **no-op** después del renombre (validada por `tests/validate.sh`).
- Actividad 02 cerrada con `NOTES.md` que extrae y comenta los atributos pedidos (validada por `tests/validate.sh`).
- Respuesta argumentada a las preguntas de evaluación de `theory/lesson.md` §12.
- Capacidad de responder en 1–2 frases: *¿por qué el state nunca va a Git, y qué controles mínimos exijo a un backend remoto?*

## Secuencia recomendada

1. Lee `theory/lesson.md` entero (una pasada, sin ejecutar nada).
2. Reproduce `examples/01-state-list-and-show/` paso a paso.
3. Reproduce `examples/02-sensitive-in-state-demo/` y abre el `terraform.tfstate` resultante con un editor.
4. Haz `activities/01-rename-resource-with-state-mv/` (guided).
5. Haz `activities/02-inspect-state-of-a-provisioned-stack/` (independent — valida comprensión real).
6. Responde `theory/lesson.md` §12 sin consultar.

## Siguiente

→ `tf-06-modules`: encapsular configuración en módulos reutilizables (necesitas tener el modelo del state claro para entender por qué el *root module* es el único con backend).
