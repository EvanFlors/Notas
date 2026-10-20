# az-06 — Recursos y referencias

## Documentación oficial

- [Azure Key Vault — overview](https://learn.microsoft.com/en-us/azure/key-vault/general/overview)
- [Key Vault — RBAC guide (data plane)](https://learn.microsoft.com/en-us/azure/key-vault/general/rbac-guide)
- [Key Vault — built-in roles](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#security)
- [Key Vault — soft delete overview](https://learn.microsoft.com/en-us/azure/key-vault/general/soft-delete-overview)
- [Key Vault — certificates overview](https://learn.microsoft.com/en-us/azure/key-vault/certificates/about-certificates)
- [Key Vault — certificate policy](https://learn.microsoft.com/en-us/azure/key-vault/certificates/certificate-policy)
- [Managed Identities for Azure resources](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview)
- [Container Apps — manage secrets with Key Vault references](https://learn.microsoft.com/en-us/azure/container-apps/manage-secrets)
- [App Service — Key Vault references](https://learn.microsoft.com/en-us/azure/app-service/app-service-key-vault-references)
- [AKS — Secrets Store CSI Driver with Azure Key Vault provider](https://learn.microsoft.com/en-us/azure/aks/csi-secrets-store-driver)
- [AKS — Workload Identity](https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview)

## Terraform provider

- [`azurerm_key_vault`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault)
- [`azurerm_key_vault_secret`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret)
- [`azurerm_key_vault_certificate`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_certificate)
- [`azurerm_user_assigned_identity`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity)
- [`azurerm_role_assignment`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment)
- [`azurerm_container_app`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_app)
- [`azurerm_federated_identity_credential`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/federated_identity_credential)

## Lecturas complementarias

- [Azure security baseline for Key Vault](https://learn.microsoft.com/en-us/security/benchmark/azure/baselines/key-vault-security-baseline)
- [Rotation tutorial — single-user with Function + Event Grid](https://learn.microsoft.com/en-us/azure/key-vault/secrets/tutorial-rotation)
- [Azure Key Vault REST API (data plane)](https://learn.microsoft.com/en-us/rest/api/keyvault/)
- [DefaultAzureCredential (Python)](https://learn.microsoft.com/en-us/python/api/azure-identity/azure.identity.defaultazurecredential)

## Equivalencias AWS (para el estudiante que viene del lado AWS)

| Azure | AWS |
|-------|-----|
| Key Vault — secret | Secrets Manager — secret |
| Key Vault — key | KMS — CMK |
| Key Vault — certificate | ACM / ACM Private CA |
| Managed Identity (User-Assigned) | IAM Role asumible por EC2/ECS/Lambda via instance profile / task role |
| Workload Identity (AKS) | IRSA (EKS) |
| `Key Vault Secrets User` role | `secretsmanager:GetSecretValue` + resource policy |
