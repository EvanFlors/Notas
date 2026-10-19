# Recursos — gl-03

Referencias oficiales y lecturas de apoyo. **Verificar en Fase 4** del curso para asegurar vigencia (GitLab publica releases cada mes 22; nombres y features pueden cambiar).

## Oficiales (GitLab)

- **CI/CD variables (general)**: `https://docs.gitlab.com/ee/ci/variables/`
- **Predefined CI/CD variables (`$CI_*`)**: `https://docs.gitlab.com/ee/ci/variables/predefined_variables.html`
- **Protect a CI/CD variable**: `https://docs.gitlab.com/ee/ci/variables/#protect-a-cicd-variable`
- **Mask a CI/CD variable**: `https://docs.gitlab.com/ee/ci/variables/#mask-a-cicd-variable`
- **Variable types (`variable` vs `file`)**: `https://docs.gitlab.com/ee/ci/variables/#use-file-type-cicd-variables`
- **Variable precedence**: `https://docs.gitlab.com/ee/ci/variables/#cicd-variable-precedence`
- **Group-level variables**: `https://docs.gitlab.com/ee/ci/variables/#for-a-group`
- **Environment-scoped variables**: `https://docs.gitlab.com/ee/ci/environments/#limit-the-environment-scope-of-a-cicd-variable`

## ID Tokens (OIDC desde GitLab)

- **ID tokens overview**: `https://docs.gitlab.com/ee/ci/secrets/id_token_authentication.html`
- **Keyword reference `id_tokens:`**: `https://docs.gitlab.com/ee/ci/yaml/#id_tokens`
- **JWT claims payload**: `https://docs.gitlab.com/ee/ci/secrets/id_token_authentication.html#token-payload`

## Secret managers (integración nativa `secrets:`)

- **`secrets:` keyword reference**: `https://docs.gitlab.com/ee/ci/yaml/#secrets`
- **HashiCorp Vault (JWT auth con GitLab ID Token)**: `https://docs.gitlab.com/ee/ci/secrets/hashicorp_vault.html`
- **Vault JWT/OIDC auth method**: `https://developer.hashicorp.com/vault/docs/auth/jwt`
- **Azure Key Vault**: `https://docs.gitlab.com/ee/ci/secrets/azure_key_vault.html`
- **GCP Secret Manager**: `https://docs.gitlab.com/ee/ci/secrets/gcp_secret_manager.html`
- **AWS Secrets Manager** (verificar disponibilidad por plan): `https://docs.gitlab.com/ee/ci/secrets/`

## OIDC a cloud providers sin keys

- **GitLab → AWS (OIDC federation con IAM)**: `https://docs.gitlab.com/ee/ci/cloud_services/aws/`
- **GitLab → GCP (Workload Identity Federation)**: `https://docs.gitlab.com/ee/ci/cloud_services/google_cloud/`
- **GitLab → Azure (Workload Identity Federation)**: `https://docs.gitlab.com/ee/ci/cloud_services/azure/`

## Seguridad

- **Pipeline security best practices**: `https://docs.gitlab.com/ee/ci/pipelines/pipeline_security.html`
- **Secret Detection scanner (job-level, se verá en gl-08)**: `https://docs.gitlab.com/ee/user/application_security/secret_detection/`

## Comparación con GitHub Actions

- **GHA OIDC a AWS**: `https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services`
- Mapping conceptual (GHA ↔ GitLab):
  - `secrets.FOO` ↔ Project/Group variable con `masked: true`.
  - `environments: { protection_rules: ... }` ↔ Protected Environment + variable con `environment_scope: production`.
  - `permissions: id-token: write` ↔ `id_tokens:` block en el job.
  - `aws-actions/configure-aws-credentials` ↔ Vault/AWS SM via `secrets:` o `aws sts assume-role-with-web-identity` manual.

## Checklist de verificación requerida en Fase 4

- Alfabeto exacto permitido por `masked:` (puede ampliarse con el tiempo).
- Longitud mínima de valor enmascarable (default 8, configurable en self-managed).
- Lista actual de secret managers soportados nativamente en `secrets:` (ampliación continua).
- Claims disponibles en el ID Token (GitLab va añadiendo claims; verificar `runner_environment`, `ref_protected`, etc.).
- Pricing: ID Tokens y `secrets:` nativo son gratis en todos los planes de GitLab SaaS; confirmar que sigue así.
- Vault OSS vs Vault Enterprise/HCP: diferencia de features para JWT auth role templating.
