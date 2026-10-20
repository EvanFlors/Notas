# gl-02 — `.gitlab-ci.yml`, pipelines y runners

## Identificación

- **ID:** `gl-02-gitlab-ci-yml-pipelines-runners`
- **Curso:** `gitlab-cicd`
- **Nivel:** fundamentos (beginner)
- **Duración estimada:** 3 h
- **Prerrequisitos:** `gl-01-model-and-mapping-to-gha`.

## Objetivo

Escribir tu primer `.gitlab-ci.yml`, interiorizar la **anatomía del pipeline** (keys top-level, jobs, stages) y entender los **tipos de runner** (shared SaaS, group, project) y cómo se seleccionan con `tags:`. Al terminar deberías poder portar un workflow "hello-world" de GitHub Actions a GitLab, diagnosticar un job que queda `pending` por falta de runner y defender *shared* vs *group runner* por escrito.

## Alcance

Este módulo cubre:

- **Anatomía de `.gitlab-ci.yml`**: keys top-level (`stages`, `variables`, `default`, `workflow`, `include`, `image`, `services`, `before_script`, `after_script`) y la convención de que *cualquier otra key* es el nombre de un job.
- **Modelo pipeline → stages → jobs**: cómo se ejecutan en orden de stage y en paralelo dentro de un stage; qué significa "wall clock = max(duración de cada stage)".
- **Job keys mínimas**: `stage`, `script`, `image`, `tags`, `rules`/`only`/`except` (con la nota explícita de que `only/except` es *legacy* — usar `rules`).
- **Docker executor por default**: cómo `image:` cambia el entorno de ejecución y cómo `services:` levanta sidecars (p. ej. Postgres).
- **`tags:` como contrato runner↔job**: por qué un job sin tags espera un runner "cualquiera" compatible y por qué uno con tags concretos puede quedar `pending` indefinidamente.
- **Tipos de runner**: **Shared** (SaaS, hospedados por GitLab, por tier/sistema), **Group** (compartidos por un grupo/subgrupo), **Project** (dedicados a un proyecto); comparación con **GitHub-hosted** y **self-hosted** de GHA.
- **Registration tokens vs authentication tokens**: por qué los primeros están deprecados y la vía moderna es `glab runner create` + authentication token.
- **UI del pipeline**: status, retry *job* vs retry *pipeline*, downstream, child/parent (mención, se profundiza en `gl-04`).

Lo que **no** cubre (se verá después):

- Variables, secretos, `protected`/`masked`, ID Tokens → `gl-03`.
- `rules:`, `workflow:`, `needs:`, matrices y DAG → `gl-04`.
- `include:`, `extends:`, CI/CD Components → `gl-05`.
- Executors avanzados (Fleeting, Kubernetes), DinD, OIDC a cloud → `gl-06`.
- Environments y Review Apps → `gl-07`.
- Scanners nativos y Container Registry → `gl-08`.

Este módulo es **mayoritariamente escritura de YAML + análisis de runner selection**. **No se requiere ejecutar el pipeline en `gitlab.com`** para pasar la validación: todos los validadores son estructurales (Python/`yaml`, `grep`). Si quieres verificarlo en vivo, basta con un proyecto free en `gitlab.com` y los runners *shared*.

## Materiales

- **`theory/lesson.md`** — lección profunda con 10 secciones: anatomía YAML, modelo stage/job, tags, runners, pending jobs, mapping desde GHA.
- **`examples/`** — tres ejemplos leíbles y, si quieres, ejecutables:
  - `01-first-pipeline/` — el `.gitlab-ci.yml` mínimo con un único job y `script: echo hello`.
  - `02-stages-and-jobs/` — tres stages (`lint`, `test`, `build`) con un job por stage y uno que corre en paralelo.
  - `03-docker-executor-image/` — mismo pipeline usando `image: python:3.12-slim` y `services: postgres:16` para ilustrar el executor Docker.
- **`activities/`** — dos actividades **independientes**:
  - `01-port-hello-world-from-gha/` — portar un workflow `hello.yml` de GHA a `.gitlab-ci.yml` con 3 stages (`lint`, `test`, `build`). Validador estructural con `python3 -c 'import yaml ...'`.
  - `02-shared-vs-group-runner/` — ADR corto decidiendo *shared SaaS runner* vs *group runner* para un escenario dado, con tabla de trade-offs. Validador estructural con `grep`.
- **`resources/links.md`** — referencias oficiales (docs de `.gitlab-ci.yml`, runners, SaaS runner pricing).

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué `stage` ordena y `needs` paraleliza; qué significa un job sin `tags:`; diferencia shared/group/project runner. |
| Operativa | Escribir un `.gitlab-ci.yml` con 3 stages y 4 jobs sintácticamente válido; añadir `image:` y `services:` cuando corresponda. |
| Diagnóstica | Dado un job en `pending`, enumerar las 3 causas más frecuentes (sin runner con tags; runner offline; `rules:` que no matchea). |
| Arquitectónica | Justificar *shared* vs *group runner* por caso (tier Free, workloads con secretos, runners con tooling específico). |

## Criterios de evaluación

- Entrega las dos actividades con sus validadores estructurales en verde (`0 issue(s)` en el validador global).
- El `.gitlab-ci.yml` producido en la actividad 01 parsea con `python3 -c 'import yaml; yaml.safe_load(open("…"))'` y contiene **3 stages** y **≥3 jobs**.
- El ADR de la actividad 02 cita explícitamente *shared*, *group*, al menos **3 criterios de decisión** y **2 alternativas descartadas**.
- Puedes explicar sin notas por qué `only/except` es *legacy* y qué lo reemplaza.

## Entregables

- `.gitlab-ci.yml` del *port* GHA → GitLab (sale de la actividad `01`).
- `ADR-RUNNERS.md` con la decisión *shared* vs *group runner* (sale de la actividad `02`).

## Costos

**Ninguno.** Todo el módulo se desarrolla localmente contra archivos YAML y Markdown. No se requiere proyecto activo en `gitlab.com`. Si decides ejecutar los ejemplos:

- **Shared SaaS runners** en plan Free: 400 minutos CI/CD/mes (sujeto a cambios, verificar en `gitlab.com`). Suficiente para los 3 ejemplos.
- **Group / project runners** propios: coste del host (VM/K8s pod); fuera del alcance de este módulo.

## Siguiente módulo

→ `gl-03-variables-and-secrets-protected-and-masked` — jerarquía de variables (Instance → Group → Project → Environment → Pipeline), flags `protected`/`masked`, integración con Vault vía **ID Tokens** (OIDC).
