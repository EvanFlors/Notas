# helm-10 — Platform Patterns: library charts, Argo CD/Flux y la frontera con Kustomize

> Módulo de cierre del curso **helm**. Deja de pensar en "chart" como artefacto suelto y empieza a pensar en **Helm como pieza de una plataforma**: helpers compartidos, GitOps que lo ejecuta por ti, y los puntos donde Helm cede terreno a Kustomize o a un operador.

## Identificación

- **ID:** `helm-10-platform-patterns-library-charts-argo-flux-and-kustomize-boundary`
- **Nivel:** producción
- **Duración estimada:** 4 h
- **Prerrequisitos:** `helm-07` (lifecycle/hooks), `helm-08` (OCI/firma), `helm-09` (testing), curso **kubernetes** Nivel 4, puente con cursos **argocd** y **docker**.

## Objetivo

Operar Helm como **plataforma**: compartir helpers entre charts internos mediante *library charts*, integrar Helm con **Argo CD** y **Flux** sin romperse en los sitios conocidos, usar **post-renderers** y Kustomize como "edición de salida" sin templatizar más, y decidir con criterio **cuándo migrar a/desde Kustomize** o **a un operador**. Además, versionar los charts internos **como productos**: SemVer, deprecation policy, migration guides.

## Temas y subtemas

- **Library charts** (`type: library`)
  - Helpers reutilizables (`define`) sin recursos renderizables.
  - Convención de nombres y versionado independiente.
- **"Golden chart" de plataforma vs chart por app**
  - Un chart genérico que todas las apps consumen vía `values`.
  - Trade-offs: velocidad y uniformidad frente a flexibilidad.
- **Helm + Argo CD**
  - `spec.source.helm.values`, `valueFiles`, `parameters`.
  - Argo CD **no ejecuta** `helm install`: renderiza y aplica como manifests → impacto en hooks, release names, Secret del release.
- **Helm + Flux**
  - CRD `HelmRelease` v2, `HelmRepository`, `OCIRepository`.
- **Helm + Kustomize**
  - `helm template | kustomize build` para post-rendering.
  - `--post-renderer` como contrato oficial.
- **Fronteras**
  - Cuándo migrar a Kustomize puro.
  - Cuándo migrar a un operador.
- **Gobernanza de charts internos**
  - SemVer, deprecation policy, migration guides, `appVersion` vs `version`.

## Conceptos internos (fundamentos)

- Un **library chart** no se instala: su `Chart.yaml` declara `type: library` y sus templates (archivos que empiezan con `_`) solo contienen `define` — no producen manifests. El consumidor lo lista como `dependencies:` y lo invoca con `include`.
- **Argo CD** no ejecuta `helm install`: hace `helm template` (vía CMP o `helm render`), aplica el YAML con server-side apply y guarda el estado en su propio `Application`. **No hay Secret de release de Helm** en el cluster. Consecuencias: los hooks de Helm con `helm.sh/hook` se traducen a hooks de Argo (`argocd.argoproj.io/hook`), las policies de borrado cambian, y `helm history` / `helm rollback` no funcionan como esperas.
- **Flux**, en cambio, usa el controlador `helm-controller` que **sí** ejecuta Helm server-side: hay Secret de release y el lifecycle es casi idéntico al CLI.
- Un **post-renderer** es cualquier binario que lee el YAML renderizado por `helm template` por stdin y escribe el YAML modificado por stdout. Es la vía oficial para "editar" la salida de Helm sin añadir más plantillas al chart.
- Un chart interno es un **producto**: tiene usuarios (otros equipos), tiene breaking changes y necesita changelog, deprecation window y migration guides.

## Competencias

- **Conceptual:** explicar por qué un library chart no se instala; qué pasa con los hooks de Helm bajo Argo CD; qué resuelve un post-renderer que no resuelve un `values`.
- **Operativa:** escribir un library chart y consumirlo desde otro chart; configurar un `Application` de Argo CD apuntando a un chart Helm con `valueFiles` por entorno; aplicar Kustomize como post-renderer.
- **Arquitectónica:** decidir cuándo un chart deja de ser la herramienta correcta (migrar a Kustomize puro o a un operador); definir el **contrato** de un "golden chart" de plataforma; versionar charts internos con política explícita.

## Ejemplos

- `examples/01-library-chart-shared-helpers/` — library chart con `_helpers.tpl` reutilizables, consumido por un chart application.
- `examples/02-helm-with-argo-cd-pattern/` — `Application` de Argo CD con `source.helm.values` y `valueFiles`, explicación de las trampas.
- `examples/03-post-renderer-with-kustomize/` — `helm template | kustomize build` y uso de `--post-renderer`.

## Actividades

- `activities/01-write-library-chart/` — **guided-lab**: escribir un library chart y conectarlo a una app consumidora. Validación automatizada.
- `activities/02-platform-chart-contract-adr/` — **architecture (independent)**: ADR que define el contrato del chart de plataforma y defiende Helm vs Kustomize vs operador para 3 escenarios reales.

## Entregables

- Library chart interno funcional (`platform-lib`) con labels, selectors, nombres y probes estandarizados.
- `demo-app` consumiéndolo con `helm template` que produce manifests válidos.
- ADR del **contrato del chart de plataforma** con 3 decisiones Helm/Kustomize/operador argumentadas.

## Criterios de evaluación

| Dimensión | Qué se espera |
|-----------|---------------|
| Conceptual | Explicar library chart, impacto de Argo CD sobre hooks/release storage, qué hace un post-renderer. |
| Operativa | `helm dependency build` y `helm template` del consumidor rinden sin error; `kustomize build` como post-renderer altera la salida esperada. |
| Arquitectónica | ADR con decisión defendible para los 3 escenarios y política de versionado del chart interno. |

## Recursos

Ver `resources/links.md` y `theory/lesson.md` (12 secciones).
