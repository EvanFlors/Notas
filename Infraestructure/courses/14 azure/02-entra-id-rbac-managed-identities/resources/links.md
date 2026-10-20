# Recursos — az-02

## Documentación oficial

- Microsoft Entra ID — overview: <https://learn.microsoft.com/entra/fundamentals/whatis>
- App registrations vs Service Principals: <https://learn.microsoft.com/entra/identity-platform/app-objects-and-service-principals>
- Managed Identities overview: <https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/overview>
- System-assigned vs user-assigned: <https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/managed-identities-faq>
- IMDS endpoint (token acquisition): <https://learn.microsoft.com/azure/virtual-machines/instance-metadata-service>
- Azure RBAC overview: <https://learn.microsoft.com/azure/role-based-access-control/overview>
- Role definitions (built-in): <https://learn.microsoft.com/azure/role-based-access-control/built-in-roles>
- Custom roles: <https://learn.microsoft.com/azure/role-based-access-control/custom-roles>
- Role definition schema (`Actions` / `DataActions` / `AssignableScopes`): <https://learn.microsoft.com/azure/role-based-access-control/role-definitions>
- Key Vault RBAC vs Access Policies: <https://learn.microsoft.com/azure/key-vault/general/rbac-guide>
- Conditional Access overview: <https://learn.microsoft.com/entra/identity/conditional-access/overview>
- Privileged Identity Management (PIM): <https://learn.microsoft.com/entra/id-governance/privileged-identity-management/pim-configure>

## Terraform (`azurerm`)

- `azurerm_role_assignment`: <https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment>
- `azurerm_role_definition` (custom): <https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_definition>
- `azurerm_user_assigned_identity`: <https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity>
- `azurerm_key_vault` con `enable_rbac_authorization`: <https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault>

## Lecturas complementarias

- Microsoft Security — Managed Identity best practices: <https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/managed-identity-best-practice-recommendations>
- OIDC Federation GitHub Actions → Entra ID (preview para `az-10`): <https://learn.microsoft.com/entra/workload-id/workload-identity-federation-create-trust>
- Azure Policy `deny` effect vs AWS SCP (contexto para `az-09`): <https://learn.microsoft.com/azure/governance/policy/concepts/effects>
