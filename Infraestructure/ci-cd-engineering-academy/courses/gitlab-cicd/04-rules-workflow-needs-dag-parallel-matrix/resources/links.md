# Recursos — gl-04

Referencias oficiales. Verificar en Fase 4 del programa para asegurar vigencia (GitLab publica release el 22 de cada mes y la sintaxis evoluciona).

## Oficiales (GitLab Docs)

- **`.gitlab-ci.yml` keyword reference**: `https://docs.gitlab.com/ee/ci/yaml/`
- **`workflow:` top-level**: `https://docs.gitlab.com/ee/ci/yaml/#workflow`
- **`rules:` reference**: `https://docs.gitlab.com/ee/ci/yaml/#rules`
- **`needs:` reference y DAG**: `https://docs.gitlab.com/ee/ci/yaml/#needs`
- **`parallel:` y `parallel: matrix:`**: `https://docs.gitlab.com/ee/ci/yaml/#parallel`
- **Predefined variables (`CI_PIPELINE_SOURCE`, `CI_NODE_INDEX`, …)**: `https://docs.gitlab.com/ee/ci/variables/predefined_variables.html`
- **CI/CD Pipeline Editor y Lint**: `https://docs.gitlab.com/ee/ci/pipeline_editor/`

## Mapeo GitHub Actions ↔ GitLab

- **Migrating from GitHub Actions**: `https://docs.gitlab.com/ee/ci/migration/github_actions.html`
- **Pipeline efficiency (needs/DAG)**: `https://docs.gitlab.com/ee/ci/pipelines/pipeline_efficiency.html`

## Patrones avanzados (siguiente módulo)

- **Child/parent pipelines (`trigger:`)**: `https://docs.gitlab.com/ee/ci/pipelines/downstream_pipelines.html`
- **CI/CD Components (en `gl-05`)**: `https://docs.gitlab.com/ee/ci/components/`

## Lecturas y charlas

- GitLab Unfiltered — "DAG pipelines in practice" (varias ediciones por año en YouTube).
- Blog de GitLab — "Pipeline optimization" (serie recurrente).

## Checklist de verificación requerida en Fase 4

- Que `only/except` siga marcado como legacy (y no removido todavía).
- Que `workflow: name:` siga admitiendo interpolación de variables.
- Que `parallel: matrix:` no haya añadido ya `exclude:` nativo (en roadmap desde hace años).
- Límite actual de jobs en un pipeline y de `needs:` por job (crece con las versiones).
