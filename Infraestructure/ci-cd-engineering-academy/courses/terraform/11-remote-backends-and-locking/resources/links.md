# Recursos — tf-11

## Documentación oficial

- Terraform — [Backends: configuration](https://developer.hashicorp.com/terraform/language/backend)
- Terraform — [S3 backend reference](https://developer.hashicorp.com/terraform/language/backend/s3)
- Terraform — [`terraform_remote_state` data source](https://developer.hashicorp.com/terraform/language/state/remote-state-data)
- Terraform — [State locking](https://developer.hashicorp.com/terraform/language/state/locking)
- Terraform — [`terraform force-unlock`](https://developer.hashicorp.com/terraform/cli/commands/force-unlock)
- Terraform — [`terraform init -migrate-state`](https://developer.hashicorp.com/terraform/cli/commands/init#backend-initialization)
- OpenTofu — [Backends overview](https://opentofu.org/docs/language/settings/backends/configuration/)
- OpenTofu — [State encryption](https://opentofu.org/docs/language/state/encryption/)
- HCP Terraform / Terraform Cloud — [`cloud` block](https://developer.hashicorp.com/terraform/cli/cloud/settings)

## Backends alternativos

- [GCS backend](https://developer.hashicorp.com/terraform/language/backend/gcs)
- [AzureRM backend](https://developer.hashicorp.com/terraform/language/backend/azurerm)
- [HTTP backend](https://developer.hashicorp.com/terraform/language/backend/http)
- [Kubernetes backend](https://developer.hashicorp.com/terraform/language/backend/kubernetes) (verifica estado de soporte antes de adoptarlo)
- GitLab — [Terraform state managed](https://docs.gitlab.com/ee/user/infrastructure/iac/terraform_state.html)

## AWS

- S3 — [Bucket versioning](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html)
- S3 — [Server-side encryption](https://docs.aws.amazon.com/AmazonS3/latest/userguide/serv-side-encryption.html)
- S3 — [Block public access](https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html)
- DynamoDB — [PutItem con `attribute_not_exists`](https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_PutItem.html)
- IAM — [Policies for Terraform remote state in S3](https://developer.hashicorp.com/terraform/language/backend/s3#permissions)

## Entornos locales

- LocalStack — [S3 docs](https://docs.localstack.cloud/user-guide/aws/s3/)
- LocalStack — [DynamoDB docs](https://docs.localstack.cloud/user-guide/aws/dynamodb/)

## Lecturas complementarias

- Gruntwork — [How to manage Terraform state](https://blog.gruntwork.io/how-to-manage-terraform-state-28f5697e68fa)
- Spacelift — [Terraform state best practices](https://spacelift.io/blog/terraform-state) (comparar con criterio)
- HashiCorp — [S3 native state locking announcement](https://www.hashicorp.com/blog) (buscar "S3 native locking" para el post vigente)
- Terraform Up & Running, cap. 3 "How to manage Terraform state" — Yevgeniy Brikman.

## Herramientas útiles

- [`tfstate-lookup`](https://github.com/fujiwara/tfstate-lookup) — leer outputs sin cargar el provider.
- [`terraform-docs`](https://github.com/terraform-docs/terraform-docs) — generar docs de módulos.
- `aws s3api list-object-versions` + `aws s3api copy-object` para rollback de state corrupto.

## Verificar en Fase 4

- Versión mínima de Terraform / OpenTofu que soporta `use_lockfile = true` (S3 native locking).
- Estado actual del backend `kubernetes` (en algunas eras fue marcado "no recomendado").
- Pricing de HCP Terraform y OpenTofu Cloud (planes free vs team vs enterprise).
