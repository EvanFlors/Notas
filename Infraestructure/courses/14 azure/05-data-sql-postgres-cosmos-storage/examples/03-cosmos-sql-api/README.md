# Ejemplo 03 — Cosmos DB SQL API con session consistency

> Lectura y analisis. Sin ejecucion. Objetivo: fijar como se declara una Cosmos account **SQL API**, con **session** consistency, serverless, y como se modela un container con `partition_key` util.

## 1. El snippet Terraform

```hcl
resource "azurerm_resource_group" "data" {
  name     = "rg-az05-cosmos-example"
  location = "westeurope"
}

resource "azurerm_cosmosdb_account" "ex" {
  name                = "cosmos-az05-example"
  resource_group_name = azurerm_resource_group.data.name
  location            = azurerm_resource_group.data.location
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"               # SQL API

  # Serverless: pay-per-RU. Ideal dev y workloads esporadicos.
  capabilities {
    name = "EnableServerless"
  }

  consistency_policy {
    consistency_level       = "Session"                  # default sensato
    # Para bounded staleness:
    # max_interval_in_seconds = 10
    # max_staleness_prefix    = 100
  }

  geo_location {
    location          = azurerm_resource_group.data.location
    failover_priority = 0
  }

  public_network_access_enabled   = false
  is_virtual_network_filter_enabled = true

  tags = {
    env        = "example"
    managed_by = "terraform"
  }
}

resource "azurerm_cosmosdb_sql_database" "shop" {
  name                = "shop"
  resource_group_name = azurerm_resource_group.data.name
  account_name        = azurerm_cosmosdb_account.ex.name
}

resource "azurerm_cosmosdb_sql_container" "orders" {
  name                  = "orders"
  resource_group_name   = azurerm_resource_group.data.name
  account_name          = azurerm_cosmosdb_account.ex.name
  database_name         = azurerm_cosmosdb_sql_database.shop.name
  partition_key_paths   = ["/tenantId"]
  partition_key_version = 2

  indexing_policy {
    indexing_mode = "consistent"
    included_path { path = "/*" }
    excluded_path { path = "/\"_etag\"/?" }
  }
}
```

## 2. Modelo de items (patron single-container)

```jsonc
// Un USER
{
  "id": "u-123",
  "tenantId": "tenant-acme",
  "type": "user",
  "email": "ana@example.com",
  "createdAt": "2026-10-01T10:00:00Z"
}

// Una ORDER del mismo tenant → mismo partition value → query local, barato.
{
  "id": "o-1",
  "tenantId": "tenant-acme",
  "type": "order",
  "userId": "u-123",
  "status": "pending",
  "totalCents": 12000,
  "createdAt": "2026-10-16T10:00:00Z"
}

// Un ORDER_ITEM del mismo tenant.
{
  "id": "oi-1-A",
  "tenantId": "tenant-acme",
  "type": "order_item",
  "orderId": "o-1",
  "sku": "sku-A",
  "qty": 2,
  "unitPriceCents": 5000
}
```

## 3. Lectura clave

1. **`kind = "GlobalDocumentDB"`** es la etiqueta Terraform para la **SQL API** (nombre historico; no confundir con Mongo API `MongoDB` ni Cassandra `Cassandra`).
2. **`Session` consistency** es el default sensato: lees tus propias escrituras siempre; otros clientes pueden ver estado antiguo. Pasar a `Strong` multiplica RU y latencia.
3. **Serverless** elimina el min RU/s provisioned (que en el pasado era de ~400 RU/s compartidas). Para dev y traffic bajo es casi gratis.
4. **`partition_key_paths = ["/tenantId"]`**: todas las queries por `tenantId` son locales a una particion → baratas (1-5 RU) y rapidas. Queries que crucen tenants ("todos los orders globalmente") son **cross-partition** → caras.
5. **`is_virtual_network_filter_enabled = true`** + **`public_network_access_enabled = false`**: cierra la Cosmos account a la red publica. Requiere Private Endpoint o service endpoint para que la app la alcance.
6. **`partition_key_version = 2`**: version 2 soporta particiones logicas hasta 20 GiB (v1 era 10 GiB). Siempre v2 en projects nuevos.

## 4. Hot partition — mismo problema que DynamoDB

Si todo el trafico va al tenant `tenant-acme` (ej. porque es el 90% del volumen), esa particion se satura y empiezan los **429 Too Many Requests**. Mitigaciones:

- Split sintetico: `partition_key = f"{tenantId}#{shard}"`, donde `shard = hash(userId) % 10`.
- Rediseno: elegir una PK con mejor distribucion (p. ej. `userId` si los tenants son muy desiguales).

## 5. Comparativa consistency: ejemplo real

| Consistency | Caso real donde conviene |
|-------------|--------------------------|
| **Strong** | Saldo bancario leido inmediatamente despues de un deposito en multi-region. Nunca debe mostrar menos de lo depositado. Caro: todas las replicas confirman antes del commit. |
| **Bounded staleness** | Dashboard de ventas con tolerancia de 10 segundos. "Mostrame el total, puede estar 10s atrasado pero no mas". |
| **Session** (default) | Carrito de compra del usuario: cada usuario ve sus propios cambios, no le importa que otro usuario tenga un segundo de retraso. |
| **Consistent prefix** | Feed de eventos ordenados (siempre ves A antes de B si llegaron asi), pero puede faltar C. |
| **Eventual** | Contador de likes publico, aproximado. Latencia minima, RU minima. |

## 6. Costes aproximados (si se aplicase)

- **Serverless**: 0.25 USD por millon de RU + storage. Workloads de dev suelen quedar en pocos USD/mes.
- **Provisioned 400 RU/s** (minimo historico): ~24 USD/mes solo por el minimo.

**No ejecutar `apply`** en este curso.
