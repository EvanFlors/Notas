# Recursos — tf-04-variables-outputs-locals

> A verificar en Fase 4 del plan del curso. Prioridad: docs oficiales de
> Terraform y OpenTofu — el lenguaje es idéntico en esta superficie.

## Documentación oficial

### Terraform (HashiCorp)

- Bloque [`variable`](https://developer.hashicorp.com/terraform/language/values/variables) — tipos, `default`, `description`, `sensitive`, `nullable`.
- Bloque [`locals`](https://developer.hashicorp.com/terraform/language/values/locals).
- Bloque [`output`](https://developer.hashicorp.com/terraform/language/values/outputs).
- [Variable definition precedence](https://developer.hashicorp.com/terraform/language/values/variables#variable-definition-precedence) — orden exacto de resolución.
- [Custom validation rules](https://developer.hashicorp.com/terraform/language/values/variables#custom-validation-rules) — bloques `validation` dentro de `variable`.
- [Sensitive input variables](https://developer.hashicorp.com/terraform/language/values/variables#suppressing-values-in-cli-output) y [Sensitive values in state](https://developer.hashicorp.com/terraform/language/state/sensitive-data) — alcance y límites.
- [Type constraints](https://developer.hashicorp.com/terraform/language/expressions/type-constraints) — `object({...})`, `tuple([...])`, `optional(T, default)`.
- Comando [`terraform output`](https://developer.hashicorp.com/terraform/cli/commands/output) — flags `-raw` y `-json`.

### OpenTofu

- [`variable`](https://opentofu.org/docs/language/values/variables/), [`locals`](https://opentofu.org/docs/language/values/locals/), [`output`](https://opentofu.org/docs/language/values/outputs/) — equivalencia completa con TF para esta superficie.

## Patrones de secretos

- HashiCorp Vault — [`vault` provider](https://registry.terraform.io/providers/hashicorp/vault/latest/docs) y data sources (`vault_generic_secret`, `vault_kv_secret_v2`).
- AWS Secrets Manager — [`aws_secretsmanager_secret_version`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) data source.
- GCP Secret Manager — [`google_secret_manager_secret_version`](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/secret_manager_secret_version) data source.
- Mozilla SOPS — [`sops` provider](https://registry.terraform.io/providers/carlpett/sops/latest/docs) para leer secrets cifrados en Git con llaves KMS/age/PGP.

## Lecturas recomendadas

- Gruntwork — "How to manage Terraform secrets" (artículo canónico sobre por qué `sensitive` no basta).
- HashiCorp Learn — [Protect sensitive input variables](https://developer.hashicorp.com/terraform/tutorials/configuration-language/sensitive-variables).
- HashiCorp Learn — [Customize Terraform configuration with variables](https://developer.hashicorp.com/terraform/tutorials/configuration-language/variables).
- Terraform best practices (comunidad) — convención `variables.tf` / `outputs.tf` / `envs/*.tfvars`.

## Checklist a verificar en Fase 4

- Vigencia de `optional(T, default)` en `object` (introducido en 1.3, estable desde 1.4).
- UX actual de `terraform output -raw` / `-json`.
- Divergencias OpenTofu en manejo de `sensitive` (hasta la fecha, equivalente a TF).
- Compatibilidad `*.auto.tfvars` cross-tool.
