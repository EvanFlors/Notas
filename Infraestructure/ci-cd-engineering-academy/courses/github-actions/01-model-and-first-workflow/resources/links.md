# Recursos — `gha-01-model-and-first-workflow`

> Verificar fecha de consulta. Las URLs oficiales de GitHub cambian ocasionalmente de ruta.

## Documentación oficial

- **Understanding GitHub Actions** — introducción canónica a eventos, workflows, jobs, actions, runners. <https://docs.github.com/en/actions/learn-github-actions/understanding-github-actions>
- **Workflow syntax for GitHub Actions** — referencia exhaustiva del YAML (todas las claves). <https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions>
- **Events that trigger workflows** — catálogo completo de triggers y sus payloads. <https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows>
- **About GitHub-hosted runners** — runners provistos por GitHub, capacidades por SO. <https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners>
- **Choosing when your workflow runs** — filtros, branches, paths. <https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#on>
- **Billing for GitHub Actions** — minutos, multiplicadores por SO, límites por plan. <https://docs.github.com/en/billing/managing-billing-for-github-actions/about-billing-for-github-actions>
- **Monitoring and troubleshooting workflows** — UI, re-run, debug logging. <https://docs.github.com/en/actions/monitoring-and-troubleshooting-workflows>

## Repositorios canónicos

- **actions/runner-images** — qué viene preinstalado en cada imagen hosted (una entry por SO). <https://github.com/actions/runner-images>
- **actions/checkout** — fuente de la action más usada, con `action.yml` legible. <https://github.com/actions/checkout>
- **actions/setup-python**, **actions/setup-node**, **actions/setup-go**, **actions/setup-java** — actions oficiales de setup. Buscar en <https://github.com/actions>.
- **actions/runner** — el agente de runner (self-hosted), útil para entender el ciclo de un job. <https://github.com/actions/runner>

## Herramientas de desarrollo local

- **actionlint** — linter estático de workflows GHA (detecta errores de sintaxis, triggers inválidos, referencias rotas). <https://github.com/rhysd/actionlint>
- **nektos/act** — ejecutor local de workflows en contenedores Docker; útil para iterar sin pushear. <https://github.com/nektos/act>
- **GitHub Actions VSCode extension** — autocompletado y validación de workflows en el editor. <https://marketplace.visualstudio.com/items?itemName=github.vscode-github-actions>

## Lectura complementaria

- **The GitHub Blog — Actions tag** — anuncios y features. <https://github.blog/tag/github-actions/>
- **Awesome Actions** — índice comunitario de actions útiles. <https://github.com/sdras/awesome-actions>
- **GitHub Actions by example** — colección pedagógica. <https://github.com/actions/starter-workflows>

## En este curso

- Siguiente módulo: `gha-02-syntax-expressions-and-contexts` — expresiones `${{ … }}`, contextos, `if:`, interpolación segura.
- Para gestión de dependencias de actions (pin a SHA, actions oficiales vs terceros): `gha-04`.
- Para catálogo profundo de triggers (`pull_request_target`, `workflow_run`, cron): `gha-03`.
- Para self-hosted runners y ARC: `gha-11`.
