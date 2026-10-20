# Starter — az-03-02-hub-spoke-tf

Esta actividad es **independiente**. Tu entregable: 5 archivos HCL + 1 Markdown.

## Pasos

1. Lee `../README.md` completo y recorre `examples/03-hub-spoke-skeleton/`.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/az-03-02-hub-spoke
   cd /tmp/az-03-02-hub-spoke
   ```
3. Escribe los archivos:
   - `providers.tf`
   - `hub.tf` — vnet-hub + `AzureFirewallSubnet` + `GatewaySubnet` + Private DNS Zone.
   - `spoke-a.tf` — vnet-spoke-a + 1 subnet.
   - `spoke-b.tf` — vnet-spoke-b + 1 subnet.
   - `peering.tf` — 4 peerings + 3 links DNS.
   - `TOPOLOGY.md` — diagrama ASCII + explicación.
4. (Opcional) Valida offline:
   ```bash
   terraform init -backend=false
   terraform validate
   terraform fmt -check -recursive
   ```
5. Validador estructural:
   ```bash
   bash <ruta-repo>/courses/azure/03-vnet-nsg-asg-private-link-hub-spoke/activities/02-hub-spoke-tf/tests/validate.sh /tmp/az-03-02-hub-spoke
   ```
6. Compara con `../solution/`.

## Reglas duras

- **No `terraform apply`**. No hay suscripción detrás.
- **No IDs reales**. Si necesitas placeholder usa `00000000-0000-0000-0000-000000000000`.
- Español en prosa, inglés en código.

## Plantilla sugerida (`providers.tf`)

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}
```

## Pistas de CIDR

| Red | CIDR sugerido |
|-----|---------------|
| vnet-hub | `10.0.0.0/22` |
| vnet-spoke-a | `10.1.0.0/16` |
| vnet-spoke-b | `10.2.0.0/16` |

Dentro de `vnet-hub`:

| Subnet | CIDR |
|--------|------|
| AzureFirewallSubnet | `10.0.0.0/26` |
| GatewaySubnet | `10.0.0.64/27` |
| AzureBastionSubnet (opcional) | `10.0.0.96/27` |
