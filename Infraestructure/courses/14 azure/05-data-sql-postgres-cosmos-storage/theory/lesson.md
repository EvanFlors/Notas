# Leccion — Datos administrados en Azure: SQL, Postgres Flexible, Cosmos DB y Storage

> Esta leccion asume el curso **aws-08** completado. El objetivo aqui es **mapear** y entender **las divergencias de Azure**, no re-aprender fundamentos de bases relacionales ni NoSQL.

---

## 1. El catalogo de datos de Azure, de un vistazo

Azure separa los servicios de datos en 4 familias:

| Familia | Servicios principales | Equivalente AWS |
|---------|----------------------|-----------------|
| Relacional managed | **Azure SQL Database**, **Azure SQL Managed Instance**, **Azure Database for PostgreSQL Flexible Server**, **Azure Database for MySQL Flexible Server** | RDS (motores clasicos), Aurora |
| NoSQL multi-modelo | **Azure Cosmos DB** (APIs: SQL, Mongo, Cassandra, Gremlin, Table) | DynamoDB, DocumentDB, Keyspaces, Neptune |
| Object / file / queue | **Azure Storage Account** (Blob, Files, Queues, Tables) | S3, EFS/FSx, SQS, DynamoDB (table ligera) |
| Cache y analytics | Azure Cache for Redis, Synapse, Databricks, Fabric | ElastiCache, Redshift, EMR |

Esta leccion se centra en las 3 primeras familias (la cuarta se trata en modulos posteriores o fuera del curso).

---

## 2. Azure SQL Database

### 2.1 Que es

**Azure SQL Database** es SQL Server administrado por Microsoft. No tienes acceso al sistema operativo ni al motor; configuras el *tier* y Azure se ocupa del resto.

Dos modelos de compra:

- **DTU** (Database Transaction Unit): bundle fijo de CPU + RAM + IO. Tiers Basic/Standard/Premium. Util cuando no quieres pensar en dimensionamiento.
- **vCore**: eliges cores, RAM, generacion de hardware. Da acceso a **serverless** (auto-pause tras N minutos sin trafico — ideal dev/stg) y a **Hyperscale** (storage hasta 100 TB, replicas rapidas).

### 2.2 Topologia alta disponibilidad

- Dentro de una region: SQL Database replica sincronamente a 3 nodos *locally redundant* por defecto. Fallo de nodo = failover transparente en segundos.
- **Zone-redundant** (opcional, Premium/BusinessCritical): replicas en 3 **Availability Zones** distintas.
- **Auto-failover groups**: replica asincrona a otra region con DNS endpoint unico. Failover manual o automatico.

### 2.3 Auth

Preferir siempre **Entra ID authentication** (antes "Azure AD authentication") sobre SQL login clasico:

- La app usa su Managed Identity → obtiene token OAuth → se conecta sin password.
- `GRANT` se hace sobre grupos de Entra ID, no sobre users SQL individuales.

El SQL login clasico (`sa` + password) sigue existiendo pero es el equivalente de "root + password en el .env": **no usar en prod**.

### 2.4 Red

- Por defecto el server tiene endpoint publico (`<name>.database.windows.net`) con firewall por IP.
- **Private Endpoint** da una IP privada dentro de tu VNet. Combinado con "Public Network Access = Disabled" eliminas la superficie publica.
- Alternativa legacy: **Service Endpoints** (abren el servicio a toda una subnet, mas groseros). Preferir Private Endpoint.

---

## 3. Azure Database for PostgreSQL Flexible Server

### 3.1 Flexible vs Single

**Postgres Single Server** esta en **deprecacion** (fin de vida anunciado). **Siempre** elegir **Flexible Server** para proyectos nuevos.

Diferencias clave que importan:

| Aspecto | Single Server | Flexible Server |
|---------|---------------|-----------------|
| HA | Gen2 unica | **Zone-redundant HA** (standby en otra AZ) |
| Red | Public o VNet rule | **Public** o **Private Access** (delegated subnet) |
| Mantenimiento | Ventana forzada por Azure | Ventana custom |
| Burstable (B-series) | No | **Si** (B1ms, B2s) |
| Price per minute | No | Si |

### 3.2 Modelos de red

- **Public access**: endpoint publico + firewall por IP. Simple, no apto para prod.
- **Private access**: el server vive **dentro** de una subnet **delegada** a `Microsoft.DBforPostgreSQL/flexibleServers`. No hay IP publica. Se accede via DNS privado (`<name>.privatelink.postgres.database.azure.com`).
- **Private Endpoint** (en preview/GA segun version): da IP privada en subnet separada al servidor con public access. Un poco redundante si ya usas private access.

### 3.3 Auth

Tres modos:

