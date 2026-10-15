# Recursos — tf-09

## Documentación oficial — Terraform

- **Lenguaje: `provider`** — <https://developer.hashicorp.com/terraform/language/providers/configuration>
- **`required_providers`** — <https://developer.hashicorp.com/terraform/language/providers/requirements>
- **Multiple provider instances (`alias`)** — <https://developer.hashicorp.com/terraform/language/providers/configuration#alias-multiple-provider-configurations>
- **Meta-argument `lifecycle`** — <https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle>
- **`moved` blocks** — <https://developer.hashicorp.com/terraform/language/modules/develop/refactoring>
- **`import` blocks (TF ≥ 1.5)** — <https://developer.hashicorp.com/terraform/language/import>
- **`removed` blocks (TF ≥ 1.7)** — <https://developer.hashicorp.com/terraform/language/resources/syntax#removing-resources>
- **`terraform apply -replace`** — <https://developer.hashicorp.com/terraform/cli/commands/plan#replace-address>
- **`terraform taint` (deprecado)** — <https://developer.hashicorp.com/terraform/cli/commands/taint>
- **Provisioners (y por qué son último recurso)** — <https://developer.hashicorp.com/terraform/language/resources/provisioners/syntax>

## Documentación oficial — OpenTofu

- **OpenTofu docs** — <https://opentofu.org/docs/>
- **`removed` block en OpenTofu** — <https://opentofu.org/docs/language/resources/syntax/#removing-resources>
- **State encryption (divergente de TF)** — <https://opentofu.org/docs/language/state/encryption/>

## Providers didácticos usados en el módulo

- **`hashicorp/local`** — <https://registry.terraform.io/providers/hashicorp/local/latest/docs>
- **`hashicorp/random`** — <https://registry.terraform.io/providers/hashicorp/random/latest/docs>
- **`hashicorp/null`** — <https://registry.terraform.io/providers/hashicorp/null/latest/docs>

## Guías conceptuales

- **Refactoring guide (official)** — <https://developer.hashicorp.com/terraform/language/modules/develop/refactoring>
- **Resource behavior y lifecycle** — <https://developer.hashicorp.com/terraform/language/resources/behavior>
- **Blog: `import` blocks walkthrough** — buscar "Terraform 1.5 import blocks" en developer.hashicorp.com/blog.

## Lecturas complementarias (patterns, antipatterns)

- **Gruntwork: Terraform Best Practices (lifecycle)** — <https://www.gruntwork.io/>
- **"How Terraform's `prevent_destroy` works and when it doesn't"** — buscar por título; varias versiones comunitarias.
- **"Avoiding provisioners in Terraform"** — HashiCorp blog y guías comunitarias.

## Herramientas útiles

- **`tflint`** — <https://github.com/terraform-linters/tflint>
- **`terraform-docs`** — <https://terraform-docs.io/>
- **`terraform state`** CLI reference — <https://developer.hashicorp.com/terraform/cli/commands/state>
