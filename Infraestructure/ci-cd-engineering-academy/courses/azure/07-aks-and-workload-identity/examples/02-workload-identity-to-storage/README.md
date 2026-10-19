# Example 02 — Workload Identity leyendo un blob de Storage

> **Lectura y análisis.** Snippet anotado. En la actividad 02 adaptarás esto a tu propio workload.

## Escenario

Un pod `app` en el namespace `apps` necesita **leer** objetos de `https://staz07demo.blob.core.windows.net/data/*` sin ningún secreto montado.

Piezas:

1. Cluster AKS con `oidc_issuer_enabled = true` + `workload_identity_enabled = true` (del ejemplo 01).
2. **User-Assigned MI** `mi-az07-app`.
3. **Federated identity credential** sobre esa MI que confía en el issuer OIDC del cluster para el subject `system:serviceaccount:apps:app`.
4. **Role assignment** `Storage Blob Data Reader` sobre el storage account.
5. **ServiceAccount K8s** `app` en `apps`, anotado con el `clientId` de la MI.
6. **Deployment** con label `azure.workload.identity/use: "true"` + `serviceAccountName: app`.

## Terraform (extracto)

```hcl
# Supongamos que ya existen azurerm_kubernetes_cluster.this, azurerm_resource_group.this.

resource "azurerm_user_assigned_identity" "app" {
  name                = "mi-az07-app"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
}

resource "azurerm_federated_identity_credential" "app" {
  name                = "fic-app-apps-ns"
  resource_group_name = azurerm_resource_group.this.name
  parent_id           = azurerm_user_assigned_identity.app.id

  audience = ["api://AzureADTokenExchange"]
  issuer   = azurerm_kubernetes_cluster.this.oidc_issuer_url
  subject  = "system:serviceaccount:apps:app"
}

# Storage account y role assignment minimo
resource "azurerm_storage_account" "data" {
  name                     = "staz07demodata"
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_role_assignment" "app_blob_reader" {
  scope                = azurerm_storage_account.data.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}
```

## Manifiestos Kubernetes

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: apps
  labels:
    azure.workload.identity/use: "true"
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app
  namespace: apps
  annotations:
    # client_id de la MI mi-az07-app. En real: azurerm_user_assigned_identity.app.client_id.
    azure.workload.identity/client-id: "33333333-3333-3333-3333-333333333333"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  namespace: apps
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app
  template:
    metadata:
      labels:
        app: app
        # Label critico: activa el webhook de Workload Identity para este pod.
        azure.workload.identity/use: "true"
    spec:
      serviceAccountName: app
      containers:
        - name: app
          image: mcr.microsoft.com/azure-cli:latest
          command:
            - /bin/sh
            - -c
            - |
              set -eu
              # Variables inyectadas por el webhook:
              #   AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_FEDERATED_TOKEN_FILE,
              #   AZURE_AUTHORITY_HOST.
              az login --service-principal \
                --username "$AZURE_CLIENT_ID" \
                --tenant   "$AZURE_TENANT_ID" \
                --federated-token "$(cat $AZURE_FEDERATED_TOKEN_FILE)"
              az storage blob list \
                --account-name staz07demodata \
                --container-name data \
                --auth-mode login \
                --output table
              sleep 3600
```

## Qué pasa en runtime (resumen)

1. El webhook `azure-workload-identity` ve el label en el pod y proyecta un token del `ServiceAccount` en `/var/run/secrets/azure/tokens/azure-identity-token`.
2. El contenedor lanza `az login` con `--federated-token`.
3. Entra verifica el token: el `issuer` del token (OIDC del cluster) y el `sub` (`system:serviceaccount:apps:app`) coinciden con la federated identity credential de `mi-az07-app`.
4. Entra devuelve un access token para la MI `mi-az07-app`.
5. `az storage blob list` llama al Storage; Azure RBAC evalúa `Storage Blob Data Reader` sobre el account → `200 OK`.

Ningún secreto se persiste en el cluster. La única "credencial" en el pod es el projected token, que caduca y se renueva automáticamente.

## Debug típico

| Síntoma | Causa habitual |
|---------|----------------|
| `AADSTS70021: No matching federated identity record found` | `subject` del `federated_identity_credential` no coincide con `system:serviceaccount:<ns>:<sa>`. |
| `azure.identity.CredentialUnavailableError: WorkloadIdentity ... environment variable not set` | Falta el label `azure.workload.identity/use: "true"` en el pod → webhook no inyectó variables. |
| `403 AuthorizationPermissionMismatch` sobre blobs | Falta el role assignment `Storage Blob Data Reader` sobre el storage account (lo tienes a nivel RG pero no de account, o viceversa). |
| `AADSTS700016: Application with identifier ... not found` | La MI fue borrada o no está en el mismo tenant que el cluster. |