1. **Password** (admin + password al crear el server). Como SQL login: no para prod.
2. **Entra ID authentication** (preferido): la app usa Managed Identity, obtiene token, lo pasa como password al driver. El `GRANT` se hace sobre grupos de Entra ID.
3. **Mixto**: ambos habilitados. Util en migraciones.

### 3.4 Decision rapida

- Workload OLTP tipico, equipo que ya sabe Postgres: **Flexible Server**.
- Workload que necesita SQL Server, T-SQL, SSMS: **Azure SQL Database**.
- Workload con legacy Oracle/Sybase/SQL Server on-prem y necesita migrar sin reescribir: **Azure SQL Managed Instance** (fuera del alcance de este modulo, pero recuerdalo).

---

## 4. Cosmos DB

### 4.1 Que lo hace distinto

Cosmos DB es la apuesta NoSQL de Azure. Dos cosas lo diferencian materialmente:

1. **Multi-API**: la misma infraestructura hospeda APIs distintas (SQL/document, Mongo wire protocol, Cassandra, Gremlin graph, Table). Eliges el API al crear la account y no se cambia luego.
2. **5 niveles de consistencia**: unico managed del mercado que ofrece este espectro ajustable globalmente.

### 4.2 Los 5 niveles de consistencia

De mas fuerte a mas debil:

1. **Strong**: linearizable. Lectura siempre ve la ultima escritura committed. Mas caro en RU, mas latente en multi-region (el write espera a replicas remotas).
2. **Bounded staleness**: lecturas pueden ver escrituras antiguas, pero el *lag* esta **acotado** (ej. "no mas de K operaciones" o "no mas de T segundos"). Util cuando quieres eventual consistency *con limite*.
3. **Session** (default): consistency dentro de la sesion del cliente. "Mis propias escrituras siempre las veo"; otras sesiones pueden ver estado antiguo. Es el default y suele ser lo correcto.
4. **Consistent prefix**: nunca ves escrituras fuera de orden (si llegaron A, B, C nunca ves A, C sin B), pero puedes ver estado antiguo. Util para feeds.
5. **Eventual**: minima garantia. Las replicas convergen pero sin orden ni limite. Maximo throughput y minima latencia.

Esta decision aplica **globalmente** a toda la account; se puede *relajar* por operacion (nunca endurecer).

### 4.3 Particion y RUs

- Cada container define una **partition key** (ej. `/tenantId`, `/userId`). Cosmos distribuye items en particiones logicas por hash de esa key.
- **Hot partition**: todo el trafico va a un solo valor de partition key → saturacion y 429s. Mismo problema que DynamoDB.
- Billing en **RU/s** (Request Units per second): un GetItem ~1 RU, un query mas segun scan. Dos modos:
  - **Provisioned** (manual): dimensionas RU/s por container o compartidas por database.
  - **Serverless**: pay-per-RU. Ideal dev y workloads esporadicos.
  - **Autoscale**: provisioned con rango min/max.

### 4.4 Elegir SQL API vs otras

- **SQL (NoSQL) API**: default moderno. Query language similar a SQL sobre JSON. Es el que recomendamos por defecto.
- **Mongo API**: migraciones desde MongoDB con minimo cambio.
- **Cassandra API**: migraciones desde Cassandra.
- **Table API**: migraciones desde Azure Storage Tables (ligero, cheap).
- **Gremlin**: grafos.

### 4.5 Red

Mismo patron: endpoint publico por defecto; Private Endpoint para eliminarlo.

---

## 5. Azure Storage Account

Un **Storage Account** es un *paraguas* que hospeda 4 servicios bajo un recurso:

| Servicio | Que es | Equivalente AWS |
|----------|--------|-----------------|
| **Blob** | Object storage (hot/cool/cold/archive tiers; versioning; soft delete; lifecycle). | S3 |
| **Files** | SMB/NFS filesystem managed. | EFS / FSx for Windows |
| **Queues** | Message queue sencilla (push + poll). | SQS |
| **Tables** | NoSQL ligero (PK/RK + propiedades). | DynamoDB (uso basico) |

Un Storage Account tiene **nombre global** (DNS: `<name>.blob.core.windows.net`); no puedes repetir el nombre con nadie en Azure.

### 5.1 Blob

- Tiers: **hot** (acceso frecuente), **cool** (poco frecuente), **cold** (menos aun, GA reciente), **archive** (rehydrate en horas).
- **Lifecycle management**: reglas tipo "mover a cool tras 30 dias, archive tras 90, borrar tras 365".
- **Versioning** + **soft delete**: recuperacion de blobs borrados.

### 5.2 SAS tokens

**Shared Access Signatures**: URLs firmadas temporales. Siempre acotar:

- `sr`: resource (b = blob, c = container).
- `sp`: permissions (r/w/d/l).
- `st` / `se`: start / expiry (**pocos minutos**).
- `sip`: IP range (opcional pero recomendado).
- `spr`: protocolo (`https`).

