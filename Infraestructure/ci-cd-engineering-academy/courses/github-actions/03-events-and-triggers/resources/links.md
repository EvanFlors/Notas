# Recursos — gha-03 Events and triggers

> Verificar en Fase 4 que las URLs y los contenidos siguen vigentes.

## Documentación oficial

- Eventos que disparan workflows: <https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows>
- Sintaxis del workflow (`on:`, filtros): <https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions>
- Patrones de filtros (branches, tags, paths, globs): <https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#filter-pattern-cheat-sheet>
- Contextos (`github`, `inputs`, `secrets`, …): <https://docs.github.com/en/actions/learn-github-actions/contexts>
- `workflow_dispatch` inputs: <https://docs.github.com/en/actions/using-workflows/manually-running-a-workflow>
- `schedule` y cron: <https://docs.github.com/en/actions/reference/events-that-trigger-workflows#schedule>
- `workflow_run`: <https://docs.github.com/en/actions/reference/events-that-trigger-workflows#workflow_run>
- `workflow_call` (reusables): <https://docs.github.com/en/actions/using-workflows/reusing-workflows>
- `repository_dispatch`: <https://docs.github.com/en/actions/reference/events-that-trigger-workflows#repository_dispatch>

## Seguridad (lectura obligatoria para §7 y §8 de la lección)

- Security hardening for GitHub Actions: <https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions>
- "Keeping your GitHub Actions and workflows secure Part 1: Preventing pwn requests" (Github Security Lab) — anatomía del anti-patrón `pull_request_target`: <https://securitylab.github.com/research/github-actions-preventing-pwn-requests/>
- Approving workflow runs from public forks: <https://docs.github.com/en/actions/managing-workflow-runs/approving-workflow-runs-from-public-forks>
- OpenSSF Scorecard — `Dangerous-Workflow` check: <https://github.com/ossf/scorecard/blob/main/docs/checks.md#dangerous-workflow>

## Payload de eventos

- Webhook events reference (describe el payload que ve el workflow): <https://docs.github.com/en/webhooks-and-events/webhooks/webhook-events-and-payloads>

## Herramientas

- `actionlint`: <https://github.com/rhysd/actionlint>
- `zizmor` (static analysis de seguridad para workflows): <https://woodruffw.github.io/zizmor/>
- GitHub CLI (`gh workflow run`, `gh run watch`): <https://cli.github.com/manual/gh_workflow>

## Lecturas complementarias

- GitHub Actions "Store information in variables" (contextos y expresiones usados por filtros): <https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions>
- Choreographing Microservices with Workflow Events (patrones de orquestación con `workflow_run` / `repository_dispatch`).
