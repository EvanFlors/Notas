# gl-10 — Migración (GHA/Jenkins → GitLab) y patrones de plataforma

## Identificación

- **ID:** `gl-10-migration-and-platform-patterns`
- **Curso:** `gitlab-cicd`
- **Nivel:** producción
- **Duración estimada:** 4 h
- **Prerrequisitos:** `gl-05` (includes/extends/components), `gl-06` (runners/OIDC), `gl-08` (seguridad/registry), `gl-09` (compliance/gobernanza).

## Objetivo

Cerrar el curso de GitLab CI/CD con una **síntesis de capstone**: diseñar y ejecutar — en papel — una **migración** desde GitHub Actions (o Jenkins) a GitLab, y definir cómo se **opera GitLab como plataforma** de CI/CD para toda una organización: catálogo interno, inner-source, control de costes, observabilidad y relación con despliegue (Argo CD).

Al terminar deberías poder:

- Hacer **inventario** antes de migrar (secrets, variables, environments, protected refs, OIDC trust policies).
- Mapear primitivas GHA↔GitLab (`reusable workflow` ≈ **CI/CD Component**; `composite action` ≈ `extends` o Component; `oidc token` → **ID Token** con `aud` y claims diferentes).
- Diseñar un **periodo de dual-run** que reduzca el riesgo de "big bang".
- Operar el **CI/CD Catalog** interno como *golden path*.
- Decidir **SaaS runners vs runners propios** (cost + control + latencia).
- Instrumentar **observabilidad** del CI/CD (duration, success rate, queue time).
- Trazar la frontera con **Argo CD** (CI construye; CD despliega).

## Alcance

Este módulo cubre:

- **Migración GHA → GitLab** (y viceversa cuando aplica): patrones comunes y gotchas.
- **Inventario pre-migración** y plantillas de recogida.
- **Dual-run** y criterios de corte.
- **CI/CD Catalog interno** como contrato versionado para toda la org.
- **Inner-source** del catálogo: RFC, Code Owners, approval rules.
- **Cost control**: minutos SaaS vs operar runners en K8s con Fleeting o chart oficial.
- **Observabilidad del CI/CD**: Prometheus exporter, dashboards de job duration / success rate / queue time.
- **ADR final del curso**: GHA vs GitLab por tipo de organización.

Lo que **no** cubre:

- Fundamentos de GitLab (`gl-01`..`gl-04`).
- Runners desde cero (`gl-06`).
- Scanners nativos (`gl-08`).
- Compliance/approvals (`gl-09`).
- Despliegue continuo con Argo CD (se referencia; el curso dedicado es `argo-cd`).

Este módulo es **mayoritariamente conceptual + ADR**. **No** se provisiona nada en una cuenta GitLab real. El único *tooling* es `bash`, `jq`/`yq` opcional, Markdown y un editor. Las dos actividades son análisis escritos con validadores estructurales.

## Materiales

- **`theory/lesson.md`** — lección profunda en 10 secciones (migración, catálogo, cost, observabilidad, Argo CD).
- **`examples/`** — ejemplos de lectura y análisis:
  - `01-port-gha-workflow-to-gitlab/` — un workflow GHA real portado paso a paso a `.gitlab-ci.yml`, con tabla de mapping.
  - `02-cicd-catalog-governance/` — contrato de un CI/CD Component, modelo de inner-source y gobernanza.
  - `03-ci-metrics-dashboard/` — qué métricas instrumentar y cómo (Prometheus exporter + 4 PromQL de ejemplo).
- **`activities/`** — dos actividades **independientes** (ambas tipo ADR):
  - `01-migrate-capstone-pipeline/` — portar un workflow GHA concreto a GitLab y documentar la decisión en `MIGRATION-ADR.md` + `.gitlab-ci.yml`.
  - `02-platform-adr-final/` — ADR final del curso: GitLab como plataforma (catálogo, cost, observabilidad, Argo CD, elección GHA vs GitLab para 3 organizaciones).
- **`resources/links.md`** — referencias oficiales.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar las 3 diferencias que más suelen romper una migración GHA→GitLab (claims OIDC, modelo de permisos, modelo de reutilización). |
| Operativa (sin infra) | Portar un workflow GHA mediano a `.gitlab-ci.yml` y defender cada decisión en un ADR. |
| Arquitectónica | Diseñar la operación del catálogo CI/CD de una org: quién propone, quién aprueba, cómo versiona, cómo se mide adopción. |
| Estratégica | Defender la elección GHA vs GitLab para 3 organizaciones con constraints distintos. |

## Criterios de evaluación

- Dado un workflow GHA, listas las 5 cosas que hay que decidir **antes** de portar.
- Describes el plan de dual-run para una org de 30 repos.
- Explicas la diferencia entre `include:component:` y `include:remote:` y cuándo elegir cada uno.
- Nombras 4 métricas que todo dashboard de CI/CD debería tener.
- Trazas la frontera CI/CD en una org con Argo CD: qué hace GitLab y qué hace Argo.
- Entregas las dos actividades con sus validadores estructurales en verde.

## Entregables

- **`MIGRATION-ADR.md`** + **`.gitlab-ci.yml`** portado (actividad `01`).
- **`PLATFORM-ADR.md`** con el ADR final del curso (actividad `02`).

## Costos

**Ninguno.** Todo el módulo se desarrolla localmente contra archivos de texto y YAML/JSON. No se requiere cuenta GitLab activa.

## Siguiente paso

Este es el **último módulo** del curso `gitlab-cicd`. Siguientes pasos sugeridos en el programa:

- `argo-cd` — para completar el pipeline *build-and-publish → deploy* separando CI de CD.
- `platform-engineering` — para operar el catálogo CI/CD junto con el resto del *internal developer platform*.