**Preferir User Delegation SAS** (firmada con credenciales de Entra ID + Managed Identity) sobre Account Key SAS. La Account Key es un secreto compartido equivalente a un root token.

### 5.3 Private Endpoint

Como el resto: pone IP privada en tu VNet; combinado con "Public Network Access = Disabled" cierra la superficie publica.

### 5.4 Azurite — emulador local

**Azurite** es el emulador oficial de Microsoft para desarrollo local. Soporta Blob, Queue y Table. Se usa en este modulo con la imagen `mcr.microsoft.com/azure-storage/azurite` y evita pagar Storage Account real para desarrollo.

---

## 6. Private Endpoint vs Service Endpoint

| Aspecto | Service Endpoint | Private Endpoint |
|---------|-----------------|------------------|
| Que hace | Extiende la identidad VNet al servicio PaaS (el servicio *sabe* que vienes de esa subnet). | Da IP privada en tu VNet al servicio PaaS. |
| Trafico | Sale a la red publica Azure, pero el servicio permite solo tu VNet. | Nunca sale a la red publica. |
| Granularidad | Por subnet. | Por recurso (una storage account, una Cosmos DB account). |
| Cross-region | No. | Si (via VNet peering). |
| Recomendacion | Legacy. | **Default moderno.** |

En este curso usamos **Private Endpoint** siempre que el servicio lo soporte.

---

## 7. Mapping AWS <-> Azure

| AWS | Azure | Nota |
|-----|-------|------|
| RDS Postgres | Azure Database for PostgreSQL **Flexible Server** | NO Single Server (deprecado). |
| RDS SQL Server | Azure SQL Database o Managed Instance | SQL Database para apps nuevas; Managed Instance para migrar on-prem. |
| Aurora Serverless v2 | Azure SQL Database serverless | Modelo similar (auto-pause, auto-scale). |
| DynamoDB | Cosmos DB **SQL API** | Elegir consistency explicitamente. |
| DocumentDB | Cosmos DB **Mongo API** | Compatible wire. |
| ElastiCache Redis | Azure Cache for Redis | Equivalente directo. |
| S3 | Azure Blob Storage | Lifecycle, versioning, SAS tokens. |
| EFS | Azure Files (NFS) | SMB tambien soportado. |
| SQS | Azure Storage Queue o Service Bus Queue | Storage Queue = SQS Standard; Service Bus = SQS FIFO + mas features. |
| SNS | Azure Event Grid o Service Bus Topic | Event Grid para eventos; Service Bus Topic para pub/sub con sesiones. |

---

## 8. Checklist de decision rapida

**Debo elegir motor de datos para un workload nuevo. Que uso?**

1. **Necesito transacciones ACID y modelo relacional estable?** → Postgres Flexible (default) o Azure SQL (si el equipo viene de SQL Server).
2. **Necesito escalar horizontalmente con PK + consistency ajustable?** → Cosmos DB SQL API.
3. **Necesito almacenar blobs grandes (imagenes, backups, datasets)?** → Blob Storage.
4. **Necesito queue sencilla pay-per-use?** → Storage Queue (barato) o Service Bus (features avanzadas).
5. **Necesito cache in-memory?** → Azure Cache for Redis (fuera de este modulo).

**En red siempre:**

- Private Endpoint + `Public Network Access = Disabled` en prod.
- Entra ID auth + Managed Identity en el consumidor.
- Secretos (solo si inevitable) en Key Vault.

---

## 9. Que NO cubre esta leccion

- Backups centralizados (Azure Backup, cross-region restore). → fuera del alcance.
- Observabilidad (Azure Monitor, Diagnostic Settings a Log Analytics). → `az-08`.
- Secrets lifecycle completo con Key Vault. → `az-06`.
- Service Bus y Event Grid detallados. → fuera del alcance de este curso.
- Synapse / Fabric / Databricks (analytics). → fuera del alcance.

---

## 10. Preguntas de autoevaluacion

1. Cual es la diferencia entre **Postgres Single Server** y **Postgres Flexible Server** y por que elegimos Flexible por defecto?
2. En Cosmos DB, si cambias de **session** a **strong** consistency, que impacto esperas en latencia y en RU consumidas?
3. Que es un **User Delegation SAS** y por que es mas seguro que un Account Key SAS?
4. Por que un Storage Account con "Public Network Access = Disabled" necesita Private Endpoint **y** DNS zone privada para que una app lo resuelva correctamente?
5. Mapea estos 4 casos a Azure: (a) catalogo de productos con lookups por PK < 10ms global, (b) base OLTP de pedidos con transacciones, (c) backups de BD exportados en gzip, (d) notas de voz pending transcripcion con consumer unico. Elige el servicio y justifica.

Las respuestas se trabajan en las dos actividades de este modulo.
