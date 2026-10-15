# Recursos — tf-13-cicd-and-opentofu

## Documentación oficial

### Terraform CI/CD

- "Automate Terraform with CI/CD" (HashiCorp Learn) — https://developer.hashicorp.com/terraform/tutorials/automation/github-actions
- `hashicorp/setup-terraform` action — https://github.com/hashicorp/setup-terraform
- "terraform plan" + `-out` + `-detailed-exitcode` — https://developer.hashicorp.com/terraform/cli/commands/plan
- "terraform apply <planfile>" — https://developer.hashicorp.com/terraform/cli/commands/apply
- "Managing the dependency lock file" — https://developer.hashicorp.com/terraform/language/files/dependency-lock
- "Refresh-only mode" — https://developer.hashicorp.com/terraform/cli/commands/plan#planning-modes

### GitHub Actions patterns

- "Deployment environments" (environments, approvals, protection rules) — https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment
- "About security hardening with OpenID Connect" — https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect
- "Configuring OpenID Connect in AWS" — https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services
- `aws-actions/configure-aws-credentials` — https://github.com/aws-actions/configure-aws-credentials
- `marocchino/sticky-pull-request-comment` — https://github.com/marocchino/sticky-pull-request-comment
- `dawidd6/action-download-artifact` — https://github.com/dawidd6/action-download-artifact

### Terraform community actions / wrappers

- `dflook/terraform-github-actions` — https://github.com/dflook/terraform-github-actions
- `trstringer/manual-approval` (approval pattern alternatives) — https://github.com/trstringer/manual-approval

## OpenTofu

- Sitio oficial — https://opentofu.org/
- Instalación — https://opentofu.org/docs/intro/install/
- `opentofu/setup-opentofu` action — https://github.com/opentofu/setup-opentofu
- Registry — https://search.opentofu.org/
- "Migrating from Terraform" — https://opentofu.org/docs/intro/migration/
- "State and plan encryption" — https://opentofu.org/docs/language/state/encryption/
- "Provider-defined functions" — https://opentofu.org/docs/language/functions/#provider-defined-functions
- OpenTF Manifesto (contexto histórico, 2023) — https://web.archive.org/web/2023*/https://opentf.org/

## Licencias

- Business Source License (BUSL) — https://mariadb.com/bsl11/
- HashiCorp license announcement (2023) — https://www.hashicorp.com/blog/hashicorp-adopts-business-source-license
- Linux Foundation / OpenTofu announcement (2023) — https://www.linuxfoundation.org/press/announcing-opentofu

## Fundamentos y lectura adicional

- Gruntwork — "How to use OpenTofu with Terragrunt" — https://blog.gruntwork.io/
- "TOCTOU" (Wikipedia) — https://en.wikipedia.org/wiki/Time-of-check_to_time-of-use
- "Drift detection in Terraform" (community patterns) — https://spacelift.io/blog/terraform-drift-detection
- "The twelve-factor app" (relación con config as code) — https://12factor.net/

## Herramientas asociadas

- `tflint` — https://github.com/terraform-linters/tflint
- `checkov` — https://www.checkov.io/
- `conftest` (OPA) — https://www.conftest.dev/
- `tfsec` → ahora Trivy config — https://aquasecurity.github.io/trivy/
