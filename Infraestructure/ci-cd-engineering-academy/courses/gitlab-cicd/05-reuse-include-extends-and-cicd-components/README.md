# gl-05 — Reutilización: `include`, `extends` y CI/CD Components

## Identificación

- **ID:** `gl-05-reuse-include-extends-and-cicd-components`
- **Curso:** `gitlab-cicd`
- **Nivel:** intermedio
- **Duración estimada:** 3 h
- **Prerrequisitos:** `gl-04` (reglas, DAG, matrices).

## Objetivo

Dominar los tres mecanismos de reutilización de GitLab CI/CD y saber **cuándo** usar cada uno: `extends:` para herencia local de jobs, `include:` para traer YAML de otros lugares, y **CI/CD Components** como el estándar moderno y versionado para compartir pipelines entre proyectos. Al terminar deberías poder convertir un pipeline duplicado en un **componente consumible** por otros proyectos y defender esa decisión frente a `include:remote:` o composite actions de GHA.

## Alcance

Este módulo cubre:

- **`extends:`** sobre *hidden jobs* (`.base-job`) para herencia local dentro de un `.gitlab-ci.yml`.
- **`include:`** en sus cuatro variantes: `local`, `project`, `remote`, `template`.
- **CI/CD Components** (GA desde 2023): estructura obligatoria del repositorio (`templates/<name>/template.yml`), **contrato** `spec:inputs:` con tipos, documentación mínima en `README.md`, publicación al **CI/CD Catalog** (interno o público) y consumo con `include: - component:`.
- **SemVer** para componentes (`~latest`, tags inmutables, `main` solo para dev).
- Diferencia frente a **reusable workflows** y **composite actions** de GitHub Actions (contrato tipado vs convención).
- Trade-offs: cuándo basta un `extends:` local, cuándo conviene `include: project:` del propio grupo, y cuándo justifica el salto a un componente publicado.

Lo que **no** cubre (se verá después):

- `include: template:` para los scanners de seguridad nativos → `gl-08`.
- Compliance pipelines que fuerzan include → `gl-09`.
- Gobernanza del CI/CD Catalog como plataforma interna → `gl-10`.

## Materiales

- **`theory/lesson.md`** — lección con los tres mecanismos, el contrato de un componente, SemVer y comparación con GHA.
- **`examples/`** (lectura y análisis):
  - `01-extends-hidden-job/` — refactor de jobs duplicados a `.base-job` con `extends`.
  - `02-include-local-vs-project/` — mismo pipeline servido desde `local`, `project` y `remote`; cuándo elegir cada uno.
  - `03-cicd-component-publish-and-consume/` — anatomía de un componente publicado (`templates/<name>/template.yml` + `spec:inputs:` + `README.md`) y pipeline que lo consume.
- **`activities/`** — dos actividades **independientes**:
  - `01-extract-component-from-pipeline/` — refactorizar un pipeline duplicado en un **CI/CD Component** con `spec:inputs:` y un consumidor que lo use.
  - `02-adr-components-vs-includes/` — **ADR** justificando `component` vs `include` vs `extends` para 3 escenarios reales.
- **`resources/links.md`** — documentación oficial de GitLab y referencias cruzadas con GHA.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la diferencia entre `include:remote:` y un **CI/CD Component**; por qué el contrato `spec:inputs:` es el motivo principal del salto; qué significa SemVer en un componente. |
| Operativa | Extraer un job repetido a un componente con `spec:inputs:` tipados; consumirlo con `include: - component:` y pasarle inputs. |
| Arquitectónica | Decidir entre `extends`, `include: project:` y `component` para 3 casos distintos y defenderlo por escrito. |

## Criterios de evaluación

- Lee un `.gitlab-ci.yml` con 3 jobs duplicados y propone el refactor correcto (extends local o componente, con justificación).
- Dado un componente con `spec:inputs:`, lo invoca correctamente desde un consumer pipeline con inputs válidos.
- Entrega las dos actividades con sus validadores estructurales en verde.

## Entregables

- Un **CI/CD Component** propio con `templates/<name>/template.yml` + `README.md` + `spec:inputs:` y un pipeline consumidor funcional (sale de la actividad `01`).
- Un **ADR** `ADR-REUSE-STRATEGY.md` con la decisión por mecanismo para 3 escenarios (sale de la actividad `02`).

## Costos

**Ninguno.** Todo el módulo se desarrolla localmente contra archivos YAML. No se requiere proyecto GitLab real: los validadores comprueban estructura con `python3` + `yaml`. Si decides publicar el componente contra un GitLab real (SaaS o self-managed), el consumo desde el CI/CD Catalog interno es gratis en todos los planes; solo los minutos de runner se contabilizan.

## Siguiente módulo

→ `gl-06-runners-deep-executors-fleeting-and-oidc` — ejecutores (`shell`, `docker`, `kubernetes`), autoscaling con Fleeting, DinD seguro y federación OIDC a AWS/GCP sin keys.
