# Recursos — gha-02

## Documentación oficial

- **Contexts** — <https://docs.github.com/actions/learn-github-actions/contexts>
- **Expressions** — <https://docs.github.com/actions/learn-github-actions/expressions>
- **Workflow syntax** — <https://docs.github.com/actions/using-workflows/workflow-syntax-for-github-actions>
- **Status check functions** (`success()`, `failure()`, `cancelled()`, `always()`) — en la página de Expressions.
- **Security hardening for GitHub Actions** (incluye la sección canónica sobre script injection) — <https://docs.github.com/actions/security-guides/security-hardening-for-github-actions>
- **GITHUB_TOKEN** y permisos — <https://docs.github.com/actions/security-guides/automatic-token-authentication>
- **`actions/github-script`** — <https://github.com/actions/github-script>

## Herramientas de análisis estático

- **actionlint** (oficial Microsoft; detecta sintaxis, uso incorrecto de contextos, injections básicos) — <https://github.com/rhysd/actionlint>
- **zizmor** (Rust; audit especializado en seguridad de workflows) — <https://github.com/woodruffw/zizmor>
- **octoscan** (análisis de workflows en Go) — <https://github.com/synacktiv/octoscan>

## Ejecución local de workflows

- **nektos/act** (ejecuta workflows localmente en Docker) — <https://github.com/nektos/act>

## Lecturas adicionales recomendadas

- GitHub Security Lab — "Keeping your GitHub Actions and workflows secure Part 2: Untrusted input" — <https://securitylab.github.com/research/github-actions-untrusted-input/>
- Blog Snyk — "Preventing GitHub Actions script injection"
- Writeup del incidente `tj-actions/changed-files` (2025) — útil para ver el "después" de un compromise de supply chain downstream.

## Referencia rápida de contextos

| Contexto | Representa | Disponible en |
|----------|-----------|---------------|
| `github` | Metadatos y payload del run | Todo |
| `env` | Env vars del YAML | `if:`, `run:`, `with:` |
| `vars` | Repository/org variables | igual que `env` |
| `secrets` | Secretos | Steps y, con restricciones, `job.if:` |
| `inputs` | Inputs de dispatch/call | Workflow receptor |
| `needs` | Resultado y outputs de jobs necesitados | Jobs con `needs:` |
| `job` | Estado del job actual | Dentro del job |
| `runner` | Metadatos del runner | Dentro de un step |
| `steps` | Outputs/conclusion de steps anteriores con `id:` | Steps siguientes del mismo job |
| `matrix` | Fila de matriz actual | Jobs con `strategy.matrix` |
| `strategy` | Metadatos de la estrategia | Jobs con `strategy:` |
