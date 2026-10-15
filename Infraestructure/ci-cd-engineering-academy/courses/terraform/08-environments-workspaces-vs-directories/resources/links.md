# Recursos — tf-08

## Documentación oficial

- **Terraform — CLI Workspaces** — <https://developer.hashicorp.com/terraform/cli/workspaces>
- **Terraform — "When to use Workspaces" (nota explícita de que no son para separar prod)** — <https://developer.hashicorp.com/terraform/cli/workspaces#when-to-use-multiple-workspaces>
- **Terraform — `terraform.workspace` expression** — <https://developer.hashicorp.com/terraform/language/state/workspaces#current-workspace-interpolation>
- **Terraform — Backends** — <https://developer.hashicorp.com/terraform/language/backend>
- **Terraform — Backend `local`** — <https://developer.hashicorp.com/terraform/language/backend/local>
- **Terraform — Backend `s3` (incluye prefijo `env:/` por workspace)** — <https://developer.hashicorp.com/terraform/language/backend/s3>
- **Terraform — Module sources** — <https://developer.hashicorp.com/terraform/language/modules/sources>
- **Terraform — Standard Module Structure** — <https://developer.hashicorp.com/terraform/language/modules/develop/structure>

## OpenTofu (equivalentes)

- **OpenTofu — CLI Workspaces** — <https://opentofu.org/docs/cli/workspaces/>
- **OpenTofu — Backends** — <https://opentofu.org/docs/language/settings/backends/configuration/>

## Patrones y guías

- **Gruntwork — "How to manage multiple environments with Terraform"** — <https://blog.gruntwork.io/how-to-manage-multiple-environments-with-terraform-32c7bc5d692>
- **Terraform: Up & Running (Yevgeniy Brikman)** — capítulos sobre workspaces vs file-layout.
- **Terragrunt — "Keep your Terraform code DRY"** — <https://terragrunt.gruntwork.io/docs/features/keep-your-terraform-code-dry/>
- **Terragrunt — "Keep your remote state configuration DRY"** — <https://terragrunt.gruntwork.io/docs/features/keep-your-remote-state-configuration-dry/>
- **AWS Prescriptive Guidance — "Organizing Terraform state"** — <https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/organization.html>

## Anti-patrones

- **"Don't use workspaces for environments"** — búsquedas: *"terraform workspaces considered harmful"*, *"terraform workspaces vs directories"*. Hay múltiples posts de la comunidad con esta tesis (Gruntwork, Masterpoint, HashiCorp discuss).
- **HashiCorp community thread — workspaces vs directory structure** — <https://discuss.hashicorp.com/t/using-terraform-workspaces-to-manage-environments/48736>

## ADR y gobernanza

- **ADR template (Michael Nygard)** — <https://github.com/joelparkerhenderson/architecture-decision-record/tree/main/locales/en/templates/decision-record-template-by-michael-nygard>
- **ADR repository (ejemplos reales de ADRs de infra)** — <https://adr.github.io/>

## Herramientas relacionadas (se profundiza en módulos posteriores)

- **Checkov** — <https://www.checkov.io/>
- **tflint** — <https://github.com/terraform-linters/tflint>
- **Open Policy Agent / Conftest** — <https://www.openpolicyagent.org/docs/latest/>, <https://www.conftest.dev/>

## Providers didácticos usados en este módulo

- **`hashicorp/random`** — <https://registry.terraform.io/providers/hashicorp/random/latest/docs>
- **`hashicorp/local`** — <https://registry.terraform.io/providers/hashicorp/local/latest/docs>
- **`hashicorp/null`** — <https://registry.terraform.io/providers/hashicorp/null/latest/docs>
