# Resources — gh-12 governance and automation

## Documentación oficial

### Rulesets y branch protection

- Managing rulesets — <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets>
- Available rules — <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets>
- About rulesets — <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets>
- Classic branch protection reference (migration) — <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches>
- Merge queue — <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue>

### CODEOWNERS

- About code owners — <https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners>
- CODEOWNERS syntax — <https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners#codeowners-syntax>
- CODEOWNERS errors API — <https://docs.github.com/en/rest/repos/repos#list-codeowners-errors>

### Environments

- Using environments for deployment — <https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment>
- Managing environments — <https://docs.github.com/en/actions/deployment/targeting-different-environments/managing-environments-for-deployment>
- Environment protection rules — <https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment#environment-protection-rules>

### Identidad y tokens

- About authentication to GitHub — <https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/about-authentication-to-github>
- Creating a fine-grained PAT — <https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens>
- Creating a GitHub App — <https://docs.github.com/en/apps/creating-github-apps>
- Authenticating with a GitHub App — <https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/about-authentication-with-a-github-app>
- `actions/create-github-app-token` (obtain installation token in a workflow) — <https://github.com/actions/create-github-app-token>

### OIDC

- About security hardening with OpenID Connect — <https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect>
- Configuring OpenID Connect in AWS — <https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services>
- Configuring OpenID Connect in GCP — <https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-google-cloud-platform>
- Configuring OpenID Connect in Azure — <https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure>
- `aws-actions/configure-aws-credentials` — <https://github.com/aws-actions/configure-aws-credentials>

### `gh` CLI y API

- `gh` manual — <https://cli.github.com/manual/>
- `gh api` — <https://cli.github.com/manual/gh_api>
- REST API — Rulesets — <https://docs.github.com/en/rest/repos/rules>
- GraphQL API — <https://docs.github.com/en/graphql>

### Webhooks

- About webhooks — <https://docs.github.com/en/webhooks>
- Webhook events and payloads — <https://docs.github.com/en/webhooks/webhook-events-and-payloads>

### Audit log

- About the audit log for an org — <https://docs.github.com/en/organizations/keeping-your-organization-secure/managing-security-settings-for-your-organization/reviewing-the-audit-log-for-your-organization>
- Audit log REST API — <https://docs.github.com/en/rest/orgs/orgs#get-the-audit-log-for-an-organization>

## Lecturas y charlas recomendadas

- GitHub blog — Rulesets GA announcement (buscar en el changelog oficial) — <https://github.blog/changelog/>
- SLSA framework (relevante para `gh-13`) — <https://slsa.dev/>
- Michael Nygard — "Documenting Architecture Decisions" (ADR original) — <https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions>

## Herramientas útiles

- `gh` CLI — <https://cli.github.com/>
- `jq` — <https://stedolan.github.io/jq/>
- `yq` — <https://github.com/mikefarah/yq>
- `actionlint` (lint de workflows) — <https://github.com/rhysd/actionlint>
