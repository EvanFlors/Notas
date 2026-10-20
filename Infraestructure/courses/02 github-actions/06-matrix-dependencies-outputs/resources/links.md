# Recursos — gha-06

## Documentación oficial

- **Workflow syntax (índice)** — <https://docs.github.com/actions/using-workflows/workflow-syntax-for-github-actions>
- **`jobs.<id>.strategy.matrix`** — <https://docs.github.com/actions/using-jobs/using-a-matrix-for-your-jobs>
- **`jobs.<id>.needs`** — <https://docs.github.com/actions/using-jobs/using-jobs-in-a-workflow#defining-prerequisite-jobs>
- **`jobs.<id>.outputs`** — <https://docs.github.com/actions/using-jobs/defining-outputs-for-jobs>
- **Workflow commands & environment files** (`GITHUB_OUTPUT`, `GITHUB_STEP_SUMMARY`, `GITHUB_ENV`, `GITHUB_PATH`) — <https://docs.github.com/actions/using-workflows/workflow-commands-for-github-actions>
- **`concurrency`** — <https://docs.github.com/actions/using-jobs/using-concurrency>
- **Expressions and functions** (`fromJSON`, `toJSON`, `contains`, `always`, `success`, `cancelled`) — <https://docs.github.com/actions/learn-github-actions/expressions>
- **Contexts reference** (`github`, `needs`, `matrix`, `strategy`, `job`) — <https://docs.github.com/actions/learn-github-actions/contexts>

## Cambios históricos relevantes

- **GitHub Changelog**, *"GitHub Actions: Deprecating `save-state` and `set-output` commands"* (oct 2022) — <https://github.blog/changelog/2022-10-11-github-actions-deprecating-save-state-and-set-output-commands/>
- **GitHub Blog**, *"Prevent duplicate deployments with Actions concurrency"*.
- **GitHub Security Lab**, posts sobre **script injection** en workflows.

## Actions utilizadas en este módulo

- **`actions/checkout`** — <https://github.com/actions/checkout>
- **`actions/setup-python`** — <https://github.com/actions/setup-python>

## Herramientas de linting

- **`actionlint`** (CLI de lint para workflows YAML) — <https://github.com/rhysd/actionlint>
- **`gh workflow`**, **`gh run`** (CLI de GitHub para disparar/observar runs) — <https://cli.github.com/manual/gh_workflow>

## Lectura complementaria

- Blog de **Legit Security**, **Praetorian**, **Snyk** y **StepSecurity** — búsquedas con "GitHub Actions script injection" para ejemplos concretos.
- *The Twelve-Factor App* (contextual para pensar en builds reproducibles) — <https://12factor.net/>
- GitHub Actions runner image contents (qué viene preinstalado en `ubuntu-latest`, `macos-latest`) — <https://github.com/actions/runner-images>

## Nota de verificación

Última verificación de enlaces: pendiente de validar en Fase 4. Todos los dominios son oficiales (`docs.github.com`, `github.com`, `github.blog`, `cli.github.com`, `12factor.net`). Confirmar versiones mayores de las acciones (`actions/checkout@v4`, `actions/setup-python@v5`) al momento de ejecución del curso en producción.
