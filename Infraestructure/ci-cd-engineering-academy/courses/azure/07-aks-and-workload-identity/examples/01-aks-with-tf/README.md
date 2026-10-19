# Example 01 — AKS con Terraform (`azurerm_kubernetes_cluster`)

> **Lectura y análisis.** Este snippet NO se ejecuta: provisionaría un AKS real con coste de VMs. Léelo, cópialo a la actividad 01 y adáptalo.

## Objetivo

Ver el "skeleton" mínimo defendible de un AKS 2026:

- Control plane en tier Free (ajustable a Standard).
- System node pool en 3 zonas, con `only_critical_addons_enabled`.
- Un user node pool con cluster-autoscaler habilitado.
- **Azure CNI Overlay** + Cilium network policy.
- **OIDC issuer + Workload Identity** habilitados (foundation para la actividad 02).
- **Entra ID + Azure RBAC for Kubernetes** como único mecanismo de auth humano.
- Add-ons: Container Insights, App Routing, Key Vault CSI secrets provider.
- Cluster identity: User-Assigned Managed Identity (reusable).

## `main.tf` anotado

```hcl
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
  }
}

provider "azurerm" {
  features {}
  # IDs ficticios — en real vienen de un `az account show` tras login.
  subscription_id = "00000000-0000-0000-0000-000000000000"
  tenant_id       = "11111111-1111-1111-1111-111111111111"
}

resource "azurerm_resource_group" "this" {
  name     = "rg-az07-demo"
  location = "westeurope"
}

# Identidad del cluster: UA-MI (reusable, independiente del ciclo de vida del cluster).
resource "azurerm_user_assigned_identity" "aks" {
  name                = "mi-az07-aks"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
}

# Log Analytics para Container Insights.
resource "azurerm_log_analytics_workspace" "this" {
  name                = "la-az07-demo"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = "aks-az07-demo"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  dns_prefix          = "az07demo"
  kubernetes_version  = "1.30"
  sku_tier            = "Free" # cambiar a "Standard" (0.10 USD/h) para SLA 99.95.

  # ---- OIDC + Workload Identity (foundation de la actividad 02) --------
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # ---- Identidad y RBAC ------------------------------------------------
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  azure_active_directory_role_based_access_control {
    admin_group_object_ids = [
      # Entra group object ID — ficticio. En real: `az ad group show --group aks-admins -o tsv --query id`.
      "22222222-2222-2222-2222-222222222222",
    ]
    azure_rbac_enabled = true
  }
  local_account_disabled = true  # cero kubeconfig con secrets locales.

  # ---- Networking ------------------------------------------------------
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    pod_cidr            = "10.244.0.0/16"
    service_cidr        = "10.0.0.0/16"
    dns_service_ip      = "10.0.0.10"
  }

  # ---- System node pool (obligatorio) ----------------------------------
  default_node_pool {
    name                         = "system"
    vm_size                      = "Standard_D2s_v5"
    zones                        = ["1", "2", "3"]
    only_critical_addons_enabled = true
    auto_scaling_enabled         = true
    min_count                    = 3
    max_count                    = 5
    node_labels = {
      "role" = "system"
    }
  }

  # ---- Add-ons ---------------------------------------------------------
  oms_agent {
    log_analytics_workspace_id      = azurerm_log_analytics_workspace.this.id
    msi_auth_for_monitoring_enabled = true
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  web_app_routing {
    dns_zone_ids = [] # vacio: usa el FQDN del LB. Si tienes azure_dns_zone, pasa su id.
  }
}

# ---- User node pool "apps" (donde corren tus workloads) ----------------
resource "azurerm_kubernetes_cluster_node_pool" "apps" {
  name                  = "apps"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = "Standard_D4s_v5"
  zones                 = ["1", "2", "3"]
  auto_scaling_enabled  = true
  min_count             = 2
  max_count             = 8
  mode                  = "User"
  node_labels = {
    "role" = "apps"
  }
}
```

## Qué validar sin provisionar

```bash
cd /tmp/az-07-example-01
terraform init -backend=false
terraform validate   # Success! The configuration is valid.
terraform plan       # requiere credenciales Azure; omitir en labs offline.
```

`terraform validate` **no** necesita credenciales (no habla con Azure). Suficiente para verificar HCL y referencias de providers.

## Lo que este ejemplo NO cubre

- La **federated identity credential** por workload (eso va en el ejemplo 02).
- Las role assignments concretas sobre la MI del cluster (`AcrPull` sobre un ACR, p. ej.).
- `ingress_application_gateway` (AGIC) ni `monitor_metrics` (Prometheus managed) — flags extra que puedes añadir.
- Networking privado (`private_cluster_enabled = true`) y el Private DNS zone que exige.
