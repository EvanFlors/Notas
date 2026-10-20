# argo-06 — Projects, RBAC y boundaries en Argo CD

## Identificación

- **ID:** `argo-06-projects-rbac-and-boundaries`
- **Curso:** `argocd-gitops`
- **Nivel:** intermedio
- **Duración estimada:** 3 h
- **Prerrequisitos:**
  - `argo-03-application-anatomy-sources-destinations-sync` (dominar el CR `Application`).
  - Curso **kubernetes** ≥ `k8s-12-rbac-serviceaccounts-admission-policy` (RBAC nativo de Kubernetes, ServiceAccounts, Roles, RoleBindings).
  - `kind` o acceso a un cluster de pruebas y `argocd` CLI instalado.

## Objetivo

Diseñar **multi-tenancy segura** en Argo CD usando `AppProject` como barrera entre equipos. Al terminar sabrás:

- Delimitar qué repos, qué clusters y qué namespaces puede tocar cada equipo.
- Separar **Argo CD RBAC** (quién hace qué *dentro* de Argo CD) de **K8s RBAC** (qué hace Argo CD en el cluster target).
- Emitir **JWT tokens** acotados por role para integrar un pipeline de CI sin darle el `admin`.
- Integrar grupos de un proveedor **OIDC/SSO** con policies de project.

## Alcance

Este módulo cubre:

- CR `AppProject`: `sourceRepos`, `destinations`, `clusterResourceWhitelist/Blacklist`, `namespaceResourceWhitelist/Blacklist`, `orphanedResources`, `roles`.
- Policies CSV de Argo CD (`policy.csv`) y modelo Casbin subyacente.
- Project roles con JWT tokens de corta duración para CI.
- Integración con OIDC (Dex o IdP externo) mapeando `groups` a roles.
- Diferencia conceptual **Argo CD RBAC vs K8s RBAC** y por qué ambos importan.
- Patrones de auditoría: detectar un project `*/*` abierto y proponer el mínimo privilegio.

Lo que **no** cubre:

- `ApplicationSet` y generadores → `argo-07`.
- Multi-cluster, sharding del `application-controller` y alta disponibilidad → `argo-08`.
- Rotación de secrets/sealed-secrets → curso `security`.

## Materiales

- **`theory/lesson.md`** — lección profunda con **12 secciones**.
- **`examples/`**:
  - `01-project-per-team/` — dos `AppProject` (`team-payments`, `team-checkout`) con boundaries distintos.
  - `02-rbac-with-oidc-groups/` — `argocd-rbac-cm` con policies por grupo OIDC.
  - `03-jwt-token-for-ci/` — emisión de JWT por project role y uso desde CI.
- **`activities/`**:
  - `01-multi-team-projects/` (**guided-lab**, 60 min) — montar dos projects aislados y verificar que un equipo no puede sincronizar en el namespace del otro.
  - `02-least-privilege-rbac-adr/` (**independent**, 60–75 min) — auditar un project `*/*` y escribir un ADR con la restricción mínima suficiente.
- **`resources/links.md`** — docs oficiales y lecturas recomendadas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué un `AppProject` es la barrera de tenencia, no el namespace. Diferenciar policies de Argo CD RBAC de un `RoleBinding` nativo de K8s. Describir qué ServiceAccount acaba actuando en el cluster target. |
| Operativa | Crear un `AppProject` con `sourceRepos`, `destinations`, whitelists; definir un project role; emitir un JWT; configurar `argocd-rbac-cm` para que un grupo OIDC obtenga un role. |
| Arquitectónica | Diseñar un modelo de multi-tenancy para N equipos con mínimo privilegio. Auditar un project laxo y justificar cada restricción. Argumentar separación `project-admin` vs `project-viewer` vs `ci-syncer`. |

## Criterios de evaluación

- Dos `AppProject` creados que **impidan** cross-deployment entre equipos (demostrado con un intento fallido explícito).
- Un project role `ci-syncer` con JWT, limitado a `sync` y a Applications de un project.
- `argocd-rbac-cm` muestra una policy por grupo OIDC (aunque sea Dex local).
- ADR corto que justifique la restricción mínima para pasar de `*/*` a políticas acotadas.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo (una pasada; cubre las 12 secciones).
2. Reproduce `examples/01-project-per-team/` y observa el `argocd app sync` fallando por boundary.
3. Haz la actividad `activities/01-multi-team-projects/` (guided-lab).
4. Reproduce `examples/02-rbac-with-oidc-groups/` y `examples/03-jwt-token-for-ci/`.
5. Haz la actividad `activities/02-least-privilege-rbac-adr/` (independent) — es la que valida criterio arquitectónico.
6. Responde las preguntas de evaluación de la lección sin consultar.

## Siguiente

→ `argo-07-applicationsets-and-generators`: generar múltiples Applications desde una plantilla y generadores (list, cluster, git, matrix).
