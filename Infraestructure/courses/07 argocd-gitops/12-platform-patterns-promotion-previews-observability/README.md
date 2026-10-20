# argo-12 — Platform patterns: promoción, previews y observabilidad

## Identificación

- **ID:** `argo-12-platform-patterns-promotion-previews-observability`
- **Curso:** `argocd-gitops`
- **Nivel:** producción
- **Duración estimada:** 5 h
- **Prerrequisitos:** `argo-07-applicationsets-and-generators`, `argo-09-secrets-with-gitops`, `argo-11-internals-and-security`.

## Objetivo

Diseñar y operar **GitOps como plataforma**: elegir y defender una estrategia de promoción entre ambientes (branch, folder/overlay con ApplicationSet, image updater), montar **PR previews** end-to-end con limpieza automática, decidir políticas de **drift reconciliation**, cablear **notifications-controller** a Slack/webhook, exponer y leer **métricas Prometheus del `application-controller`** para observar Argo CD mismo, y relacionar todo con un IDP tipo Backstage.

## Alcance

Este módulo cubre:

- Estrategia de promoción entre ambientes:
  - **branch-based** (promover = merge dev → stg → prod en el repo de infra),
  - **folder/overlay-based** con ApplicationSet (`envs/dev/`, `envs/stg/`, `envs/prod/`),
  - **image updater** (`argocd-image-updater` escribe commits que bumpan tags cuando aparece imagen nueva).
- Separación **repo de código** vs **repo de infra** (uno o varios), ownership vía `CODEOWNERS`.
- **PR previews** completas, nombrado determinista y limpieza automática al cerrar/mergear el PR.
- **Drift reconciliation**: cuándo re-sync, cuándo alertar, interacción con `selfHeal`.
- **notifications-controller** (templates, triggers, Slack/webhook/email).
- **Observabilidad de Argo CD mismo**: métricas Prometheus del `application-controller`, dashboards oficiales, SLOs internos.
- **ApplicationSet progressive sync** (rollout controlado por waves/strategy).
- Relación con **Backstage** / IDPs (plantillas que crean el folder + Application de un servicio nuevo).

Lo que **no** cubre (otros módulos):

- Instalación, projects, RBAC (`argo-02`, `argo-06`, `argo-11`).
- Progressive delivery intra-app (canary, blue/green) → `argo-10` (Argo Rollouts). Aquí **progressive sync** se refiere al rollout *entre* Applications de un ApplicationSet.
- Flux como alternativa comparada → `argo-13`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`** — cuatro ejemplos demostrativos:
  - `01-branch-promotion/` — promoción por merge de branches en el repo de infra.
  - `02-folder-promotion-appset/` — Git generator con `envs/*/` y promoción por PR.
  - `03-image-updater/` — `argocd-image-updater` escribiendo commits a Git.
  - `04-argocd-metrics-dashboard/` — exponer `application-controller` metrics y leerlas con `curl` + plantilla de dashboard.
- **`activities/`** — dos actividades:
  - `01-platform-contract-adr/` — ADR independiente que define el "contrato GitOps" (promoción, previews, drift, ownership).
  - `02-pr-previews-end-to-end/` — guided-lab reproducible con `kind` + Argo CD + ApplicationSet con PR generator simulado.
- **`resources/links.md`** — referencias verificables.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar en una pizarra las 3 estrategias de promoción con sus trade-offs; justificar separación código/infra; distinguir drift *benigno* de drift *adversario*; nombrar las 5-6 métricas clave del `application-controller`. |
| Operativa | Montar PR preview con ApplicationSet; cablear Slack/webhook con `notifications-controller`; exponer `/metrics` y verificar con `curl`; configurar `argocd-image-updater` sobre un chart Helm con `write-back` a Git. |
| Arquitectónica | Diseñar el **contrato GitOps** de una plataforma multi-tenant: quién puede mergear a `prod`, dónde viven los `values-*.yaml`, cómo se nombran los namespaces de preview, qué alerta despierta a quién, cómo se integra con Backstage. |

## Criterios de evaluación

- ADR del contrato de plataforma coherente con los principios de GitOps (versionado, pull, reconciliación continua) y con los módulos previos (ESO de `argo-09`, hardening de `argo-11`).
- PR preview levantado y destruido automáticamente a partir de un evento PR (simulado o real), con namespace aislado y limpieza verificada.
- Capacidad de leer una gráfica de `argocd_app_reconcile_bucket` y relacionarla con la salud del cluster.
- Decisión *fundamentada* sobre branch vs folder vs image updater para 3 escenarios distintos (startup, enterprise multi-tenant, equipo que publica muchas imágenes por día).

## Secuencia recomendada

1. Lee `theory/lesson.md` completa (una pasada).
2. Reproduce `examples/01-branch-promotion/` y `examples/02-folder-promotion-appset/` seguidos para contrastar.
3. Reproduce `examples/03-image-updater/`.
4. Reproduce `examples/04-argocd-metrics-dashboard/`.
5. Haz la actividad `activities/02-pr-previews-end-to-end/` (guided-lab).
6. Haz la actividad `activities/01-platform-contract-adr/` (ADR independiente): es la síntesis.
7. Responde las preguntas de evaluación al final de la lección sin consultar.

## Siguiente

→ `argo-13-flux-as-alternative`: cerrar el curso portando el capstone a Flux y escribiendo el ADR final de elección.
