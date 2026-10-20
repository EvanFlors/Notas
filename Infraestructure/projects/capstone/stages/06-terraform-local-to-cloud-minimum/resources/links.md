# Recursos — Etapa 6 (IaC con Terraform, local → cloud mínimo)

## Terraform

- Terraform docs — [https://developer.hashicorp.com/terraform/docs](https://developer.hashicorp.com/terraform/docs)
- Partial backend configuration — [https://developer.hashicorp.com/terraform/language/backend#partial-configuration](https://developer.hashicorp.com/terraform/language/backend#partial-configuration)
- Style guide — [https://developer.hashicorp.com/terraform/language/style](https://developer.hashicorp.com/terraform/language/style)

## AWS

- S3 backend — [https://developer.hashicorp.com/terraform/language/backend/s3](https://developer.hashicorp.com/terraform/language/backend/s3)
- ECR provider — [https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository)
- OIDC with GitHub Actions — [https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- `aws-actions/configure-aws-credentials` — [https://github.com/aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials)
- LocalStack (lab-only AWS emulation) — [https://docs.localstack.cloud/](https://docs.localstack.cloud/)

## GCP

- GCS backend — [https://developer.hashicorp.com/terraform/language/backend/gcs](https://developer.hashicorp.com/terraform/language/backend/gcs)
- Artifact Registry — [https://cloud.google.com/artifact-registry/docs](https://cloud.google.com/artifact-registry/docs)
- Workload Identity Federation — [https://cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines](https://cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines)
- `google-github-actions/auth` — [https://github.com/google-github-actions/auth](https://github.com/google-github-actions/auth)

## Azure

- AzureRM backend — [https://developer.hashicorp.com/terraform/language/backend/azurerm](https://developer.hashicorp.com/terraform/language/backend/azurerm)
- Azure Container Registry — [https://learn.microsoft.com/azure/container-registry/](https://learn.microsoft.com/azure/container-registry/)
- Federated credentials for GitHub — [https://learn.microsoft.com/entra/workload-id/workload-identity-federation-create-trust?pivots=identity-wif-apps-methods-azp#github-actions](https://learn.microsoft.com/entra/workload-id/workload-identity-federation-create-trust?pivots=identity-wif-apps-methods-azp#github-actions)
- `azure/login` — [https://github.com/Azure/login](https://github.com/Azure/login)

## ADR

- Michael Nygard, "Documenting Architecture Decisions" — [https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- `adr-tools` — [https://github.com/npryce/adr-tools](https://github.com/npryce/adr-tools)
