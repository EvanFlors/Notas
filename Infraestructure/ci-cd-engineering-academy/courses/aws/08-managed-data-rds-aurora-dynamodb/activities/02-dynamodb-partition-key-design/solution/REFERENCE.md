# REFERENCE — aws-08-02-dynamodb-partition-key-design

> Referencia razonada. No es la única solución correcta.

## A — Patrones de acceso

| # | Patrón | Operación | Expresión |
|---|--------|-----------|-----------|
| 1 | Perfil del usuario `u-123` | `GetItem` | `PK=USER#u-123, SK=PROFILE` |
| 2 | Órdenes del usuario `u-123` en octubre 2026, ordenadas DESC | `Query` (tabla base) | `PK=USER#u-123, SK begins_with "ORDER#2026-10"`, `ScanIndexForward=False` para DESC |
| 3 | Items de la orden `o-1` | `Query` (tabla base) | `PK=ORDER#o-1, SK begins_with "ITEM#"` |
| 4 (GSI) | Órdenes con `status=pending` | `Query` (GSI1) | `IndexName=GSI1, GSI1PK=STATUS#pending` |
| 5 (GSI) | Productos de categoría `shoes` | `Query` (GSI1) | `IndexName=GSI1, GSI1PK=CATEGORY#shoes` |

Observaciones:

- Las 3 primeras resuelven en **1 Query** cada una. Ningún `Scan`.
- Las dos GSI reusan la misma estructura `GSI1PK/GSI1SK` con prefijos distintos (`STATUS#` vs `CATEGORY#`).

## B — Modelo single-table

| PK                | SK                                | GSI1PK             | GSI1SK            | type       | atributos                 |
|-------------------|-----------------------------------|--------------------|-------------------|------------|---------------------------|
| `USER#u-123`      | `PROFILE`                         | —                  | —                 | user       | email, name               |
| `USER#u-123`      | `ORDER#2026-10-16T10:00#o-1`      | `STATUS#pending`   | `2026-10-16#o-1`  | order      | total_cents, status       |
| `USER#u-123`      | `ORDER#2026-10-15T09:12#o-2`      | `STATUS#shipped`   | `2026-10-15#o-2`  | order      | total_cents, status       |
| `ORDER#o-1`       | `ITEM#sku-A`                      | —                  | —                 | order_item | qty, unit_price_cents     |
| `ORDER#o-1`       | `ITEM#sku-B`                      | —                  | —                 | order_item | qty, unit_price_cents     |
| `PRODUCT#sku-A`   | `META`                            | `CATEGORY#shoes`   | `sku-A`           | product    | name, price_cents         |

Por qué conviven en una sola tabla:

- Los **prefijos en PK** (`USER#`, `ORDER#`, `PRODUCT#`) particionan el keyspace de forma clara.
- Los **prefijos en SK** permiten `begins_with` para colecciones mixtas en la misma partición (perfil + órdenes del mismo user).
- Un **único GSI1** sirve a 2 patrones secundarios distintos.

`projection_type = ALL` elegido porque los patrones secundarios devuelven todos los atributos de la orden/producto. Si sólo necesitara el ID y luego hacer `GetItem`, `KEYS_ONLY` ahorraría WCU.

## C — Hot partition y write sharding

**Escenario**: un tenant SaaS (`USER#tenant-pro`) concentra el 80 % del tráfico. La partición de `USER#tenant-pro` satura su cuota de WCU/RCU; el resto de usuarios ven throttling a pesar de que la tabla globalmente está infrautilizada.

**Fix: write sharding**

- Nueva PK: `USER#tenant-pro#<bucket>` con `bucket ∈ [0..9]`.
- Al escribir: elige `bucket = hash(order_id) % 10` → distribuye uniforme.
- Al leer "todas las órdenes del user": haces **10 queries en paralelo**, una por bucket, y agregas los resultados en el cliente.
- Si necesitas orden global por fecha, haces merge en cliente (los 10 streams ya vienen ordenados por SK).

**Trade-offs**:

- Lectura: 10× RCU por operación "get all orders" (10 queries). Latencia agregada = latencia máxima de las 10 (si paralelas).
- Escritura: igual que antes (1 PutItem).
- Operación: código del cliente más complejo (fan-out).

Elección sensata: `N` igual al factor de concentración esperado (si un user tiene 10× el tráfico medio, `N = 10` es suficiente; `N = 100` sobredistribuye y encarece lecturas).

## D — Resultado de la ejecución

Salida esperada (con LocalStack):

```
Creating table ecom-single...
  seeded 6 items

Query 1: GetItem(PK=USER#u-123, SK=PROFILE)
  -> {'PK': 'USER#u-123', 'SK': 'PROFILE', 'type': 'user', 'email': 'ana@example.com', ...}

Query 2: Query(PK=USER#u-123, SK begins_with ORDER#2026-10)
  -> ORDER#2026-10-15T09:12#o-2 status=shipped total=3000
  -> ORDER#2026-10-16T10:00#o-1 status=pending total=12000

Query 3: Query(PK=ORDER#o-1, SK begins_with ITEM#)
  -> ITEM#sku-A qty=2 unit=5000
  -> ITEM#sku-B qty=1 unit=2000

Query (GSI1): orders with status=pending
  -> ORDER#2026-10-16T10:00#o-1 total=12000

OK: 3/3 access patterns verified
```

Sin LocalStack:

```
SKIP: LocalStack not available at http://localhost:4566.
      Start it with: docker run -d -p 4566:4566 -e SERVICES=dynamodb localstack/localstack:latest
```

En ambos casos exit 0. SKIP no es fallo — es la señal de que el pipeline no tiene LocalStack disponible y evitamos crear coste en AWS real.
