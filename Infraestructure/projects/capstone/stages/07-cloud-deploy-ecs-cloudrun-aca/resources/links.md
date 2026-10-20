# Recursos — capstone stage 07 (Despliegue cloud)

## AWS — ECS Fargate + RDS + Secrets Manager

- ECS developer guide: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/
- Fargate overview: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html
- Task execution role vs task role: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html
- Pulling secrets into tasks: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/specifying-sensitive-data-secrets.html
- RDS for PostgreSQL user guide: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html
- Secrets Manager: https://docs.aws.amazon.com/secretsmanager/latest/userguide/
- Terraform `aws_ecs_service`: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service
- Terraform `aws_db_instance`: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance
- Terraform `aws_secretsmanager_secret`: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret

## GCP — Cloud Run v2 + Cloud SQL + Secret Manager

- Cloud Run overview: https://cloud.google.com/run/docs/overview/what-is-cloud-run
- Cloud Run service identity: https://cloud.google.com/run/docs/securing/service-identity
- Access Secret Manager secrets from Cloud Run: https://cloud.google.com/run/docs/configuring/services/secrets
- Cloud SQL private IP: https://cloud.google.com/sql/docs/postgres/configure-private-ip
- Terraform `google_cloud_run_v2_service`: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service
- Terraform `google_sql_database_instance`: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance
- Terraform `google_secret_manager_secret`: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret

## Azure — Container Apps + Postgres Flexible + Key Vault

- Azure Container Apps overview: https://learn.microsoft.com/en-us/azure/container-apps/overview
- Managed identities in Container Apps: https://learn.microsoft.com/en-us/azure/container-apps/managed-identity
- Reference Key Vault secrets from Container Apps: https://learn.microsoft.com/en-us/azure/container-apps/manage-secrets?tabs=azure-cli
- Azure Database for PostgreSQL Flexible Server: https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/
- Terraform `azurerm_container_app`: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_app
- Terraform `azurerm_postgresql_flexible_server`: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server
- Terraform `azurerm_key_vault`: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault

## Supply chain (hereda de etapa 05)

- cosign + container signatures: https://docs.sigstore.dev/cosign/overview/
- OCI image spec (digest format): https://github.com/opencontainers/image-spec/blob/main/descriptor.md#digests

## Costos y FinOps

- AWS Budgets: https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html
- GCP Billing budgets and alerts: https://cloud.google.com/billing/docs/how-to/budgets
- Azure Cost Management budgets: https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-acm-create-budgets
