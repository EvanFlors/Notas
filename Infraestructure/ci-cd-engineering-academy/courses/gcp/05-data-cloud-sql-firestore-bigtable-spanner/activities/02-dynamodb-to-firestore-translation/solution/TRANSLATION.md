# TRANSLATION.md — events-tracker: DynamoDB -> Firestore (+ Bigtable)

## Resumen

La tabla DynamoDB `events-tracker` mezcla dos dominios con perfiles de carga **radicalmente distintos**:

- `USER` + `USER_ORDER`: datos de aplicacion, tamaño moderado, QPS bajo, consultas por entidad. **Firestore Native** es el mapeo natural.
- `METRIC_POINT`: telemetria de alto throughput (1–5 K writes/s sostenidos). **Bigtable** es la unica eleccion sensata; Firestore lo soportaria tecnicamente pero el coste por write escala peor y la forma de la query (`last N by time per entity`) encaja perfectamente con un prefijo `metric#device#` + reverse timestamp.

En resumen: **1 tabla DynamoDB -> 2 motores GCP**. Esto es tipico cuando se migra single-table design.

## Mapeo por patron

| # | Patron DynamoDB | Motor GCP | Justificacion |
|---|-----------------|-----------|---------------|
| 1 | Get user by uid (PK=`USER#<uid>`, SK=`#META`) | Firestore | Lectura por document reference `users/{uid}`. O(1), 1 doc. |
| 2 | List users by country (GSI1 `COUNTRY#<cc>`) | Firestore | Query sobre coleccion `users` con `where("country","==",cc)` + indice compuesto. |
| 3 | List orders of user desc by date | Firestore | Subcoleccion `users/{uid}/orders` con `orderBy("created_at","desc")`. |
| 4 | List paid orders of user | Firestore | Mismo + `where("status","==","paid")`. Requiere indice compuesto. |
| 5 | List last N metric points per (metric, device) | **Bigtable** | Prefix scan sobre row key `metric#device#<reverse_ts>`; p99 < 10 ms a escala. |
| 6 | Write 1–5 K metric points/s sostenido | **Bigtable** | Escrituras distribuidas por device evitan hotspot; Firestore llegaria pero con coste y limites de 1 write/s/doc. |

## Modelado Firestore

Diseño de **colecciones y subcolecciones**:

```
users (coleccion)
└── {uid} (documento)
    ├── name, email, country, created_at (campos)
    └── orders (subcoleccion)
        └── {order_id} (documento)
            └── amount, status, created_at
```

Decisiones:

- `country` es campo plano del documento `users/{uid}` -> permite filtrar sin duplicar.
- `orders` **subcoleccion** (no array embebido) para no explotar el documento padre y permitir pagination.
- No se replica un indice "COUNTRY#" como coleccion extra: en Firestore el filtro `where` + indice compuesto reemplaza al GSI1 de DynamoDB.
- En DynamoDB un GSI es managed; en Firestore el equivalente es el indice compuesto declarado via Terraform/`firebase.json`. Donde en DynamoDB tendrias **dos ways de leer** (base + GSI), en Firestore tienes **la misma coleccion** con otro indice al servicio de otra query.

## Donde Bigtable gana

Patrones 5 y 6 (`METRIC_POINT`) son **series temporales de alto volumen** con la query dominante "ultimos N puntos por entidad". Diseño:

- Tabla `metrics`, column family `v`, column qualifier `val`.
- **Row key**: `metric#device#<reverse_ts>` donde `reverse_ts = MAX_INT64 - unix_ts_micros`.
- Razones:
  - El prefijo `metric#device#` distribuye las escrituras entre tablets por device: **no hay hotspot** aunque todos los devices escriban al mismo tiempo. Un diseño ingenuo con prefijo `20261019T...` **crea un hotspot** porque todas las writes del minuto cae en el ultimo tablet.
  - Al invertir el timestamp, "ultimos N puntos" es un **scan ascendente del prefijo** con `limit=N` — latencia proporcional a N, no al tamaño total.

Firestore seria incorrecto aqui por 3 motivos:
1. Limite practico de ~1 write/s por documento (hay que shardear artificialmente).
2. Coste por operacion escala linealmente con QPS; a 5 K writes/s el billing sube rapido.
3. No hay prefix scan nativo; cada query cuesta documentos leidos.

## Indices compuestos

Firestore necesita indices compuestos declarados **explicitamente** para queries con `where` + `orderBy` sobre campos distintos. En Terraform:

```hcl
resource "google_firestore_index" "orders_by_date_desc" {
  project    = "example-project-id"
  collection = "orders"
  fields { field_path = "created_at"; order = "DESCENDING" }
  fields { field_path = "__name__";   order = "DESCENDING" }
}

resource "google_firestore_index" "orders_paid_by_date" {
  project    = "example-project-id"
  collection = "orders"
  fields { field_path = "status";     order = "ASCENDING" }
  fields { field_path = "created_at"; order = "DESCENDING" }
}
```

Lista textual (los dos indices compuestos minimos):

1. Indice **composite** sobre `orders` con campos `(created_at DESC)` — para patron 3.
2. Indice **compuesto** sobre `orders` con campos `(status ASC, created_at DESC)` — para patron 4.

Si se añadiera "paid orders in country X", haria falta un indice adicional sobre la coleccion raiz `users` o un modelado reverso.

## Limites del emulador

Esto es clave para no engañarnos probando local:

- El **Firestore emulator** no valida indices compuestos: las queries del patron 4 **pasarian en emulador** aunque no declares el indice; en produccion fallarian con `FAILED_PRECONDITION`. Por eso los indices deben declararse en Terraform y revisarse en PR.
- No hay IAM real en los emuladores — pruebas de permisos deben hacerse contra Firestore real en un project sandbox, no en local.
- El **Bigtable emulator** es single-node, in-memory: no mide latencia ni garbage collection; util para contratos de API y modelado de row key, no para capacity planning.
- El **Spanner emulator** no da TrueTime real ni multi-region; util para esquema, no para SLO.

En consecuencia: emuladores sirven para **validar la forma de los datos y de las queries**, no para validar politicas, latencia o costes.
