# Ejemplo 02 — Storage Account + Blob container privado + SAS acotada

> Lectura y analisis. Sin ejecucion. Objetivo: fijar como se declara un Storage Account minimamente serio (sin acceso publico, con TLS 1.2, HTTPS-only) y como se emite un **User Delegation SAS** acotado.

## 1. El snippet Terraform

```hcl
resource "azurerm_resource_group" "data" {
  name     = "rg-az05-storage-example"
  location = "westeurope"
}

resource "azurerm_storage_account" "sa" {
  name                     = "stgaz05example"             # nombre global, 3-24 chars, lowercase + digits
  resource_group_name      = azurerm_resource_group.data.name
  location                 = azurerm_resource_group.data.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = false              # cierra la superficie publica

  blob_properties {
    versioning_enabled       = true
    change_feed_enabled      = false
    delete_retention_policy { days = 14 }
    container_delete_retention_policy { days = 14 }
  }

  tags = {
    env        = "example"
    managed_by = "terraform"
  }
}

resource "azurerm_storage_container" "uploads" {
  name                  = "uploads"
  storage_account_id    = azurerm_storage_account.sa.id
  container_access_type = "private"                    # NUNCA blob ni container en prod
}

# Lifecycle: mover a cool tras 30 dias, archive tras 90, borrar tras 365.
resource "azurerm_storage_management_policy" "lifecycle" {
  storage_account_id = azurerm_storage_account.sa.id

  rule {
    name    = "uploads-tiering"
    enabled = true
    filters {
      prefix_match = ["uploads/"]
      blob_types   = ["blockBlob"]
    }
    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = 30
        tier_to_archive_after_days_since_modification_greater_than = 90
        delete_after_days_since_modification_greater_than          = 365
      }
    }
  }
}
```

## 2. Emision de un User Delegation SAS acotado

El SAS **nunca** se declara en Terraform: se genera **en runtime** por una Managed Identity con rol `Storage Blob Data Delegator` + `Storage Blob Data Contributor` sobre el container.

```python
# fragmento ilustrativo con azure-identity + azure-storage-blob
from datetime import datetime, timedelta, timezone
from azure.identity import DefaultAzureCredential
from azure.storage.blob import (
    BlobServiceClient, BlobSasPermissions, generate_blob_sas,
)

credential = DefaultAzureCredential()                     # Managed Identity en runtime
svc = BlobServiceClient(
    account_url="https://stgaz05example.blob.core.windows.net",
    credential=credential,
)

# 1. Obtener user delegation key firmada por Entra ID (no por account key).
now = datetime.now(timezone.utc)
udk = svc.get_user_delegation_key(now, now + timedelta(hours=1))

# 2. Generar SAS para un blob concreto, 5 minutos, solo lectura, HTTPS, IP del cliente.
sas = generate_blob_sas(
    account_name="stgaz05example",
    container_name="uploads",
    blob_name="invoices/2026-10/inv-123.pdf",
    user_delegation_key=udk,
    permission=BlobSasPermissions(read=True),             # solo r
    start=now,
    expiry=now + timedelta(minutes=5),                    # ventana corta
    protocol="https",
    ip="203.0.113.42",                                    # IP del requester
)
url = f"https://stgaz05example.blob.core.windows.net/uploads/invoices/2026-10/inv-123.pdf?{sas}"
```

## 3. Lectura clave

1. **`public_network_access_enabled = false`** + **`allow_nested_items_to_be_public = false`**: dos cerrojos distintos. El primero cierra el servicio a la red publica; el segundo prohibe hacer blobs/containers publicos aunque alguien lo intente.
2. **`min_tls_version = "TLS1_2"`** y **`https_traffic_only_enabled = true`**: higiene minima. Sin HTTPS-only, Azure acepta HTTP y expone un vector trivial.
3. **`container_access_type = "private"`**: anonymous = denegado. Toda lectura exige credencial o SAS.
4. **Soft delete y versioning**: 14 dias de recuperacion para blobs y containers. Baratos. Imprescindibles antes de aceptar un bucket "productivo".
5. **User Delegation SAS** firmado con Entra ID (no con account key) → el token esta amarrado a la identidad de quien lo emitio. Si la MI pierde el permiso, los SAS activos emitidos por ella se invalidan.
6. SAS **siempre** con `permission` minimo, `expiry` corto, `ip` cuando sea viable, `protocol=https`. Cuatro condiciones que recortan el blast radius a casi nada.

## 4. Que falta aqui

- Private Endpoint hacia el Storage Account (lo veremos en la actividad). Sin PE + public_network_access_enabled=false, nadie dentro de la VNet puede llegar al blob (no resuelve el FQDN).
- Customer-managed keys (CMK) con Key Vault — `az-06`.
- Diagnostic Settings → Log Analytics — `az-08`.

## 5. Comparativa rapida con S3

| S3 | Azure Blob |
|----|-----------|
| `BucketPolicy` + `PublicAccessBlock` | `public_network_access_enabled = false` + `allow_nested_items_to_be_public = false` |
| Presigned URL (con access key o STS) | SAS token (preferir **User Delegation SAS**) |
| Lifecycle rules | Management policies |
| Bucket versioning | `versioning_enabled = true` |
| Object Lock | Immutable Blob Storage (WORM) |
| S3 Replication | GRS / RA-GRS / GZRS replication types |
