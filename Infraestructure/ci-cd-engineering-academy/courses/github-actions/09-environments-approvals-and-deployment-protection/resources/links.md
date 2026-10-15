# Recursos — gha-09

## Documentación oficial de GitHub Actions

- **Using environments for deployment**. <https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment>
- **Managing environments for deployment**. <https://docs.github.com/en/actions/deployment/targeting-different-environments/managing-environments-for-deployment>
- **Deployment protection rules**. <https://docs.github.com/en/actions/deployment/protecting-deployments/configuring-deployment-protection-rules>
- **Creating custom deployment protection rules** (GitHub Apps). <https://docs.github.com/en/actions/deployment/protecting-deployments/creating-custom-deployment-protection-rules>
- **Reviewing deployments**. <https://docs.github.com/en/actions/deployment/targeting-different-environments/reviewing-deployments>
- **Workflow syntax: `jobs.<job_id>.environment`**. <https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idenvironment>
- **Using secrets in GitHub Actions**. <https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions>
- **About the deployments API**. <https://docs.github.com/en/rest/deployments/deployments>
- **Deployment statuses API**. <https://docs.github.com/en/rest/deployments/statuses>
- **Environments API**. <https://docs.github.com/en/rest/deployments/environments>
- **Deployment branch policies API**. <https://docs.github.com/en/rest/deployments/branch-policies>

## GitHub CLI (`gh`)

- Manual completo. <https://cli.github.com/manual/>
- `gh api` (para environments y branch policies). <https://cli.github.com/manual/gh_api>
- `gh secret set --env`. <https://cli.github.com/manual/gh_secret_set>
- `gh variable set --env`. <https://cli.github.com/manual/gh_variable_set>

## Herramientas

- **actionlint** (lint estático de workflows). <https://github.com/rhysd/actionlint>
- **yq** (consultar YAML). <https://github.com/mikefarah/yq>

## Patrones y lecturas

- **Progressive delivery con environments y canaries** (artículo general). <https://martinfowler.com/articles/progressive-delivery.html>
- **Google SRE book — Release Engineering**. <https://sre.google/sre-book/release-engineering/>
- **GitHub Blog — Environments and deployments**. <https://github.blog/>

## Relacionado dentro del programa

- `gha-05-secrets-variables-and-environments-basics` — introducción a environments como namespace de secretos.
- `gha-11-oidc-and-cloud-federation` — usa el claim `environment:` para gating en AWS/GCP/Azure.
- `gha-15-platform-patterns-and-cost-governance` — environments como parte del *platform contract* a nivel org.
- `gh-12-github-governance-and-automation` — rulesets, CODEOWNERS, GitHub Apps.
