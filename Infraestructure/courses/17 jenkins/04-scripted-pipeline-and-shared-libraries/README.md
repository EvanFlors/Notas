# jenkins-04 — Scripted Pipeline y Shared Libraries

## Identificación

- **ID:** `jk-04-scripted-pipeline-and-shared-libraries`
- **Curso:** `jenkins`
- **Nivel:** intermediate
- **Duración estimada:** 4 h
- **Prerrequisitos:** `jk-03` (Declarative Pipeline y Jenkinsfile).

## Objetivo

Entender **Scripted Pipeline** (Groovy puro en `node { ... }`), reconocerlo cuando aparece en instalaciones legacy, y aprovechar **Shared Libraries** — el patrón donde vive el 80% del "poder" de Jenkins maduro. Al terminar deberías poder leer una library ajena, escribir una propia con `vars/` + `src/` + `resources/`, versionarla con `@Library('name@tag')` y defender por qué un step `standardBuild()` reemplaza a 200 líneas de `Jenkinsfile` copiadas-y-pegadas por 15 repos.

## Alcance

Este módulo cubre:

- **Scripted vs Declarative**: `node { stage('x') { sh '...' } }` vs `pipeline { agent any; stages { ... } }`; cuándo escapar a `script {}` dentro de un pipeline declarative (último recurso); por qué Declarative gana para código nuevo pero Scripted sigue siendo omnipresente en brownfield.
- **Shared Libraries**: layout obligatorio (`vars/*.groovy` → steps globales invocables como `foo()`; `src/<pkg>/*.groovy` → clases Groovy para lógica no trivial; `resources/<pkg>/*` → ficheros estáticos leíbles con `libraryResource('...')`).
- **Configuración global**: `Manage Jenkins > System > Global Pipeline Libraries` vs libraries por folder.
- **Carga y pinning**: `@Library('acme-ci@v1.3.0')`; estrategia de tagging; por qué `@Library('name@main')` en prod es un *footgun*.
- **Governance**: CODEOWNERS, PR obligatorio, review antes de taggear; `Library step with the same name as a built-in` como anti-patrón.
- **Testing** de libraries: JenkinsPipelineUnit framework (mención conceptual — el curso no monta un controller real para los validadores).
- **Patrones típicos**: `standardBuild()`, `deployToKubernetes()`, `publishArtifact()` como fachadas que encapsulan el pipeline estándar de la org.

Lo que **no** cubre (se verá después):

- Operar agents distribuidos y K8s plugin → `jk-05`.
- JCasC, Job DSL y Blue Ocean → `jk-06`.
- RBAC, credentials hardening, script approval → `jk-07`.

Este módulo es **mayoritariamente estructural + revisión de código Groovy**. No se requiere un Jenkins corriendo: los validadores comprueban que la library tiene el layout correcto, que el `Jenkinsfile` consume la librería con una versión pinneada y que la documentación de intención existe. La ejecución real contra un controller se recomienda como ejercicio opcional, pero queda fuera del scope del validador (ver `theory/lesson.md §8`).

## Materiales

- **`theory/lesson.md`** — lección profunda con 10 secciones (Scripted vs Declarative, layout de library, carga y pinning, patrones típicos, testing, governance, migración desde script embebido).
- **`examples/`** — ejemplos demostrativos (lectura, no ejecución):
  - `01-scripted-vs-declarative/` — mismo pipeline escrito en los dos estilos, lado a lado, con comentarios de qué se pierde y qué se gana.
  - `02-shared-library-skeleton/` — layout mínimo de una library con `vars/`, `src/<org>/<team>/` y `resources/<org>/<team>/`, y cómo se invoca desde un `Jenkinsfile`.
  - `03-pin-library-version/` — cuatro variantes de `@Library` (sin pin, pin a branch, pin a tag, pin a SHA) con el análisis de trade-offs.
- **`activities/`** — dos actividades **independientes**:
  - `01-extract-shared-library/` — refactorizar un `Jenkinsfile` monolítico en una Shared Library propia con `standardBuild()` + `Jenkinsfile` consumidor.
  - `02-write-standard-build-step/` — escribir desde cero el step `standardBuild()` de la org como fachada opinada (parámetros, defaults, notify en `post`).
- **`resources/links.md`** — referencias oficiales (Jenkins Shared Libraries, JenkinsPipelineUnit, CloudBees best practices).

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la diferencia entre `vars/` y `src/`; por qué `@Library('name@main')` es anti-patrón en producción; cuándo escapar a `script {}` dentro de Declarative. |
| Operativa | Leer una Shared Library ajena y predecir qué hace `standardBuild()`; crear una propia con layout correcto; pinnear por tag; invocarla desde un `Jenkinsfile` de 15 líneas. |
| Arquitectónica | Decidir cuándo lógica va en `vars/` (step público, 1 fichero) vs `src/` (clase Groovy con estado y helpers); diseñar la governance (CODEOWNERS, PR, tag) y defender por qué una library sin tests y sin versionado es deuda crítica. |

## Criterios de evaluación

- Dado un `Jenkinsfile` monolítico de 200 líneas, propones un refactor concreto que mueva lógica a `vars/standardBuild.groovy` y clases en `src/`, y defiendes qué queda en el `Jenkinsfile` del repo consumidor.
- Reconoces `@Library('acme-ci@main')` como anti-patrón y propones alternativa (`@tag`, `@sha`).
- Lees una library ajena y mapeas qué hace cada archivo de `vars/`, `src/` y `resources/`.
- Entregas las dos actividades con sus validadores estructurales en verde.

## Entregables

- **Actividad 01**: Shared Library con layout `vars/` + `src/` + `resources/` y un `Jenkinsfile` consumidor que la carga con pin por tag.
- **Actividad 02**: step `standardBuild()` opinado de la org con `README-INTENT.md` que justifique parámetros, defaults y gates obligatorios.

## Costos

**Ninguno.** Todo el módulo se desarrolla con archivos de texto Groovy/Markdown. No se requiere un Jenkins corriendo para pasar los validadores; se recomienda **opcionalmente** levantar `jenkins/jenkins:lts` del módulo `jk-02` para probar la library a mano.

## Siguiente módulo

→ `jk-05-agents-distributed-builds-kubernetes-plugin` — operar builds distribuidos con agents efímeros en Kubernetes.
