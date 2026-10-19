# az-05 — Datos en Azure: SQL, Postgres Flexible, Cosmos DB y Storage

## Identificacion

- **ID:** `az-05-data-sql-postgres-cosmos-storage`
- **Curso:** `azure`
- **Nivel:** intermedio
- **Duracion estimada:** 4 h
- **Prerrequisitos:** `az-02` (Entra ID + RBAC + Managed Identities), `az-03` (VNet + Private Endpoints), curso **aws** >= `aws-08` (RDS, DynamoDB, S3).

## Objetivo

Mapear el **catalogo de datos administrados de Azure** a casos AWS equivalentes y aprender a **operarlos sin provisionar recursos reales**: Terraform `plan` para Azure SQL y Postgres Flexible, Postgres local en Docker para practicar DDL, y los **emuladores oficiales** de Cosmos DB y Azure Storage (Azurite) para el *data plane*.

Al terminar deberias poder:

- Justificar **Azure SQL Database** vs **Postgres Flexible Server** vs **Cosmos DB** para 3 workloads distintos.
- Dibujar la topologia de un Postgres Flexible Server con **Private Endpoint** y Managed Identity (sin pasar passwords).
- Elegir uno de los **5 niveles de consistencia** de Cosmos DB para un patron de acceso dado (strong, bounded staleness, session, consistent prefix, eventual) y argumentar el trade-off.
- Enumerar las 4 superficies de un **Storage Account** (Blob, Files, Queues, Tables) y cuando usar cada una.

## Alcance

Este modulo cubre:

- **Azure SQL Database** — SQL Server managed; **DTU vs vCore**; serverless auto-pause; **auto-failover groups**; auth con **Entra ID** en lugar de SQL login.
- **Azure Database for PostgreSQL Flexible Server** — camino actual (Single Server esta en deprecacion); zonas y HA zone-redundant; **Private Access** (delegated subnet) vs **Public Access** con firewall; parameters groups; auth Entra ID.
- **Cosmos DB** — modelo multi-API (SQL, Mongo, Cassandra, Gremlin, Table); **5 niveles de consistencia** unicos en el mercado managed; particion por `partitionKey`; RU/s como unidad de billing.
- **Azure Storage Account** — paraguas de **Blob** (equivalente S3), **Files** (SMB/NFS), **Queues**, **Tables** (NoSQL ligero); SAS tokens; tiers hot/cool/archive; **Private Endpoint** y customer-managed keys (CMK).
- **Private Endpoint** como patron por defecto para servicios PaaS de datos.
- **Mapping AWS <-> Azure**: RDS <-> Azure SQL / Postgres Flexible, DynamoDB <-> Cosmos DB, S3 <-> Blob, EFS <-> Files, SQS <-> Storage Queue / Service Bus Queue.

Lo que **no** cubre (otros modulos):

- Key Vault, Managed Identity al 100% end-to-end → `az-06`.
- Observabilidad (Azure Monitor, Log Analytics) → `az-08`.
- Backups centralizados (Azure Backup) y DR cross-region → fuera del alcance de este modulo.
- Service Bus y Event Grid (mensajeria avanzada) → fuera del alcance.

## Enfoque sin coste real

Este modulo **no provisiona recursos Azure reales**. Todo se practica con:

- **Terraform `plan`** (nunca `apply`) para Azure SQL y Postgres Flexible. Se razona sobre la topologia sin crear instancias ni pagar la hora.
- **Postgres local en contenedor** (`postgres:16`) para los ejercicios de DDL y conexion. El estudiante practica `psql`, modelo, FKs e indices sin pagar Postgres Flexible.
- **Cosmos DB Linux Emulator** (`mcr.microsoft.com/cosmosdb/linux/azure-cosmos-emulator:vnext-preview`) para el *data plane* de Cosmos: crear container, poblar items, consultar con el SDK Python. Si el emulador no esta disponible, el script marca **SKIP** limpio y no falla.
- **Azurite** (`mcr.microsoft.com/azure-storage/azurite`) para el *data plane* de Blob/Queue/Table: subir blobs, generar SAS, listar. Mismo patron de **SKIP** limpio si no esta corriendo.
- **ADR** escrita a mano para topologia Postgres Flexible y para el trade-off de consistencia en Cosmos.

Objetivo: cero facturas de Azure y practica real de las decisiones.

## Materiales

