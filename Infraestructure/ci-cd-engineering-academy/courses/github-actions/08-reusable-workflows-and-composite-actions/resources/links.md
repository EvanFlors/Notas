# Recursos — gha-08

## Documentación oficial de GitHub Actions

### Composite actions

- **Creating a composite action**. <https://docs.github.com/en/actions/sharing-automations/creating-actions/creating-a-composite-action>
- **Metadata syntax for GitHub Actions** (`action.yml` reference). <https://docs.github.com/en/actions/sharing-automations/creating-actions/metadata-syntax-for-github-actions>
- **About custom actions**. <https://docs.github.com/en/actions/sharing-automations/creating-actions/about-custom-actions>

### Reusable workflows

- **Reusing workflows**. <https://docs.github.com/en/actions/sharing-automations/reusing-workflows>
- **Workflow syntax — `on.workflow_call`**. <https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions#onworkflow_call>
- **Passing inputs and secrets to a reusable workflow**. <https://docs.github.com/en/actions/sharing-automations/reusing-workflows#passing-inputs-and-secrets-to-a-reusable-workflow>
- **Using outputs from a reusable workflow**. <https://docs.github.com/en/actions/sharing-automations/reusing-workflows#using-outputs-from-a-reusable-workflow>
- **Avoiding duplication**. <https://docs.github.com/en/actions/sharing-automations/avoiding-duplication>

### Starter workflows

- **Creating starter workflows for your organization**. <https://docs.github.com/en/actions/sharing-automations/creating-workflow-templates-for-your-organization>

### Security y permisos

- **Automatic token authentication** (`GITHUB_TOKEN`). <https://docs.github.com/en/actions/security-for-github-actions/security-guides/automatic-token-authentication>
- **Security hardening for GitHub Actions**. <https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions>
- **Using secrets in GitHub Actions**. <https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions>

### Límites

- **Usage limits, billing, and administration — Reusable workflows**. <https://docs.github.com/en/actions/learn-github-actions/usage-limits-billing-and-administration#usage-limits>

## Patrones y herramientas

- **`actions/publish-action`** — mueve el tag mayor en releases. <https://github.com/actions/publish-action>
- **Dependabot — actions ecosystem** (mantén pins actualizados). <https://docs.github.com/en/code-security/dependabot/working-with-dependabot/keeping-your-actions-up-to-date-with-dependabot>
- **`actions/setup-python`** (usada en los ejemplos). <https://github.com/actions/setup-python>

## Repos ejemplares (para leer código real)

- **`github/docs` reusable workflows** — ejemplos en producción. <https://github.com/github/docs/tree/main/.github/workflows>
- **`actions/reusable-workflows`** — plantillas oficiales. <https://github.com/actions/reusable-workflows>
- **`step-security/harden-runner`** — ejemplo de composite action bien escrita. <https://github.com/step-security/harden-runner>

## Alternativas y lecturas comparativas

- **GitLab CI — `include:`** (equivalente conceptual). <https://docs.gitlab.com/ee/ci/yaml/includes.html>
- **CircleCI — Orbs**. <https://circleci.com/docs/orb-intro/>
- **Jenkins — Shared libraries**. <https://www.jenkins.io/doc/book/pipeline/shared-libraries/>

## Blogs y charlas útiles

- *GitHub Blog — "Reusable workflows now generally available"* (contexto histórico). <https://github.blog/changelog/2021-11-24-github-actions-reusable-workflows-are-generally-available/>
- *GitHub Blog — "Required workflows"* (relevante para `gha-15`). <https://github.blog/changelog/2024-01-22-github-actions-required-workflows-moves-to-repository-rules/>
