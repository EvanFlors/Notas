# Recursos — tf-12

## Documentación oficial

- **Terraform `fmt`** — <https://developer.hashicorp.com/terraform/cli/commands/fmt>
- **Terraform `validate`** — <https://developer.hashicorp.com/terraform/cli/commands/validate>
- **Terraform `test` (nativo)** — <https://developer.hashicorp.com/terraform/language/tests>
- **Terraform `show -json`** — <https://developer.hashicorp.com/terraform/internals/json-format>
- **OpenTofu `test`** — <https://opentofu.org/docs/cli/commands/test/>

## Linters y scanners

- **tflint** — <https://github.com/terraform-linters/tflint>
  - Plugin AWS: <https://github.com/terraform-linters/tflint-ruleset-aws>
  - Plugin Google: <https://github.com/terraform-linters/tflint-ruleset-google>
  - Plugin Azure: <https://github.com/terraform-linters/tflint-ruleset-azurerm>
- **Checkov** — <https://www.checkov.io/>
  - Lista de checks AWS: <https://www.checkov.io/5.Policy%20Index/terraform.html>
- **Trivy config (misconfig IaC)** — <https://aquasecurity.github.io/trivy/latest/docs/scanner/misconfiguration/>
- **Terrascan** — <https://runterrascan.io/>

## Policy-as-code

- **Open Policy Agent** — <https://www.openpolicyagent.org/docs/latest/>
- **Rego language** — <https://www.openpolicyagent.org/docs/latest/policy-language/>
- **Conftest** — <https://www.conftest.dev/>
- **Rego Playground** — <https://play.openpolicyagent.org/>
- **Sentinel (HashiCorp)** — <https://developer.hashicorp.com/sentinel>
- **Reglas Rego para Terraform (ejemplos oficiales)** — <https://github.com/open-policy-agent/conftest/tree/master/examples/hcl2>

## Testing

- **Terratest (Gruntwork)** — <https://terratest.gruntwork.io/>
- **InSpec** (post-apply) — <https://www.chef.io/products/chef-inspec>
- **Terraform test — tutorial** — <https://developer.hashicorp.com/terraform/tutorials/configuration-language/test>

## Lecturas y referencia

- **"Policy as Code with Rego"** (OPA docs, intro paso a paso) — <https://www.openpolicyagent.org/docs/latest/policy-language/>
- **Gruntwork — Testing Terraform code** (blog serie) — <https://blog.gruntwork.io/>
- **Palo Alto / Prisma Cloud — Checkov blog** — <https://www.paloaltonetworks.com/blog?category=prisma-cloud>

## Herramientas complementarias (CI)

- **pre-commit hooks para Terraform** — <https://github.com/antonbabenko/pre-commit-terraform>
- **tfsec (deprecated, migrado a trivy)** — <https://github.com/aquasecurity/tfsec>

## Referencia para evaluar módulos de terceros

- **Terraform Registry (TF)** — <https://registry.terraform.io/>
- **OpenTofu Registry** — <https://search.opentofu.org/>
