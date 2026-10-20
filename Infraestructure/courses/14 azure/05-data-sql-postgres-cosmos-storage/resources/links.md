# Recursos — az-05

Referencias oficiales y lecturas de apoyo. **Verificar en Fase 4** del curso para asegurar vigencia (consolas, nombres y pricing pueden cambiar).

## Oficiales (Microsoft Learn / Azure)

- **Azure SQL Database overview**: `https://learn.microsoft.com/azure/azure-sql/database/sql-database-paas-overview`
- **Azure SQL — purchasing models (DTU vs vCore)**: `https://learn.microsoft.com/azure/azure-sql/database/purchasing-models`
- **Azure Database for PostgreSQL — Flexible Server overview**: `https://learn.microsoft.com/azure/postgresql/flexible-server/overview`
- **Flexible Server — networking**: `https://learn.microsoft.com/azure/postgresql/flexible-server/concepts-networking`
- **Flexible Server — Entra ID authentication**: `https://learn.microsoft.com/azure/postgresql/flexible-server/concepts-azure-ad-authentication`
- **Single Server deprecation announcement**: `https://learn.microsoft.com/azure/postgresql/single-server/whats-happening-to-postgresql-single-server`
- **Cosmos DB — welcome**: `https://learn.microsoft.com/azure/cosmos-db/introduction`
- **Cosmos DB — consistency levels**: `https://learn.microsoft.com/azure/cosmos-db/consistency-levels`
- **Cosmos DB — Linux emulator (vnext-preview)**: `https://learn.microsoft.com/azure/cosmos-db/emulator-linux`
- **Cosmos DB — partitioning**: `https://learn.microsoft.com/azure/cosmos-db/partitioning-overview`
- **Storage Account overview**: `https://learn.microsoft.com/azure/storage/common/storage-account-overview`
- **Blob storage — access tiers**: `https://learn.microsoft.com/azure/storage/blobs/access-tiers-overview`
- **Shared Access Signatures (SAS) overview**: `https://learn.microsoft.com/azure/storage/common/storage-sas-overview`
- **Azurite — local emulator**: `https://learn.microsoft.com/azure/storage/common/storage-use-azurite`
- **Private Endpoint overview**: `https://learn.microsoft.com/azure/private-link/private-endpoint-overview`

## Terraform (azurerm)

- **Provider azurerm**: `https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs`
- `azurerm_postgresql_flexible_server`: `https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server`
- `azurerm_mssql_server` / `azurerm_mssql_database`: `https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/mssql_server`
- `azurerm_cosmosdb_account`: `https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cosmosdb_account`
- `azurerm_storage_account`: `https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account`
- `azurerm_private_endpoint`: `https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint`

## Emuladores (imagenes Docker)

- **Cosmos DB Linux Emulator (vnext-preview)**: `mcr.microsoft.com/cosmosdb/linux/azure-cosmos-emulator:vnext-preview`
- **Azurite**: `mcr.microsoft.com/azure-storage/azurite`
- **Postgres oficial** (para el laboratorio OLTP local): `docker.io/library/postgres:16`

## Lecturas y charlas

- Microsoft Ignite — sesiones sobre Cosmos DB consistency levels y Postgres Flexible HA (buscar edicion mas reciente).
- Blog: *Choose the right data store on Azure* (Azure Architecture Center).
- Blog: *Comparing Azure Cosmos DB and Amazon DynamoDB* (varias ediciones).

## Para el curso previo (contexto)

- Si no completaste `aws-08`, al menos lee:
  - RDS multi-AZ topology.
  - DynamoDB partition key design y hot partitions.

## Checklist de verificacion requerida en Fase 4

- Estado actual del **Cosmos DB Linux Emulator** (vnext-preview vs GA) y tag Docker vigente.
- Fecha definitiva de fin de vida de **Postgres Single Server** (ya anunciada; confirmar).
- Si **Private Endpoint para Flexible Server** ha pasado a GA en todas las regiones (estaba en rollout).
- Catalogo actualizado de tiers de Blob (`cold` paso de preview a GA recientemente).
- Si **Hyperscale (Citus) para Postgres** se mantiene como oferta separada o se ha integrado.
- Nombre vigente de **Entra ID authentication** (rebrand desde "Azure AD authentication" — docs legacy aun usan el nombre viejo).
