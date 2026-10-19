# jk-02 — Instalar Jenkins y primer job: Freestyle vs Pipeline

## Identificación

- **ID:** `jk-02-install-ui-freestyle-vs-pipeline`
- **Curso:** `jenkins`
- **Nivel:** beginner
- **Duración estimada:** 2 h
- **Prerrequisitos:** `jk-01-why-still-jenkins-and-when-not`, curso **docker** (manejo basico de `docker run`, volumenes y puertos).

## Objetivo

Instalar un Jenkins local reproducible con la imagen oficial `jenkins/jenkins:lts`, recorrer la UI minima necesaria (Dashboard, Manage Jenkins, Credentials, People, Build Queue) y hacer el **mismo "hello world" de dos formas** — **Freestyle** (configurado por UI) y **Pipeline** (Jenkinsfile versionado) — para interiorizar por que, en 2026, **todo job nuevo debe ser Pipeline** y los Freestyle sobreviven solo como pasivo legacy a migrar.

## Alcance

Este modulo cubre:

- **Instalacion con Docker** (imagen oficial `jenkins/jenkins:lts`), `JENKINS_HOME` como volumen persistente, exposicion de puerto `8080`, extraccion del `initialAdminPassword`.
- **Setup wizard**: admin user, suite de **plugins recomendados** (y por que esa suite ya empieza a ser demasiado).
- **UI tour**: Dashboard, Manage Jenkins (System, Plugins, Nodes, Credentials, Security), People, Build Queue, Build Executor Status.
- **Freestyle jobs**: creacion por UI, configuracion por casillas, `config.xml` dentro de `$JENKINS_HOME` como **unica fuente de verdad** no versionada.
- **Pipeline jobs**: `Jenkinsfile` versionado en Git, `pipeline { agent / stages / steps / post }` minimo, SCM polling vs webhooks (conceptual).
- **Folders** y **views** como organizacion basica.
- Conceptos: **workspace**, **build artifact**, **retention** (`buildDiscarder`).

Lo que **no** cubre (se vera despues):

- Sintaxis declarative completa, `environment`, `when`, `parallel`, `withCredentials` → `jk-03`.
- Scripted Pipeline y Shared Libraries → `jk-04`.
- Agents distribuidos y Kubernetes plugin → `jk-05`.
- JCasC, Job DSL, Blue Ocean → `jk-06`.
- RBAC, hardening, script approvals → `jk-07`.

Este modulo es **mayoritariamente practico local**. Levanta Jenkins con Docker, hace click en la UI, escribe un `Jenkinsfile` minimo y lo ejecuta. No se usa cuenta cloud, no se instalan plugins mas alla de la suite recomendada por el wizard.

## Materiales

- **`theory/lesson.md`** — leccion profunda en 10 secciones (instalacion, UI, Freestyle vs Pipeline, `config.xml` vs `Jenkinsfile`, workspace/artifact/retention, por que Freestyle hoy es anti-patron).
- **`examples/`** — ejemplos demostrativos (lectura y referencia, con comandos reproducibles cuando aplica):
  - `01-jenkins-docker-up/` — levantar Jenkins local con `jenkins/jenkins:lts` + Docker, obtener el admin password, tour de UI.
  - `02-freestyle-hello-world/` — crear un Freestyle job que ejecuta `echo "hello"` + `uname -a` y mostrar su `config.xml`.
  - `03-pipeline-hello-world/` — mismo "hello world" en un `Jenkinsfile` declarative minimo, cargado por **Pipeline script** inline y referencia conceptual a **Pipeline script from SCM**.
- **`activities/`** — dos actividades:
  - `01-first-pipeline-job/` — **guided-lab**: levantar Jenkins con Docker y escribir el primer `Jenkinsfile` declarative con `agent`, `stages`, `steps`, `post`.
  - `02-explore-jenkins-home/` — **independent**: inventariar `$JENKINS_HOME` (jobs, builds, workspace, config.xml, plugins) y escribir un `INVENTORY.md` razonando por que Freestyle no es versionable.
- **`resources/links.md`** — referencias oficiales (Jenkins Handbook, Pipeline Syntax, Docker image, LTS).

## Competencias esperadas

| Dimension | Al terminar deberias |
|-----------|----------------------|
| Conceptual | Explicar por que un Freestyle vive en `config.xml` no versionado y un Pipeline vive en `Jenkinsfile` versionado; nombrar los bloques minimos de un pipeline declarative. |
| Operativa | Levantar Jenkins local con `docker run`, completar el setup wizard, crear un Freestyle y un Pipeline job equivalentes, inspeccionar `$JENKINS_HOME`. |
| Arquitectonica | Justificar por que todo job nuevo debe ser Pipeline en 2026, aun si la organizacion ya tiene cientos de Freestyle; proponer un primer paso de migracion. |

## Criterios de evaluacion

- Dado un screenshot de un Freestyle, identificar donde queda guardada su configuracion y por que es un riesgo.
- Dado un `Jenkinsfile` minimo, identificar los bloques `pipeline`, `agent`, `stages`, `stage`, `steps`, `post` y explicar que hace cada uno.
- Enumerar al menos 3 razones concretas por las que Pipeline-as-code gana a Freestyle en mantenibilidad, auditoria y onboarding.
- Entregar las dos actividades con sus validadores estructurales en verde.

## Entregables

- **Jenkins local funcionando** con la imagen `jenkins/jenkins:lts` + 1 Pipeline job que ejecuta un `Jenkinsfile` declarative minimo (sale de la actividad `01`).
- **`INVENTORY.md`** describiendo el `$JENKINS_HOME` observado (sale de la actividad `02`).

## Costos

**Ninguno.** Todo corre localmente contra la imagen oficial `jenkins/jenkins:lts` dentro de Docker. Requiere Docker instalado y en ejecucion. Si no tienes Docker, los validadores de las actividades reportan `SKIP` para los chequeos que lo requieren y solo validan los entregables documentales.

## Siguiente modulo

→ `jk-03-declarative-pipeline-jenkinsfile` — sintaxis Declarative completa: `environment`, `parameters`, `options`, `triggers`, `when`, `parallel`, `post`, `withCredentials`, linting con `declarative-linter`.
