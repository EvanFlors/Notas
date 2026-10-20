# tf-01 — Modelo mental y ciclo `plan` / `apply`

## Identificación

- **ID:** `tf-01-mental-model-and-plan-apply`
- **Curso:** `terraform`
- **Nivel:** fundamentos
- **Duración estimada:** 2–3 h
- **Prerrequisitos:** nociones básicas de cloud (T-7.1). Lectura de JSON/YAML. Línea de comandos.

## Objetivo

Construir el **modelo mental correcto** del ciclo declarativo de Terraform **antes de instalar nada**: qué es *estado deseado* vs *state real*, por qué una herramienta declarativa necesita un state persistente, qué significan `+`, `-` y `~` en un plan, qué es *drift* y por qué `apply` por sí solo no lo resuelve.

Al terminar deberías poder, sin consultar docs:

- Explicar el ciclo `init → plan → apply → destroy` **sin referirte a comandos**, en términos de "estado deseado", "state real" y "diff".
- Distinguir IaC declarativa de scripts imperativos y decir cuándo cada una gana.
- Decir qué es un **provider** conceptualmente (plugin que traduce HCL ↔ API) sin haber instalado ninguno.
- Explicar por qué un `+/-/~` aparece en el plan y de dónde viene cada símbolo.
- Explicar qué es **drift** y por qué `apply` sin `refresh` puede no detectarlo.
- Justificar por qué el **state** es necesario, no un capricho de la implementación.

Este módulo es deliberadamente **"antes de instalar nada"**: no hay `terraform` binario en los ejemplos. La instalación y el primer provider se cubren en `tf-02`.

## Alcance

Este módulo cubre:

- IaC vs scripts imperativos (`bash` + `aws create ...`): reproducibilidad, idempotencia, orden.
- Declarativo vs imperativo: *qué* vs *cómo*.
- Qué es un **provider** (plugin que mapea HCL ↔ API de un servicio).
- El ciclo `init → plan → apply → destroy` **conceptual**.
- Qué es el **state** y por qué una herramienta declarativa lo necesita (no todas las APIs exponen de forma barata y correcta todo lo que creamos ni cómo mapearlo a nuestro código).
- Qué significan `+`, `-` y `~` en el output del plan — y por qué aparecen.
- **Drift**: cambios manuales fuera de Terraform.
- **Idempotencia**: aplicar el mismo código dos veces no debería cambiar nada.

Lo que **no** cubre (vendrá después):

- Instalación de Terraform, `tfenv`, lockfile → `tf-02`.
- Sintaxis HCL en profundidad, primer `apply` real → `tf-02`.
- Dependencias, `data` sources, grafo → `tf-03`.
- Formato del state, `state mv/rm`, backends → `tf-05`.
- Internals del algoritmo del plan y refresh → `tf-10`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones (≈ 2 h de lectura reflexiva).
- **`examples/`** — ejemplos conceptuales (no requieren Terraform instalado):
  - `01-declarative-vs-imperative-pseudocode/` — contrasta en pseudocódigo "cómo lo harías con un script" vs "cómo lo describes con HCL".
  - `02-plan-walkthrough-reading/` — recorrido comentado por un output capturado de `terraform plan` explicando `+`, `-`, `~` y por qué aparece cada uno.
- **`activities/`** — dos actividades **conceptuales e independientes**:
  - `01-draw-the-cycle/` — **independent, conceptual**. Produce un `MAP.md` con diagrama ASCII del ciclo `init → plan → apply → destroy` y responde 7 preguntas numeradas.
  - `02-why-do-we-need-state/` — **independent, conceptual**. Produce un `WRITEUP.md` que argumenta por qué una herramienta declarativa necesita state, qué pasaría sin él y qué es drift. 7 preguntas numeradas.
- **`resources/links.md`** — specs, docs y lecturas verificables.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar el ciclo declarativo sin referirte a comandos. Diferenciar *estado deseado* / *state real* / *infra real*. Decir qué es un provider sin haber instalado ninguno. Explicar drift e idempotencia. |
| Operativa | Leer un plan y señalar qué recursos se crean (`+`), destruyen (`-`), modifican in-place (`~`) o se reemplazan (`-/+`). Reconocer un plan "sorprendente" como posible drift. |
| Arquitectónica | Dado un escenario (p. ej. "mi compañero cambió un recurso por consola"), razonar qué verá Terraform en el próximo plan y por qué. Justificar por qué el state nunca puede ser opcional en Terraform. |

## Criterios de evaluación

- Lección leída y preguntas de evaluación respondidas (`theory/lesson.md` §12).
- Actividad 01 entregada: `MAP.md` con el ciclo diagramado y las 7 preguntas respondidas.
- Actividad 02 entregada: `WRITEUP.md` argumentando por qué el state es necesario, con las 7 preguntas respondidas.
- `tests/validate.sh` de cada actividad pasa (chequeo estructural; la semántica la calibras contra `solution/*-reference.md`).

## Secuencia recomendada

1. Lee `theory/lesson.md` completo (una pasada, sin consultar nada externo).
2. Lee `examples/01-declarative-vs-imperative-pseudocode/` — contrasta las dos aproximaciones.
3. Lee `examples/02-plan-walkthrough-reading/` — asimila los símbolos del plan.
4. Haz la actividad `01-draw-the-cycle/` — fija el ciclo en tu cabeza.
5. Haz la actividad `02-why-do-we-need-state/` — fija por qué el state existe.
6. Responde las preguntas de evaluación de la lección sin re-leer.

## Siguiente

→ `tf-02-setup-hcl-first-provider`: instalar Terraform, aprender HCL básico y correr el ciclo completo contra un provider "seguro" (`null`, `random`, `local`, `http`) sin tocar cloud ni pagar nada.
