# jk-06 — Plugins, JCasC, Job DSL y Blue Ocean

## Identificación

- **ID:** `jk-06-plugins-jcasc-job-dsl-blue-ocean`
- **Curso:** `jenkins`
- **Nivel:** advanced
- **Duración estimada:** 3 h
- **Prerrequisitos:** `jk-02-install-ui-freestyle-vs-pipeline`, `jk-03-declarative-pipeline-jenkinsfile`.

## Objetivo

Dejar de operar Jenkins como *snowflake* y tratarlo como cualquier otra app: su configuración vive en Git, se revisa por PR y se reproduce desde cero sin clics. Al terminar deberías poder bootstrapear un controller Jenkins reproducible con **Jenkins Configuration as Code (JCasC)**, generar jobs legacy desde **Job DSL** vía *seed job*, pinnear plugins con disciplina, y posicionar **Blue Ocean** sabiendo en qué estado real está hoy.

## Alcance

Este módulo cubre:

- **Plugin ecosystem** (~1800 plugins): `plugin-manager` CLI, `install-plugins.sh`, versiones pinneadas en `plugins.txt`, estrategia de updates.
- **Jenkins Configuration as Code (JCasC)**: `jenkins.yaml` que describe **todo** el controller — security realm, authorization, credentials, nodes, clouds, tools, unclassified, *jobs* (vía Job DSL seed).
- **Job DSL plugin**: definir jobs desde Groovy; patrón *seed job* que lee un `.groovy` del repo y genera N jobs; útil para migrar freestyle legacy a algo versionado.
- **Blue Ocean**: UI alternativa, su estado real en 2026 (feature-complete / low-maintenance), por qué perdió momentum, cuándo tiene sentido todavía.
- **Jenkins Operator for Kubernetes**: mención conceptual como opción CRD-based.
- **Backup del `JENKINS_HOME`** con Velero o similar: por qué JCasC no reemplaza el backup de history/artefactos.

Lo que **no** cubre (se verá después):

- Hardening de seguridad, RBAC, credentials en profundidad → `jk-07`.
- HA, upgrade cadence y plan de migración a GHA / GitLab CI / Argo Workflows → `jk-08`.
- Shared Libraries y Scripted Pipeline → `jk-04`.

Este módulo es **mayoritariamente conceptual + YAML/Groovy escrito y validado estructuralmente**. **No** se levanta un Jenkins real: el único *tooling* es `bash`, `python3` (parser YAML) y un editor. La demo con contenedor Docker + `jenkins.yaml` montado queda documentada como walkthrough opcional (SKIP de ejecución).

## Materiales

- **`theory/lesson.md`** — lección profunda: plugin ecosystem, JCasC, Job DSL, Blue Ocean, Jenkins Operator, backup.
- **`examples/`** — ejemplos demostrativos (lectura y análisis, no ejecución):
  - `01-jcasc-minimal-config/` — `jenkins.yaml` mínimo con security realm local, authorization, un credential, un node label, y bloque `tool`.
  - `02-seed-job-with-dsl/` — seed job que carga `seed-jobs.groovy` con `pipelineJob`, `folder` y `multibranchPipelineJob`.
  - `03-plugin-pinning-strategy/` — `plugins.txt` pinneado + rationale de actualización controlada.
- **`activities/`** — dos actividades **independientes**:
  - `01-reproduce-your-jenkins-with-jcasc/` — reconstruir un controller desde cero con `jenkins.yaml` + `plugins.txt` + seed job (`guided-lab`).
  - `02-plugin-audit/` — auditoría de plugins instalados en un Jenkins hipotético legacy, con plan de reducción y pinning (`independent`).
- **`resources/links.md`** — referencias oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué un Jenkins sin JCasC es *snowflake*; qué resuelve Job DSL que un Jenkinsfile no; estado real de Blue Ocean en 2026. |
| Operativa (sin infra) | Escribir un `jenkins.yaml` válido; escribir un `plugins.txt` pinneado; escribir un seed job en Groovy que genere ≥2 jobs. |
| Arquitectónica | Decidir qué va en JCasC vs qué va en Jenkinsfiles vs qué va en Shared Libraries; justificar reducción de plugins como primera medida de seguridad. |

## Criterios de evaluación

- Lee un `jenkins.yaml` ajeno y explica qué configura cada bloque (`jenkins`, `security`, `credentials`, `unclassified`, `jobs`, `tool`).
- Diagnostica un `plugins.txt` sin pinning y propone estrategia correctiva.
- Justifica cuándo usar Job DSL (jobs legacy, generación masiva) vs cuándo usar Multibranch Pipeline (repos modernos).
- Nombra 3 razones concretas por las que Blue Ocean no es la UI por defecto hoy.
- Entrega las dos actividades con sus validadores estructurales en verde.

## Entregables

- **`jenkins.yaml`** + **`plugins.txt`** + **`seed-jobs.groovy`** + **`README-INTENT.md`** (sale de la actividad `01`).
- **`plugin-audit.md`** + **`plugins-current.txt`** + **`plugins-target.txt`** (sale de la actividad `02`).

## Costos

**Ninguno.** Todo el módulo se desarrolla localmente contra archivos de texto, YAML y Groovy. No se requiere Jenkins corriendo. Si quieres verificar manualmente la demo opcional:

- `docker run --rm -p 8080:8080 -v $PWD/jenkins.yaml:/var/jenkins_home/casc_configs/jenkins.yaml -e CASC_JENKINS_CONFIG=/var/jenkins_home/casc_configs/jenkins.yaml jenkins/jenkins:lts`
- No es parte del validador. **SKIP** por defecto para mantener el módulo offline.

## Siguiente módulo

→ `jk-07-security-rbac-credentials-and-script-approval` — endurecer Jenkins con RBAC, credentials store, script approval y Vault, sobre la base reproducible de JCasC.
