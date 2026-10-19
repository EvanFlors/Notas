# Solucion de referencia — az-05-02

> Es **una** solucion razonable, no la unica. Usala para autoevaluarte **despues** del intento.

## A. Patrones de acceso

1. **Patron 1 — perfil de usuario (GetItem / read_item).** Operacion: point read por `id=USER#u-123` + `partitionKey=tenant-acme`. Latencia tolerada: < 10 ms. Consistencia requerida: `session` basta — el propio usuario quiere ver sus cambios de perfil, otros tenants no se ven afectados.
2. **Patron 2 — orders de un usuario en el ultimo mes (Query).** Operacion: query SQL por `type='order' AND userId=@uid AND STARTSWITH(createdAt,'2026-10')` dentro de la particion `tenant-acme`. Latencia tolerada: < 50 ms. Consistencia: `session`.
3. **Patron 3 — items de una order (Query).** Operacion: query por `type='order_item' AND orderId=@oid` dentro de la particion del tenant. Latencia tolerada: < 50 ms. Consistencia: `session`.

Bonus: lookup global por `status=pending` cross-tenant → cross-partition query **o** composite index secundario, con proyeccion `ALL` o `INCLUDE` para evitar re-reads.

## B. Modelo single-container Cosmos

- **Partition key:** `/tenantId`. Agrupa todos los items de un tenant en la misma particion → los 3 patrones de arriba son queries locales a particion (baratas, 1-5 RU).
- **id:** convencion `TIPO#clave` → `USER#u-123`, `ORDER#o-1`, `ITEM#o-1#sku-A`, `PRODUCT#sku-A`. Es el equivalente al **SK** de DynamoDB cuando combinado con la particion.
- **GSI / composite index:** si se necesita listar por `status` cross-tenant, crear composite index sobre `/type,/status` con `projection: ALL` (equivalente a `GSI` en DynamoDB con `KEYS_ONLY` o `ALL` segun RU budget).
- **Patron 1** se resuelve con `container.read_item(id=..., partition_key=...)` → point read, 1 RU.
- **Patron 2 y 3** se resuelven con `container.query_items(query=..., partition_key=...)` → scan dentro de particion.

Modelo literal **single-container** (equivalente al single-table de DynamoDB): un unico container alberga `user`, `order`, `order_item`, `product` discriminados por `type`.

## C. Eleccion de consistencia + hot partition

### Consistency: `session`

Trade-off:

- **Latencia:** la mas baja despues de `eventual` para lecturas; writes requieren confirmacion solo del primary.
- **RU:** barata — ~1 RU por point read, ~2.3 RU por write pequeno (vs. ~2x en `strong`).
- **Correctness:** cada cliente ve sus propias escrituras siempre (read-your-writes dentro de la sesion). Otro cliente puede ver estado antiguo durante ms-segundos. Para un carrito/pedido multi-tenant esto es exactamente lo que queremos.

Pasar a **strong** multiplicaria RU por ~2x y anadiria latencia cross-region (si la cuenta estuviera distribuida). Pasar a **eventual** anadiria confusiones del tipo "cree mi order y al refrescar no la veo", lo que degrada UX.

Si fuera un workload de **saldo de banco multi-region**, elegiria `strong` sin dudar. Si fuera un **counter de likes publicos**, `eventual`.

### Hot partition

Si un tenant (`tenant-acme`) concentra el 80% del trafico, la particion de `tenant-acme` se satura y empiezan los **429 Too Many Requests**. Mitigacion con **sharding** sintetico:

```
partitionKey = "{tenantId}#{shard}"
shard = hash(userId) % 10
```

Esto reparte el trafico de un tenant pesado en 10 particiones logicas. Las queries por usuario siguen siendo locales a 1 particion (porque el shard se deriva del `userId`). Las queries "todos los orders del tenant" ahora son cross-partition sobre 10 shards → mas caro, pero sostenible.

## D. Mapping DynamoDB → Cosmos + evidencia emuladores

### Mapping

| DynamoDB | Cosmos DB SQL API | Nota |
|----------|-------------------|------|
| `PK` (hash key) | `/partitionKey` (ej. `/tenantId`) | Elegir alta cardinalidad. |
| `SK` (sort key) | Parte del `id` (`TIPO#clave#...`) | Cosmos no tiene SK nativo; se emula en `id`. |
| `GetItem` | `container.read_item(id, partition_key)` | Point read, ~1 RU. |
| `Query` | `container.query_items(query, partition_key)` | SQL-ish sobre JSON. |
| `GSI` con projection `ALL` | **Composite index** con `projection: ALL` | Projection equivalente para evitar re-reads. |
| `on-demand` | `serverless` | Pay-per-RU. |
| `provisioned` | `provisioned throughput` (RU/s) | Puede ser por container o por database. |
| DynamoDB Streams | **Change Feed** | Lee el delta de cambios. |

### Evidencia emuladores

El script `model.py` se ejecuto contra el emulador local. En el curso aws-08 el equivalente para DynamoDB era **LocalStack** (`localstack/localstack:latest` con `SERVICES=dynamodb`). Aqui usamos los emuladores oficiales de Microsoft:

- **Cosmos DB Linux Emulator** (`mcr.microsoft.com/cosmosdb/linux/azure-cosmos-emulator:vnext-preview`) — equivalente a LocalStack para Dynamo. Ambos exponen el data plane sin tocar la cloud real.
- **Azurite** (`mcr.microsoft.com/azure-storage/azurite`) — equivalente a LocalStack para S3/SQS/DynamoDB basico, pero oficial de Microsoft y mantenido como parte de las SDKs. Es materialmente mas fiel al servicio real que LocalStack free.

Extracto de `run.log` (caso OK):

```
seeded 6 items into shop/orders
Query 1: read_item(id=USER#u-123, pk=tenant-acme)
  -> user ana@example.com
...
OK: 3/3 cosmos patterns verified; blob upload OK
```

Caso SKIP (sin emuladores):

```
SKIP: Cosmos emulator not available at https://localhost:8081.
SKIP: Azurite not available at http://127.0.0.1:10000.
cosmos SKIP; azurite SKIP
```
