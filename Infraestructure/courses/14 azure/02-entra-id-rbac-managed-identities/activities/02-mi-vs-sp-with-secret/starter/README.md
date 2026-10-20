# Starter — az-02-02-mi-vs-sp-with-secret

Esta actividad es **independiente**: produces 3 archivos HCL + 1 Markdown. **Nada se aplica**.

## Pasos

1. Lee `../README.md` completo y recorre `../../examples/02-managed-identity-vm-to-keyvault/`.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/az-02-misp
   cd /tmp/az-02-misp
   ```
3. Escribe los archivos (nombres exactos):
   - `main.tf` — patrón recomendado (MI).
   - `main-antipattern.tf` — anti-patrón (SPN + client secret).
   - `variables.tf` — al menos `location`.
4. Verifica (opcional, no requerido por el validador):
   ```bash
   # Si tienes terraform instalado:
   terraform fmt -check -diff
   # NO hagas terraform init / apply — no hay credenciales ni se pretende.
   ```
5. Escribe `README-INTENT.md` con las 4 secciones listadas en `../README.md` §5.3.
6. Valida:
   ```bash
   bash <ruta-repo>/courses/azure/02-entra-id-rbac-managed-identities/activities/02-mi-vs-sp-with-secret/tests/validate.sh /tmp/az-02-misp
   ```
7. Compara con `../solution/` para autoevaluarte.

## Esqueleto base para `main.tf`

```hcl
terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.100" }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "demo" {
  name     = "rg-mi-demo"
  location = var.location
}

resource "azurerm_user_assigned_identity" "app" {
  name                = "mi-checkout-app"
  resource_group_name = azurerm_resource_group.demo.name
  location            = azurerm_resource_group.demo.location
}

# Key Vault en modo RBAC data-plane (preferir sobre access policies legacy)
# ... completar: azurerm_key_vault, azurerm_role_assignment, VM Linux con identity block ...
```

> El validador comprueba presencia de bloques HCL por grep y ausencia de secrets / UUIDs reales. **No** llama a `terraform init` ni necesita credenciales.
