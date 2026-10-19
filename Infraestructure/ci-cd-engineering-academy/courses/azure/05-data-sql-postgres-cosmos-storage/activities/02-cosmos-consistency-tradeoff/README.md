# az-05-02 — Cosmos DB consistency trade-off + emulador + Azurite

> **Duracion:** ~75 min.
> **Tipo:** independent (modelas, decides, ejecutas emuladores locales si estan disponibles).
> **Coste real:** 0 USD. **Nada** se ejecuta contra Azure.

## 1. Contexto

Vas a modelar la capa de datos de la API de pedidos (`checkout`) **multi-tenant** usando **Cosmos DB SQL API** y a decidir que **nivel de consistencia** eligir. En paralelo, probaras la emision de un blob privado en **Azurite** (el emulador local de Azure Storage) porque el equipo quiere subir facturas PDF al mismo workload.

Objetivo doble:

1. Decidir con criterio uno de los 5 niveles de consistencia de Cosmos y argumentar el trade-off.
2. Correr un smoke local con el **Cosmos DB Linux Emulator** y con **Azurite** — y si no estan disponibles, hacer un **SKIP limpio**, no falla.

## 2. Objetivos de aprendizaje

- Modelar un container Cosmos single-container con `partitionKey` util para 3 patrones.
- Comparar los 5 niveles de consistencia con un caso real cada uno.
- Detectar y mitigar hot partitions con sharding sintetico.
- Hacer mapping DynamoDB → Cosmos para la misma logica de dominio.
- Usar los emuladores oficiales de Microsoft como sustitutos de produccion para dev local.

## 3. Preparacion

```bash
mkdir -p /tmp/az-05-cosmos
cp starter/model.py /tmp/az-05-cosmos/model.py
cd /tmp/az-05-cosmos
```

(Opcional) Levantar los emuladores:

```bash
# Cosmos DB Linux emulator (preview). Puede tardar 1-2 min en estar ready.
docker run -d --name az05-cosmos \
  -p 8081:8081 -p 10250-10255:10250-10255 \
  mcr.microsoft.com/cosmosdb/linux/azure-cosmos-emulator:vnext-preview

# Azurite (Blob + Queue + Table).
docker run -d --name az05-azurite \
  -p 10000:10000 -p 10001:10001 -p 10002:10002 \
  mcr.microsoft.com/azure-storage/azurite
```

Si no quieres (o no puedes) levantarlos, el script detecta la ausencia y marca **SKIP** limpio (exit 0 con mensaje).

## 4. Paso 1 — Ejecutar el smoke local

```bash
cd /tmp/az-05-cosmos
python3 model.py | tee run.log
```

Esperado:

- Si **Cosmos emulator** y **Azurite** estan arriba: el script crea container, siembra 6 items, corre 3 queries (seccion A patrones) y sube un blob privado via Azurite. Al final: `OK: 3/3 cosmos patterns verified; blob upload OK`.
- Si uno o los dos no estan arriba: el script imprime `SKIP: Cosmos emulator not available ...` y/o `SKIP: Azurite not available ...` y sale 0.

Sea cual sea el resultado, `run.log` debe quedar en el directorio.

## 5. Paso 2 — Escribir `CONSISTENCY.md`

Crea `/tmp/az-05-cosmos/CONSISTENCY.md` con **4 secciones** (A, B, C, D):

### A. Patrones de acceso (minimo 3, usar la palabra `Patron`)

Describe al menos 3 patrones del dominio e-commerce. Para cada uno indica: operacion (GetItem/Query), filtros, latencia tolerada, consistencia requerida. Sugerencias:

1. `Patron 1`: ver perfil de un usuario por `userId` (GetItem).
2. `Patron 2`: listar las orders de un usuario del ultimo mes (Query por `userId` + rango de `createdAt`).
3. `Patron 3`: listar los items de una order concreta (Query por `orderId`).

### B. Modelo single-container Cosmos

Define `partitionKey` (ej. `/tenantId`), diseno de `id` por tipo (`USER#u-123`, `ORDER#o-1`), y como cada patron se resuelve con un `point read` o un `query`. Debe mencionar `PK`, `SK`, `GSI` o `single-container` / `single-table`, `query` y `GetItem` / `get_item`, y `projection` o uno de `KEYS_ONLY`/`ALL`/`INCLUDE` para el caso Dynamodb-equivalente.

### C. Eleccion de consistencia + hot partition

Elige **uno** de los 5 niveles (`strong`, `bounded staleness`, `session`, `consistent prefix`, `eventual`). Justifica el **trade-off** latencia vs RU vs correctness para este workload. Luego explica en que caso tu `partitionKey` crearia un **hot partition** y propon un **sharding** sintetico (`{tenantId}#{shard}`).

### D. Mapping DynamoDB → Cosmos + ejecucion emuladores

Tabla de equivalencias (`PK`/`SK` DynamoDB vs `id`/`partitionKey` Cosmos; `GSI` vs `composite index`; `on-demand` vs `serverless`; etc.). Al final cita `LocalStack` (del curso aws) comparandolo con el `Cosmos emulator` y con `Azurite`. Pega las lineas clave de `run.log` como evidencia de la ejecucion (OK o SKIP, ambos validos).

## 6. Paso 3 — Validar

```bash
bash tests/validate.sh /tmp/az-05-cosmos
```

Debe terminar con `OK: estructura valida`.

## 7. Limpieza

```bash
docker rm -f az05-cosmos az05-azurite 2>/dev/null || true
rm -rf /tmp/az-05-cosmos
```

## 8. Que se evalua

- 3 patrones descritos de forma concreta.
- Modelo single-container coherente (una PK, items multiples por tipo).
- Decision de consistencia **argumentada** (no "porque si").
- Hot partition identificada y mitigada con sharding.
- Mapping DynamoDB → Cosmos razonado.
- `run.log` presente, con OK o con SKIP (ambos aceptables).
- Validador estructural en verde.

## 9. Solucion de referencia

`solution/REFERENCE.md` tras intentarlo.
