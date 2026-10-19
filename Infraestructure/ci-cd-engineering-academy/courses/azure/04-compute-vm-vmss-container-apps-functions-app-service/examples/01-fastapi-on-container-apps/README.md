# Ejemplo 01 — FastAPI en Container Apps

> Lectura y analisis. **No** se ejecuta contra una suscripcion real. El objetivo es que leas una receta minima completa y entiendas que recurso crea cada bloque.

## 1. El `main.tf`

```hcl
terraform {
  required_version = ">= 1.5.0"
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

variable "location" {
  type    = string
  default = "westeurope"
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-fastapi-demo"
  location = var.location
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-fastapi-demo"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "env" {
  name                       = "cae-fastapi-demo"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
}

resource "azurerm_container_app" "api" {
  name                         = "ca-fastapi"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  identity {
    type = "SystemAssigned"
  }

  template {
    container {
      name   = "api"
      image  = "ghcr.io/example/fastapi-demo:v1"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "LOG_LEVEL"
        value = "info"
      }
    }

    min_replicas = 0
    max_replicas = 5

    http_scale_rule {
      name                = "http-concurrency"
      concurrent_requests = 50
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8000
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}

output "fqdn" {
  value = azurerm_container_app.api.ingress[0].fqdn
}
```

## 2. Lectura clave

1. **`azurerm_container_app_environment`** es la frontera. Un environment puede alojar N apps y define el VNet (opcional), los limites de red y el workspace de Log Analytics donde se escriben logs/`stdout`.
2. **`revision_mode = "Single"`** es el default: solo una revision recibe trafico. Para canary debes cambiarlo a `"Multiple"` (ver ejemplo 02).
3. **`identity { type = "SystemAssigned" }`** crea una Managed Identity del sistema. Esta identity se usa para pullear la imagen desde ACR (con `AcrPull` role) y para leer secretos de Key Vault.
4. **`http_scale_rule.concurrent_requests = 50`** significa: por cada 50 requests concurrentes, levanta una replica mas. Con `min_replicas = 0` el app duerme en reposo.
5. **`ingress.external_enabled = true`** expone el app con FQDN publico (`{name}.{randomsuffix}.{region}.azurecontainerapps.io`) y cert gestionado. Para interno, `external_enabled = false`.
6. **`traffic_weight.latest_revision = true`** envia 100% a la ultima revision; implica que al aplicar un nuevo `template.container.image`, el trafico migra automaticamente — util en dev, peligroso en prod.

## 3. Fundamentos internos

- Container Apps gestiona por debajo un AKS. Tu nunca ves los nodos ni los pods. El `template.container` se convierte internamente en un Deployment, el `ingress` en un Service + Ingress, y el `scale_rule` en un **KEDA ScaledObject**.
- La imagen se pullea cada vez que arranca una replica desde cero (scale-from-zero). Imagenes grandes = cold start grande. Mantener la imagen <200MB es una buena regla.
- Los env vars simples (`env { name, value }`) viven en texto plano en el ARM template. Para secretos usa `secret` + `env { name, secret_name }`.

## 4. Que no muestra este ejemplo

- Private ingress + Private Endpoint (requiere environment con `infrastructure_subnet_id`).
- Secrets de Key Vault (ver `az-06`).
- Canary (ver ejemplo 02).
- Instrumentacion App Insights (ver `az-08`).

## 5. Mapeo con AWS

| Container Apps | AWS equivalente |
|-----------------|------------------|
| Environment | Cluster ECS |
| Container App | Service ECS + Task Definition + Target Group |
| Revision | Task Definition revision |
| `http_scale_rule` | Target Tracking Scaling Policy (RequestCountPerTarget) |
| Ingress external | ALB publico |
| Managed Identity | Task Role (IAM Role) |
