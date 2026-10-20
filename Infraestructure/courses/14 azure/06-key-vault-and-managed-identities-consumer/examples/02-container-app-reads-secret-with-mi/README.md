# Ejemplo 02 — Container App que lee un secret con Managed Identity

> Walkthrough. Sin ejecución. Objetivo: ver de punta a punta cómo un Container App obtiene un secret sin que el valor aparezca nunca en Terraform ni en app settings.

## 1. Topología

```
┌─────────────────────────┐          ┌─────────────────────────┐
│  Container App Env      │          │   Key Vault              │
│  (managed K8s abstract) │          │   kv-capstone-dev        │
│                         │          │   RBAC data-plane        │
│   ┌───────────────────┐ │   token  │                          │
│   │ Container App     │ │─────────▶│  secret: db-connection   │
│   │ ca-capstone       │ │          │  value: <opaco>          │
│   │                   │ │          │                          │
│   │ identity:         │ │          │                          │
│   │ UserAssigned ─────┼─┼──────────┤  role_assignment:        │
│   │ id-capstone-api   │ │          │  Key Vault Secrets User  │
│   └───────────────────┘ │          │  principal_id=id-capst.. │
└─────────────────────────┘          └─────────────────────────┘
```

## 2. HCL completo (plan-ready, no se aplica)

```hcl
resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-capstone"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "main" {
  name                       = "cae-capstone"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
}

resource "azurerm_container_app" "api" {
  name                         = "ca-capstone"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  secret {
    name                = "db-connection-string"
    identity            = azurerm_user_assigned_identity.app.id
    key_vault_secret_id = azurerm_key_vault_secret.db_conn.versionless_id
  }

  ingress {
    external_enabled = true
    target_port      = 8000
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 1
    max_replicas = 3

    container {
      name   = "api"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name        = "DB_CONN"
        secret_name = "db-connection-string"
      }
    }
  }
}
```

## 3. Flujo de arranque, paso a paso

1. **Container App inicia**. Antes de arrancar el contenedor, el runtime de Container Apps lee el `secret` block.
2. Reconoce que el `secret` tiene `key_vault_secret_id` + `identity`. Por tanto no es un valor literal: hay que resolverlo contra Key Vault.
3. Usa la User-Assigned MI (`id-capstone-api`) para pedir un **token** a Entra ID con audience `https://vault.azure.net`.
4. Con ese token hace `GET https://kv-capstone-dev.vault.azure.net/secrets/db-connection-string?api-version=7.4`.
5. Key Vault evalúa RBAC: ¿`principal_id` de la MI tiene `Key Vault Secrets User` sobre este vault? **Sí** → devuelve el valor.
6. El runtime inyecta el valor en `DB_CONN` **solo** en el entorno del proceso del contenedor.
7. El código de la app lee `os.environ["DB_CONN"]` como siempre.

## 4. Qué se audita y dónde

- **Activity Log del Key Vault**: entrada por cada `SecretGet`, con `callerIpAddress = <IP de la MI>` y `identity.claims.oid = <principal_id>`.
- **Activity Log del Container App**: `Microsoft.App/containerApps/write` cuando se cambia la configuración, pero **no** cuando lee el secret (eso lo ve el vault).
- **Logs del contenedor** (via Log Analytics): nada del secret. Si la app lo imprime, aparece — es responsabilidad del dev no imprimirlo.

## 5. Rotación sin re-deploy

Como el `secret.key_vault_secret_id` usa `versionless_id`:

1. Subes una versión nueva del secret: `az keyvault secret set --vault-name kv-capstone-dev --name db-connection-string --value "<nuevo>"`.
2. La Container App no se entera hasta que:
   - creas una **revisión nueva** (p. ej. deploy); o
   - reinicias el contenedor manualmente.

Si quieres rotación **en caliente** sin reinicio, la app debe implementar polling o enganchar un Event Grid handler que la reconfigure. Para 99% de workloads, el ciclo "rotación → nueva revisión en el siguiente deploy" es suficiente.

## 6. Qué cambia si fuera App Service en lugar de Container Apps

El principio es idéntico; la sintaxis cambia:

```hcl
resource "azurerm_linux_web_app" "api" {
  # ...
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  app_settings = {
    DB_CONN = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.db_conn.versionless_id})"
  }

  key_vault_reference_identity_id = azurerm_user_assigned_identity.app.id
}
```

La magia la hace la referencia `@Microsoft.KeyVault(SecretUri=...)` + `key_vault_reference_identity_id`. El resto (role assignment, MI, vault) es idéntico.

## 7. Preguntas de autocomprobación

1. Si borras el `role_assignment`, ¿la Container App se cae inmediatamente o solo al siguiente restart?
2. ¿Qué pasa si cambias `versionless_id` por `id` (versión pinneada) y luego rotas el secret?
3. ¿Qué entrada aparece en el Activity Log del vault cuando el token es rechazado por falta de RBAC?
4. Si olvidas `key_vault_reference_identity_id` en App Service, ¿qué identity intenta usar por defecto?
5. ¿Cómo probarías el flujo de arranque sin desplegar nada? (pista: `az rest` + token obtenido con `az account get-access-token --resource vault.azure.net`).
