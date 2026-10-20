# Recursos — tf-10-internals-graph-and-plan-algorithm

## Documentación oficial

- Terraform CLI — `terraform graph`: https://developer.hashicorp.com/terraform/cli/commands/graph
- Terraform CLI — `terraform plan` (flags `-refresh-only`, `-target`, `-refresh=false`): https://developer.hashicorp.com/terraform/cli/commands/plan
- Terraform CLI — `terraform show` y formato JSON: https://developer.hashicorp.com/terraform/cli/commands/show
- JSON output format (estable, versionado por `format_version`): https://developer.hashicorp.com/terraform/internals/json-format
- Managing resource drift: https://developer.hashicorp.com/terraform/tutorials/state/resource-drift
- Target resources (y por qué es escape hatch): https://developer.hashicorp.com/terraform/tutorials/state/resource-targeting
- Resource behavior y lifecycle (contexto de `ForceNew` / replace): https://developer.hashicorp.com/terraform/language/resources/behavior

## Protocolo de plugins

- Plugin framework / protocol overview: https://developer.hashicorp.com/terraform/plugin
- Plugin RPC: https://developer.hashicorp.com/terraform/plugin/how-terraform-works
- Debugging con `TF_LOG` y `TF_LOG_PROVIDER`: https://developer.hashicorp.com/terraform/internals/debugging

## OpenTofu (fork, mismo lenguaje)

- OpenTofu docs: https://opentofu.org/docs/
- Divergencias relevantes (`removed`, state encryption, provider-defined functions): https://opentofu.org/docs/intro/whats-new/

## Herramientas que consumen `plan.json`

- Conftest (OPA/Rego sobre `plan.json`): https://www.conftest.dev/
- Checkov (análisis estático sobre HCL y plan): https://www.checkov.io/
- infracost (cost diff sobre `plan.json`): https://www.infracost.io/

## Lecturas complementarias

- "Terraform: Up & Running" — Yevgeniy Brikman (capítulos de state y modules).
- HashiCorp Learn — "How Terraform works".
- Blog post del protocolo gRPC v5/v6 (archivo HashiCorp developer).
- Graphviz docs (para leer DOT a mano): https://graphviz.org/doc/info/lang.html