- **`theory/lesson.md`** — leccion profunda con las 4 familias de servicios de datos, el mapping con AWS y los pivotes de decision.
- **`examples/`** — tres ejemplos de lectura (no se ejecutan contra Azure):
  - `01-postgres-flexible-tf/` — snippet Terraform de Postgres Flexible Server con **Private Access** (delegated subnet), zone HA y auth Entra ID.
  - `02-storage-account-blob-sas/` — snippet Terraform de un Storage Account v2 + Blob container privado + politica de SAS token acotada (minuto + IP).
  - `03-cosmos-sql-api/` — snippet Terraform de una Cosmos DB account (SQL API) con **session** consistency y 400 RU/s compartidas.
- **`activities/`** — dos actividades **independientes**:
  - `01-connect-fastapi-to-postgres-flexible/` — auditar un `main.tf` de **Postgres Flexible + Azure SQL** (con hallazgo intencionado), ejecutar `terraform plan` sin credenciales reales, levantar `postgres:16` local, modelar un esquema OLTP y escribir un **TOPOLOGY.md** con la ADR de topologia + comparativa Azure SQL vs Postgres Flexible.
  - `02-cosmos-consistency-tradeoff/` — ejecutar un script Python contra el **Cosmos DB emulator** y **Azurite** (ambos SKIP limpio si no estan), analizar los 5 niveles de consistencia y escribir **CONSISTENCY.md** con la decision para 3 patrones de acceso + mapping DynamoDB -> Cosmos.
- **`resources/links.md`** — docs oficiales y lecturas.

## Competencias esperadas

| Dimension | Al terminar deberias |
|-----------|----------------------|
| Conceptual | Explicar los 5 niveles de consistencia de Cosmos DB con un ejemplo real; distinguir Private Endpoint de Service Endpoint; justificar Postgres Flexible sobre Single Server. |
| Operativa (sin infra) | Leer un `main.tf` de Postgres Flexible y detectar atributos de seguridad faltantes; levantar `postgres:16` local y conectar con `psql`; usar los emuladores de Cosmos y Azurite para probar codigo sin tocar Azure. |
| Arquitectonica | Elegir Azure SQL vs Postgres Flexible vs Cosmos DB para 3 workloads; mapear una tabla DynamoDB a Cosmos SQL API con eleccion de consistencia; justificar Private Endpoint para datos sensibles. |

## Criterios de evaluacion

- Dado un `main.tf` de Postgres Flexible, identifica al menos un hallazgo (public access, falta de HA, auth con password en lugar de Entra ID, etc.).
- Lee un snippet de Cosmos DB y explica que ocurre si cambias `session` por `strong` (impacto en latencia y RU).
- Justifica por que un Storage Account privado (sin acceso publico) necesita Private Endpoint y DNS zone para que la app lo resuelva.
- Mapea 3 casos de uso AWS a Azure: RDS Postgres -> Postgres Flexible, DynamoDB -> Cosmos DB SQL API, S3 -> Blob.
- Entrega las dos actividades con sus validadores estructurales en verde.

## Entregables

- **TOPOLOGY.md** con 4 secciones (hallazgos del `main.tf`, ADR Postgres Flexible, esquema SQL + indices, comparativa Azure SQL vs Postgres Flexible) — sale de la actividad `01`.
- **CONSISTENCY.md** con 4 secciones (patrones de acceso, modelo single-container Cosmos, eleccion de consistencia + hot partition, mapping DynamoDB -> Cosmos + ejecucion emuladores) — sale de la actividad `02`.

## Costos

**Ninguno.** Todo el modulo se desarrolla localmente:

- **Terraform** se usa solo con `init` + `plan` (no `apply`). El provider `azurerm` se puede inicializar sin credenciales reales; el `plan` fallara al intentar leer la subscription — ese fallo controlado basta para validar HCL.
- **Postgres** corre en Docker local (`postgres:16`).
- **Cosmos DB emulator** y **Azurite** corren en Docker local (imagenes oficiales de Microsoft). Si no estan disponibles, los scripts hacen SKIP limpio.
- **No** se requiere subscription Azure activa, ni tenant ID real, ni service principal.

Si en una fase posterior decides provisionar lo disenado:

- Postgres Flexible Server **B1ms** burstable: ~15-25 USD/mes.
- Azure SQL **Basic** DTU: ~5 USD/mes (lo mas barato, no apto prod).
- Cosmos DB **serverless**: pay-per-RU, barato para dev.
- Storage Account **LRS hot**: centavos por GB.

## Siguiente modulo

→ `az-06-key-vault-and-managed-identities-consumer` — unifica secretos/claves/certificados en Key Vault y los consume con Managed Identities, cerrando el patron "cero secretos en codigo" para los servicios de datos de este modulo.
