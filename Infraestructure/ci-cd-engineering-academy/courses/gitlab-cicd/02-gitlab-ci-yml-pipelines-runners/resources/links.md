# Recursos — gl-02

## Documentación oficial

- [`.gitlab-ci.yml` keyword reference](https://docs.gitlab.com/ee/ci/yaml/) — referencia canónica de **todas** las keys. Mantén esta pestaña abierta.
- [CI/CD pipelines](https://docs.gitlab.com/ee/ci/pipelines/) — modelo de ejecución, retry, downstream.
- [GitLab Runner](https://docs.gitlab.com/runner/) — docs del daemon.
- [Executors](https://docs.gitlab.com/runner/executors/) — qué hace cada uno y cuándo elegirlo.
- [Tags](https://docs.gitlab.com/ee/ci/runners/configure_runners.html#use-tags-to-control-which-jobs-a-runner-can-run) — regla exacta de matching.
- [SaaS runners on GitLab.com](https://docs.gitlab.com/ee/ci/runners/saas/linux_saas_runner.html) — tags disponibles, cuotas, pricing.
- [Register a runner with an authentication token](https://docs.gitlab.com/runner/register/) — flujo moderno (reemplaza registration tokens).

## Comparación GHA ↔ GitLab

- [Migrate from GitHub Actions](https://docs.gitlab.com/ee/ci/migration/github_actions.html) — guía oficial.
- Capítulo 7 del libro *The DevOps 2.5 Toolkit* (Farcic) — modelos mentales útiles.

## Herramientas

- [`glab`](https://gitlab.com/gitlab-org/cli) — CLI oficial de GitLab (crea runners, lanza pipelines).
- [`gitlab-ci-local`](https://github.com/firecow/gitlab-ci-local) — ejecuta `.gitlab-ci.yml` en tu laptop (útil para iterar sin consumir minutos SaaS).
- [YAML lint](https://www.yamllint.com/) — chequeo rápido online de sintaxis YAML.

## Lecturas de criterio

- GitLab blog, *"When to use shared vs. group runners"* — resumen del eje de decisión.
- GitLab handbook, *"Infrastructure runners"* — cómo opera GitLab sus propios runners.

> Verifica siempre la versión de GitLab (release mensual, día 22) y confirma qué features de runner están GA vs beta.
