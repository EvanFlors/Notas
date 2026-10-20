# Starter — az-06-01-capstone-secrets-via-kv

Esta actividad es **independiente**: produces 2 archivos HCL + 1 JSON + 1 Markdown.

## Pasos

1. Lee `../README.md` completo y recorre `../../examples/01-key-vault-rbac-dataplane/`.
2. Prepara el directorio:

   ```bash
   mkdir -p /tmp/az-06-01
   cd /tmp/az-06-01
   ```

3. Escribe los 4 archivos (nombres exactos):
   - `main.tf`
   - `variables.tf`
   - `role-assignment-kv-secrets-user.json`
   - `README-INTENT.md`

4. Verifica el JSON:

   ```bash
   jq . role-assignment-kv-secrets-user.json >/dev/null && echo OK
   ```

5. (Opcional) Formatea el HCL:

   ```bash
   terraform fmt -check main.tf variables.tf
   ```

6. Valida:

   ```bash
   bash <ruta-repo>/courses/azure/06-key-vault-and-managed-identities-consumer/activities/01-capstone-secrets-via-kv/tests/validate.sh /tmp/az-06-01
   ```

7. Compara con `../solution/REFERENCE.md` para autoevaluarte.

## Esqueletos útiles

### Esqueleto mínimo de `main.tf`

```hcl
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

# TODO: azurerm_user_assigned_identity
# TODO: azurerm_key_vault con enable_rbac_authorization = true
# TODO: azurerm_role_assignment "Key Vault Secrets User"
# TODO: azurerm_key_vault_secret con value dummy
```

### Esqueleto del JSON

```json
{
  "principalId": "00000000-0000-0000-0000-000000000000",
  "principalType": "ServicePrincipal",
  "roleDefinitionId": "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/4633458b-17de-408a-b874-0445c86b69e6",
  "scope": "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<kv>"
}
```

> **Recuerda**: ningún secret real, ningún tenant/subscription ID real. El validador no te pide valores reales; te pide **estructura** correcta.
