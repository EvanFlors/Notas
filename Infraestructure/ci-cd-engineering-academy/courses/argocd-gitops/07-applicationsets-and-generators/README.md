# argo-07 — ApplicationSets y Generators

## Identificación

- **ID:** `argo-07-applicationsets-and-generators`
- **Curso:** `argocd-gitops`
- **Nivel:** intermedio
- **Duración estimada:** 5 h
- **Prerrequisitos:** `argo-04-sources-helm-kustomize-jsonnet-multisource`, `argo-06-projects-rbac-and-boundaries`.

## Objetivo

**Generar Applications dinámicamente** a partir de datos (lista, cluster, Git, PRs, matrices) para escalar a muchos entornos, clusters y servicios sin crecer manualmente el número de manifests. Al terminar deberías poder sustituir el patrón "app-of-apps" por un `ApplicationSet` para los 3 ambientes del capstone y habilitar **preview environments por PR** con limpieza automática.

## Alcance

Este módulo cubre:

- El CR `ApplicationSet` y el `applicationset-controller`.
- **Generators**: `List`, `Cluster`, `Git` (directories y files), `Matrix`, `Merge`, `SCM Provider`, `Pull Request`.
- `template` con `metadata` y `spec` parametrizados; variables `{{path}}`, `{{path.basename}}`, `{{branch}}`, `{{number}}`, `{{values.*}}`.
- Modo **`goTemplate: true`** y por qué es preferible al motor legacy `fasttemplate`.
- Evitar explosión combinatoria (filtros, selectores, `templatePatch`).
- **Progressive sync** (`strategy.type: RollingSync`) para desplegar waves de Applications con criterios de salud.
- Diferencia conceptual **app-of-apps** vs **ApplicationSet**.

Lo que **no** cubre (otros módulos):

- Secretos (`argo-09`), multi-cluster bootstrap profundo (`argo-08`), platform patterns de promoción (`argo-12`).

## Materiales

- **`theory/lesson.md`** — lección con 12 secciones.
- **`examples/`**:
  - `01-git-generator-env-per-folder/` — ApplicationSet que descubre `envs/*/` en un repo.
  - `02-cluster-generator-fleet/` — una App por cluster registrado.
  - `03-pullrequest-preview-env/` — PR Generator con namespace efímero y delete-on-close.
- **`activities/`**:
  - `01-env-per-folder-appset/` — **guided-lab**: construir un ApplicationSet con Git generator (directories) sobre un repo local.
  - `02-pr-preview-environments/` — **independent**: ApplicationSet que crea un ambiente por PR (mockeable con file-generator si no hay GitHub webhook).
- **`resources/links.md`** — documentación oficial y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar qué es un generator, por qué `ApplicationSet` ≠ `app-of-apps`, y por qué `goTemplate: true` evita trampas de escapado. Enumerar los generators y cuándo elegir cada uno. |
| Operativa | Escribir un `ApplicationSet` con Git generator que genere N Apps desde `envs/*/`, con un `template` parametrizado; levantar PR previews; aplicar `strategy: RollingSync`. |
| Arquitectónica | Diseñar la "forma" de un ApplicationSet para una org con 50 servicios × 3 ambientes evitando explosión y repetición; decidir cuándo usar Matrix vs Merge vs un sólo generator con filtros. |

## Criterios de evaluación

- `ApplicationSet` que genera correctamente 3 Applications para `envs/dev`, `envs/stg`, `envs/prod` desde un repo Git.
- Preview environment aparece al abrir un PR y se elimina al cerrarlo (demostrable aunque sea con file-generator mock).
- Capacidad de defender la elección de generator por caso de uso.
- Respuesta argumentada a las preguntas de reflexión de cada actividad.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo.
2. Reproduce `examples/01-git-generator-env-per-folder/`.
3. Haz la actividad `01-env-per-folder-appset/` (guided).
4. Lee `examples/02-cluster-generator-fleet/` y `03-pullrequest-preview-env/`.
5. Haz la actividad `02-pr-preview-environments/` (independent).
6. Responde las preguntas de reflexión sin consultar.

## Siguiente

→ `argo-08-multi-cluster-and-bootstrap-patterns`: usar ApplicationSet como raíz de bootstrap de clusters.
