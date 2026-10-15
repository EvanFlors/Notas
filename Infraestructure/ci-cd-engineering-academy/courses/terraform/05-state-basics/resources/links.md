# Recursos — tf-05

## Documentación oficial (Terraform / HashiCorp)

- **State overview** — <https://developer.hashicorp.com/terraform/language/state>
- **Manipulating state (CLI)** — <https://developer.hashicorp.com/terraform/cli/state>
  - `terraform state list` — <https://developer.hashicorp.com/terraform/cli/commands/state/list>
  - `terraform state show` — <https://developer.hashicorp.com/terraform/cli/commands/state/show>
  - `terraform state mv` — <https://developer.hashicorp.com/terraform/cli/commands/state/mv>
  - `terraform state rm` — <https://developer.hashicorp.com/terraform/cli/commands/state/rm>
  - `terraform state pull / push` — <https://developer.hashicorp.com/terraform/cli/commands/state/pull>
- **Sensitive data in state** — <https://developer.hashicorp.com/terraform/language/state/sensitive-data>
- **Backends overview** (local vs remote) — <https://developer.hashicorp.com/terraform/language/backend>
- **State locking** — <https://developer.hashicorp.com/terraform/language/state/locking>
- **Import** (conceptual) — <https://developer.hashicorp.com/terraform/language/import>
- **`moved` blocks** (alternativa a `state mv`) — <https://developer.hashicorp.com/terraform/language/modules/develop/refactoring>
- **`terraform refresh`** (deprecated as standalone; implícito en plan) — <https://developer.hashicorp.com/terraform/cli/commands/refresh>

## Documentación oficial (OpenTofu — complementaria)

- **State** — <https://opentofu.org/docs/language/state/>
- **State encryption** (nativa, divergencia frente a HashiCorp Terraform) — <https://opentofu.org/docs/language/state/encryption/>
- **Backends** — <https://opentofu.org/docs/language/settings/backends/configuration/>

## Providers didácticos usados en este módulo

- **random** — <https://registry.terraform.io/providers/hashicorp/random/latest/docs>
- **local** — <https://registry.terraform.io/providers/hashicorp/local/latest/docs>
- **null** — <https://registry.terraform.io/providers/hashicorp/null/latest/docs>

## Lectura complementaria

- Yevgeniy Brikman, *Terraform: Up & Running*, O'Reilly — capítulos sobre state y backends (edición vigente).
- HashiCorp blog, posts históricos sobre backend remoto y state locking (buscar título vigente al consultar).
- Gruntwork, "How to manage Terraform state" — <https://blog.gruntwork.io/how-to-manage-terraform-state-28f5697e68fa>
- Charity Majors / honeycomb, posts sobre operar IaC a escala (actitud operacional ante drift).

## Herramientas que verás más adelante

- **S3 + DynamoDB** (backend remoto más usado históricamente) — `tf-11`.
- **HCP Terraform / OpenTofu Cloud** (remote state + runs + policy) — `tf-11`, `tf-12`, `tf-13`.
- **tflint**, **Checkov**, **conftest** (lintig + policy) — `tf-12`.

## Nota de verificación

Última revisión de enlaces: pendiente de Fase 4. Todos los dominios son oficiales (`developer.hashicorp.com`, `opentofu.org`, `registry.terraform.io`); verificar disponibilidad y titulado al momento de desarrollar el curso.
