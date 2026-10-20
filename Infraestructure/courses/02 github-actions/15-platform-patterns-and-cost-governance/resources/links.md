# Recursos — gha-15

## Documentación oficial

### Repository rulesets y required workflows
- **About rulesets** — <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets>
- **Creating rulesets for an organization** — <https://docs.github.com/en/organizations/managing-organization-settings/creating-rulesets-for-repositories-in-your-organization>
- **Available rules** (incluye `workflows` / required workflows) — <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets>
- **REST API: Repository rules** — <https://docs.github.com/en/rest/orgs/rules>

### Reusable workflows / Starter workflows
- **Reusing workflows** — <https://docs.github.com/en/actions/using-workflows/reusing-workflows>
- **Creating starter workflows for your organization** — <https://docs.github.com/en/actions/using-workflows/creating-starter-workflows-for-your-organization>
- **Sharing actions and workflows with your organization** — <https://docs.github.com/en/actions/creating-actions/sharing-actions-and-workflows-with-your-organization>

### Billing
- **About billing for GitHub Actions** — <https://docs.github.com/en/billing/managing-billing-for-your-products/managing-billing-for-github-actions/about-billing-for-github-actions>
- **Managing your spending limit for GitHub Actions** — <https://docs.github.com/en/billing/managing-billing-for-your-products/managing-billing-for-github-actions/managing-your-spending-limit-for-github-actions>
- **About larger runners** — <https://docs.github.com/en/actions/using-github-hosted-runners/about-larger-runners>
- **Usage limits, billing, and administration** — <https://docs.github.com/en/actions/learn-github-actions/usage-limits-billing-and-administration>

### Caching / Artifacts / GHCR
- **Caching dependencies** (nota del límite de 10 GB por repo) — <https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows>
- **Storing workflow data as artifacts** — <https://docs.github.com/en/actions/using-workflows/storing-workflow-data-as-artifacts>
- **Working with the Container registry (GHCR)** — <https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry>

### Concurrency
- **Using concurrency** — <https://docs.github.com/en/actions/using-jobs/using-concurrency>

### API y observabilidad
- **REST API: workflow runs** — <https://docs.github.com/en/rest/actions/workflow-runs>
- **REST API: workflow-run usage/timing** — <https://docs.github.com/en/rest/actions/workflow-runs#get-workflow-run-usage>
- **Webhook events: `workflow_run`** — <https://docs.github.com/en/webhooks/webhook-events-and-payloads#workflow_run>
- **Webhook events: `workflow_job`** — <https://docs.github.com/en/webhooks/webhook-events-and-payloads#workflow_job>

### Terraform / IaC del contrato
- **integrations/github provider** — <https://registry.terraform.io/providers/integrations/github/latest/docs>
- Recursos relevantes: `github_organization_ruleset`, `github_repository_ruleset`, `github_actions_organization_permissions`, `github_actions_organization_secret`.

## Referencia conceptual

- **DORA metrics** (lead time, deployment frequency, CFR, MTTR) — <https://dora.dev/>
- **Google SRE Workbook — SLOs** — <https://sre.google/workbook/implementing-slos/>
- **Platform Engineering** (CNCF) — <https://tag-app-delivery.cncf.io/whitepapers/platforms/>

## Herramientas

- **gh CLI** — <https://cli.github.com/>
- **GitHub Actions billing (dashboard)** — Settings → Billing → Plans and usage de la org.
- **StepSecurity Harden-Runner** (contexto `gha-13`, útil para auditoría de runners) — <https://github.com/step-security/harden-runner>

## Nota de verificación

Última verificación: pendiente de validar en Fase 4. Los multiplicadores de minutos (Linux ×1, Windows ×2, macOS ×10) han sido estables desde el lanzamiento de Actions, pero **verifica siempre** en billing docs antes de citar números a tu CFO. El modelo de "required workflows" nativo clásico está siendo reemplazado por **rulesets**; el ejemplo del módulo usa rulesets.
