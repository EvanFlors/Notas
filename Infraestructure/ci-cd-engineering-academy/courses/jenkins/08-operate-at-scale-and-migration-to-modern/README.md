# jk-08 — Operar Jenkins a escala y migrar a herramientas modernas

## Identificación

- **ID:** `jk-08-operate-at-scale-and-migration-to-modern`
- **Curso:** `jenkins`
- **Nivel:** producción (avanzado)
- **Duración estimada:** 4 h
- **Prerrequisitos:** `jk-04` (shared libraries), `jk-06` (JCasC), `jk-07` (seguridad), curso **github-actions** o **gitlab-cicd**, curso **argocd-gitops**.

## Objetivo

Cerrar el curso Jenkins con dos competencias de producción:

1. **Operar Jenkins a escala**: entender por qué el controller es single-point-of-failure, qué patrones existen (HA activo-pasivo manual, CloudBees CI, Jenkins Operator), cómo se diseña backup/restore del `JENKINS_HOME`, cuál es la cadencia LTS y cómo se planifica capacidad (`controller` vs `agents`).
2. **Planificar y ejecutar una migración a una plataforma moderna** (GitHub Actions, GitLab CI o Argo Workflows) sin apagar producción: inventario → clasificación → **dual-run** → corte final → archivado histórico. Toda decisión queda plasmada en un **ADR**.

Al terminar sabrás **operar mientras migras** — que es el único modo realista de reemplazar un Jenkins con años de historia encima.

## Alcance

Este módulo cubre:

- **Operación de producción**: HA (CloudBees CI vs activo-pasivo manual), backup del `JENKINS_HOME` (Velero en K8s, snapshots EBS en VMs), **upgrade cadence** (LTS cada ~12 semanas; ventana de 1–2 LTS atrás como regla), **capacity planning** (controller coordina, agents cargan), **monitoring** (metrics plugin + Prometheus exporter; alertas en `jenkins_queue_depth`, `jenkins_executor_in_use_count`, heap del controller).
- **Migration path** a herramientas modernas:
  - Inventario de pipelines (incluidos los freestyle "fantasma" que nadie recuerda).
  - Clasificación: **migrar / consolidar / retirar**.
  - Target: **GHA** (si repos en GitHub), **GitLab CI** (si GitLab), **Argo Workflows / Tekton** (si K8s-native).
  - **Dual-run** por N semanas: el mismo pipeline corre en Jenkins y en el target, se comparan artefactos y duración; solo cuando el target es verde consistente se declara ganador.
  - Reemplazar **Shared Library** por **reusable workflow / CI/CD Component / Argo WorkflowTemplate**.
  - Reemplazar `withCredentials` por **OIDC federation** al cloud (sin claves de larga duración).
  - **Archivo histórico** de logs/artefactos antes de apagar el controller — compliance exige retención aunque el servicio desaparezca.
- **ADR** de migración con criterios de éxito, timeline, riesgos, rollback y "cuándo apagamos Jenkins".

Lo que **no** cubre:

- La creación operativa de la Shared Library original (eso vivió en `jk-04`).
- El hardening del Jenkins antes de migrar (`jk-07`).
- Cómo escribir el reusable workflow GHA de destino (eso vive en el curso `github-actions`).

Este módulo es **mayoritariamente conceptual + ADR + ejemplos de pipelines dual-run**. No se provisiona cluster real — todo es papel y archivos de texto validados estructuralmente.

## Materiales

- **`theory/lesson.md`** — lección con 10 secciones: HA, backup, upgrade, capacity, observabilidad, migration framework, dual-run, OIDC federation, archivado y "cuándo apagar Jenkins".
- **`examples/`** — tres ejemplos de lectura:
  - `01-jenkins-ha-pattern/` — diagrama y análisis del patrón activo-pasivo manual vs CloudBees CI vs Operator.
  - `02-dual-run-jenkins-and-gha/` — un pipeline simple corriendo simultáneamente en Jenkins (`Jenkinsfile`) y en GHA (`.github/workflows/dual-run.yml`), con el método de comparación.
  - `03-migration-plan-template/` — plantilla de inventario y clasificación de pipelines (migrar/consolidar/retirar) con criterios.
- **`activities/`** — dos actividades independientes:
  - `01-operate-at-scale-adr/` — ADR operacional: HA pattern elegido, estrategia de backup, cadencia de upgrade y plan de capacidad para un escenario dado.
  - `02-migration-adr-and-dual-run/` — ADR de migración completo + un pipeline de ejemplo en dual-run (Jenkinsfile + workflow equivalente).
- **`resources/links.md`** — referencias oficiales (Jenkins LTS, CloudBees, Velero, Prometheus exporter, GHA/GitLab/Argo).

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Operativa | Diseñar backup + restore del `JENKINS_HOME`; planificar upgrade LTS; decidir qué métricas alertan. |
| Arquitectónica | Elegir patrón HA (activo-pasivo vs CloudBees CI vs Operator) con criterio de coste/beneficio. |
| Estratégica | Diseñar y defender un plan de migración por fases con dual-run y criterios de corte. |
| Comunicativa | Escribir ADRs legibles que un equipo de 5 personas pueda ejecutar sin que tú estés en la sala. |

## Criterios de evaluación

- Explica por qué el controller de Jenkins es **single-point-of-failure por diseño** y qué implica para el SLA.
- Nombra tres métricas que **sí** o **sí** deben alertar y qué significan.
- Dado un inventario de 20 pipelines, los clasifica en migrar / consolidar / retirar con criterio.
- Defiende un plan de dual-run contra "si funciona no lo toques" **y** contra "migra todo ya".
- Entrega las dos actividades con sus validadores estructurales en verde.

## Entregables

- **`ADR-OPERATE-AT-SCALE.md`** con decisión de HA, backup, upgrade y capacidad (sale de la actividad `01`).
- **`ADR-MIGRATION.md`** con inventario, clasificación, dual-run y criterios de corte (sale de la actividad `02`).
- **`Jenkinsfile`** y **`.github/workflows/dual-run.yml`** equivalentes para un pipeline simple (sale de la actividad `02`).

## Costos

**Ninguno.** Todo el módulo se desarrolla localmente contra archivos de texto. Si en una fase posterior decides materializar lo diseñado:

- **Jenkins LTS** (OSS): gratis; la cuenta sale del cluster/VM que lo hospeda.
- **CloudBees CI**: licencia comercial (precio por **controller + agents**; cotización por equipo de ventas).
- **GitHub Actions**: minutos gratis en repos públicos; en privados cobran por minuto y por runner self-hosted (gratis el software, no la máquina).
- **GitLab CI**: incluido en el plan GitLab; shared runners con cuota.
- **Argo Workflows**: OSS; coste del cluster K8s que lo corre.

## Siguiente paso

Este es el **último módulo** del curso Jenkins. Las migraciones específicas a GHA / GitLab / Argo se profundizan en sus respectivos cursos (`github-actions`, `gitlab-cicd`, `argocd-gitops`).
