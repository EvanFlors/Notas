# Ejemplo 03 — DynamoDB single-table (lectura, se practica en la actividad 02)

Modelo single-table para un dominio e-commerce simple, con **una** tabla, PK/SK compuestas y un GSI para patrones secundarios.

## Terraform de la tabla

```hcl
resource "aws_dynamodb_table" "ecom" {
  name         = "ecom-single"
  billing_mode = "PAY_PER_REQUEST" # on-demand; migrar a PROVISIONED cuando se estabilice.
  hash_key     = "PK"
  range_key    = "SK"

  attribute { name = "PK"      type = "S" }
  attribute { name = "SK"      type = "S" }
  attribute { name = "GSI1PK"  type = "S" }
  attribute { name = "GSI1SK"  type = "S" }

  global_secondary_index {
    name            = "GSI1"
    hash_key        = "GSI1PK"
    range_key       = "GSI1SK"
    projection_type = "ALL" # considera KEYS_ONLY o INCLUDE para reducir WCU.
  }

  point_in_time_recovery { enabled = true }  # PITR 35 dias.
  server_side_encryption  { enabled = true } # AWS-managed KMS.

  tags = {
    Environment = "prod"
    Owner       = "platform"
  }
}
```

## Esquema de items

| PK                | SK                            | GSI1PK                  | GSI1SK          | type       | atributos propios                 |
|-------------------|-------------------------------|-------------------------|-----------------|------------|-----------------------------------|
| `USER#u-123`      | `PROFILE`                     | —                       | —               | user       | `email`, `name`                   |
| `USER#u-123`      | `ORDER#2026-10-16T10:00#o-1`  | `STATUS#pending`        | `2026-10-16#o-1`| order      | `total`, `status`                 |
| `USER#u-123`      | `ORDER#2026-10-15T09:12#o-2`  | `STATUS#shipped`        | `2026-10-15#o-2`| order      | `total`, `status`                 |
| `ORDER#o-1`       | `ITEM#sku-A`                  | —                       | —               | order_item | `qty`, `unit_price`               |
| `ORDER#o-1`       | `ITEM#sku-B`                  | —                       | —               | order_item | `qty`, `unit_price`               |
| `PRODUCT#sku-A`   | `META`                        | `CATEGORY#shoes`        | `sku-A`         | product    | `name`, `price`, `stock`          |

## Patrones de acceso que resuelve

| # | Patrón | Operación | Costo |
|---|--------|-----------|-------|
| 1 | Perfil del usuario `u-123` | `GetItem(PK=USER#u-123, SK=PROFILE)` | 0.5 RCU (eventual) o 1 RCU (strong). |
| 2 | Órdenes del usuario `u-123` en octubre 2026 | `Query(PK=USER#u-123, SK begins_with ORDER#2026-10)` | 1 RCU por 4 KB leídos. |
| 3 | Items de la orden `o-1` | `Query(PK=ORDER#o-1, SK begins_with ITEM#)` | idem. |
| 4 | Todas las órdenes `pending` | `Query(IndexName=GSI1, PK=STATUS#pending)` | lee del GSI, no de la tabla base. |
| 5 | Productos de categoría `shoes` | `Query(IndexName=GSI1, PK=CATEGORY#shoes)` | GSI1 reutilizado. |

## Trade-offs explicitados

- **Un solo GSI** sirve para dos patrones distintos (status de órdenes y categoría de productos) usando distintos prefijos en `GSI1PK`. Es el truco del single-table.
- Si llega un patrón nuevo ("órdenes por `region#status`"), evalúas: ¿cabe en GSI1 con otro prefijo? Si no, añades GSI2.
- **Alto cardinality en `PK`** → sin hot partitions. Si `PK = USER#u-123` donde `u-123` fuera un tenant con 90 % del tráfico, aplicarías write sharding: `PK = USER#u-123#<bucket>` con `bucket = hash(sk) % 10`, y las lecturas harían 10 `Query` paralelos agregando en cliente.
- **GSI con `projection_type = ALL`** proyecta todos los atributos → GSI gasta WCU por cada atributo. Para GSIs sólo-índice (buscar y luego hacer `GetItem` al original), usar `KEYS_ONLY`.

## Se practica en la actividad 02

En `activities/02-dynamodb-partition-key-design/` el estudiante implementa esta tabla en **LocalStack** (si está disponible) y ejecuta los 3 patrones con `boto3`.
