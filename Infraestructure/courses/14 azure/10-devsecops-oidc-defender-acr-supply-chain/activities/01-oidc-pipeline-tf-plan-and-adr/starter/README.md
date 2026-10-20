# Starter — az-10-01-oidc-pipeline-tf-plan-and-adr

Actividad **independiente**: no hay plantilla ejecutable. Tu entregable es un ADR + archivos Terraform plan-only + un workflow YAML.

## Pasos

1. Lee `../README.md` completo y recorre los tres `examples/` del modulo (`01-oidc-federation-github-to-azure`, `02-acr-cosign-sign-and-verify`, `03-defender-for-containers-config`).
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/az-10-01/terraform
   mkdir -p /tmp/az-10-01/.github/workflows
   cd /tmp/az-10-01
   ```
3. Crea `ADR-DEVSECOPS-SUPPLY-CHAIN.md` con las 6 secciones estandar (Estado, Contexto, Decision, Consecuencias, Alternativas + heading ADR).
4. Crea `terraform/main.tf`, `terraform/oidc.tf`, `terraform/acr.tf`, `terraform/defender.tf` con los campos documentados en §5.3 del README.
5. Crea `.github/workflows/build-sign-push.yml` con `permissions: id-token: write` y `azure/login@...` SIN secrets.
6. Valida:
   ```bash
   bash <ruta-repo>/courses/azure/10-devsecops-oidc-defender-acr-supply-chain/activities/01-oidc-pipeline-tf-plan-and-adr/tests/validate.sh /tmp/az-10-01
   ```
7. Compara con `../solution/REFERENCE.md` para autoevaluar.

## Esqueletos sugeridos (opcionales)

### `terraform/main.tf`

```hcl
terraform {
  required_version = ">= 1.6"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = ">= 3.100" }
    azuread = { source = "hashicorp/azuread", version = ">= 2.50" }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "00000000-0000-0000-0000-000000000000"
}
```

### `terraform/oidc.tf`

```hcl
resource "azuread_application" "gha_checkout" {
  display_name = "gha-deployer-checkout-prod"
}

resource "azuread_service_principal" "gha_checkout" {
  client_id = azuread_application.gha_checkout.client_id
}

resource "azuread_application_federated_identity_credential" "main_branch" {
  application_id = azuread_application.gha_checkout.id
  display_name   = "gha-checkout-main"
  description    = "GHA main branch of acme/checkout"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:acme/checkout:ref:refs/heads/main"
}
```

### `terraform/acr.tf`

```hcl
resource "azurerm_container_registry" "checkout_prod" {
  name                          = "acrcheckoutprod"
  resource_group_name           = "rg-checkout-prod"
  location                      = "westeurope"
  sku                           = "Premium"
  admin_enabled                 = false
  public_network_access_enabled = false
}
```

### `terraform/defender.tf`

```hcl
resource "azurerm_security_center_subscription_pricing" "containers" {
  tier          = "Standard"
  resource_type = "Containers"
}
```

### `.github/workflows/build-sign-push.yml`

```yaml
name: build-sign-push
on:
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: azure/login@v2
        with:
          client-id: ${{ vars.AZURE_CLIENT_ID }}
          tenant-id: ${{ vars.AZURE_TENANT_ID }}
          subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}
      - run: az account show
```

> El validador NO ejecuta `terraform` ni `az`. Solo lee los archivos.
