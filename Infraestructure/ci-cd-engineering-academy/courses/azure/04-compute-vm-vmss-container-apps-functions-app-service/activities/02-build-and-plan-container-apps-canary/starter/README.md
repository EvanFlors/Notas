# Starter — az-04-02-build-and-plan-container-apps-canary

Esta actividad es **independiente**: produces un Dockerfile + un modulo Terraform + un `main.py` minimo.

## Pasos

1. Lee `../README.md` completo y recorre `../../examples/01-fastapi-on-container-apps/` y `../../examples/02-canary-with-revisions/`.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/az-04-02/app
   cd /tmp/az-04-02
   ```
3. Escribe los 4 archivos:
   - `app/main.py` (FastAPI minimo).
   - `Dockerfile` (multistage, usuario no root, `EXPOSE 8000`).
   - `main.tf` (Container Apps + revisions + traffic split 90/10).
   - `variables.tf` (al menos `location` e `image`).
4. Verifica localmente:
   ```bash
   docker build -t az04-canary:test .
   terraform init -backend=false
   terraform validate
   ```
5. Valida:
   ```bash
   bash <ruta-repo>/courses/azure/04-compute-vm-vmss-container-apps-functions-app-service/activities/02-build-and-plan-container-apps-canary/tests/validate.sh /tmp/az-04-02
   ```
6. Compara con `../solution/` para autoevaluarte.

## Esqueleto util del `main.tf`

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

# ... resource_group, log_analytics_workspace, container_app_environment ...

resource "azurerm_container_app" "api" {
  revision_mode = "Multiple"

  identity {
    type = "SystemAssigned"
  }

  template {
    container {
      name   = "api"
      image  = var.image
      cpu    = 0.5
      memory = "1Gi"
    }
    min_replicas    = 1
    max_replicas    = 5
    revision_suffix = "v2"
  }

  ingress {
    external_enabled = true
    target_port      = 8000

    traffic_weight {
      revision_suffix = "v1"
      percentage      = 90
    }
    traffic_weight {
      revision_suffix = "v2"
      percentage      = 10
    }
  }
}
```

## Checklist mental antes de validar

- [ ] `Dockerfile` es multistage y tiene `USER` != root.
- [ ] `docker build .` termina OK.
- [ ] `terraform init -backend=false && terraform validate` termina OK.
- [ ] `revision_mode = "Multiple"`.
- [ ] Dos `traffic_weight` sumando 100.
- [ ] `identity { type = "SystemAssigned" }`.
- [ ] Sin tenant IDs reales ni secretos.
