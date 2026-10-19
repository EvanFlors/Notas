# jk-03 — Declarative Pipeline (Jenkinsfile versionado)

## Identificación

- **ID:** `jk-03-declarative-pipeline-jenkinsfile`
- **Curso:** `jenkins`
- **Nivel:** intermedio
- **Duración estimada:** 3 h
- **Prerrequisitos:** `jk-02-install-ui-freestyle-vs-pipeline` (Jenkins corriendo y primer pipeline job).

## Objetivo

Escribir pipelines **declarative** versionados en un `Jenkinsfile` que vive en el repositorio. Al terminar deberías poder diseñar un pipeline moderno (`lint → test → build → push → deploy`) con `agents`, `stages`, `parallel`, `when`, `post`, `withCredentials` e `input` para gates manuales, sin caer en `script {}` como primer recurso ni en bloques Groovy sueltos sin estructura.

## Alcance

Este módulo cubre:

- **Sintaxis Declarative Pipeline** completa: `pipeline { agent, environment, parameters, options, triggers, stages, post }`.
- **Agents** por pipeline o por `stage` (`agent any`, `agent none`, `agent { docker { image '...' } }`, `agent { label '...' }`).
- **Steps** útiles: `sh`, `withEnv`, `withCredentials`, `dir`, `stash` / `unstash`, `archiveArtifacts`, `junit`, `publishHTML`.
- **Post actions**: `always`, `success`, `failure`, `unstable`, `changed`, `fixed`.
- **Condicionales `when`**: `branch`, `expression`, `environment`, `changeRequest`, `anyOf`, `allOf`, `not`.
- **Parallel stages** y `failFast`.
- **Gates manuales** con `input` y timeout defensivo.
- **Credentials binding**: `credentials('id')` vs `withCredentials { ... }`.
- **Linting**: `pipeline-model-definition` plugin, `jenkins-cli declarative-linter`, validación estructural con `grep` cuando no hay Jenkins arrancado.

Lo que **no** cubre (se verá después):

- **Scripted Pipeline** y **Shared Libraries** → `jk-04`.
- **Agents distribuidos y Kubernetes plugin** → `jk-05`.
- **JCasC / Job DSL / Blue Ocean** → `jk-06`.
- **RBAC, credentials store seguro, script approval, Vault plugin productivo** → `jk-07`.

Las dos actividades son **puramente locales** sobre archivos `Jenkinsfile`: no hace falta un Jenkins corriendo para completarlas. El validador comprueba la **estructura del Jenkinsfile** mediante `grep` (y, opcionalmente, el `declarative-linter` si tienes `jenkins-cli` configurado).

## Materiales

- **`theory/lesson.md`** — lección profunda con 10 secciones.
- **`examples/`** — ejemplos de referencia (lectura y análisis, no ejecución):
  - `01-declarative-skeleton/` — esqueleto mínimo con todos los bloques top-level (`agent`, `environment`, `options`, `parameters`, `stages`, `post`).
  - `02-parallel-stages/` — pipeline con `parallel` + `failFast` + `when` por rama.
  - `03-withcredentials-vault/` — `withCredentials` con `string`, `usernamePassword`, `file` y comparación con `credentials('id')` directo.
- **`activities/`** — dos actividades independientes:
  - `01-port-gha-workflow-to-jenkinsfile/` — portar un workflow de GitHub Actions al `Jenkinsfile` equivalente (guided-lab).
  - `02-add-manual-gate/` — añadir un gate manual con `input` a un pipeline existente y proteger el gate con `timeout` + `post { aborted }` (independent).
- **`resources/links.md`** — referencias oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la diferencia entre Declarative y Scripted, por qué `agent none` + `agent` por `stage` es el patrón más seguro, y en qué casos `script {}` es aceptable. |
| Operativa | Escribir un `Jenkinsfile` declarative que lint-ea, testea, construye, publica y despliega con `when` por rama y `input` para prod. |
| Arquitectónica | Decidir dónde adjuntar un `agent`, cómo partir `stages` paralelos y cómo exponer `parameters` sin convertir el pipeline en un formulario infinito. |

## Criterios de evaluación

- Dado un `Jenkinsfile` mal estructurado, identificar los bloques fuera de lugar y proponer el refactor correcto.
- Explicar por qué `post { always { ... } }` es imprescindible para `junit`/`archiveArtifacts` en pipelines que fallan.
- Justificar cuándo usar `credentials('id')` como variable de entorno vs `withCredentials { ... }` como bloque.
- Entregar las dos actividades con sus validadores estructurales en verde (`0 issue(s)`).

## Entregables

- **`Jenkinsfile`** portado desde un workflow GHA, con `agent`, `environment`, `stages` (lint/test/build/push/deploy), `post` y `when` (sale de la actividad `01`).
- **`Jenkinsfile`** con **gate manual** (`input` + `timeout` + `post { aborted }`) adjunto al stage de deploy a prod (sale de la actividad `02`).

## Costos

**Ninguno.** Todo el módulo se desarrolla localmente contra archivos `Jenkinsfile` y validadores `bash`. No se requiere un Jenkins arrancado para completar las actividades. Si decides ejecutar los pipelines en el Jenkins local de `jk-02`:

- **Jenkins LTS en Docker**: gratis.
- **Agents efímeros con Docker**: coste local (CPU/RAM del laptop).
- **Credenciales de prueba**: cadenas placeholder — no uses credenciales reales en una instalación de laboratorio.

## Siguiente módulo

→ `jk-04-scripted-pipeline-and-shared-libraries` — Scripted Pipeline (Groovy puro) y Shared Libraries para encapsular pipelines estándar de la organización.
