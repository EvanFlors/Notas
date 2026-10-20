# aws-08 — Lección: datos administrados en AWS

> 11 secciones. Prerrequisitos: `aws-03` (VPC) y `aws-06` (IAM avanzado). Prácticas con Terraform `plan`, Postgres local y LocalStack — **sin coste real** en AWS.

---

## 1. El problema que resuelven los datos administrados

Operar una base de datos en producción implica, como mínimo:

- Backups automáticos con retención, verificados por restore periódico.
- Patching del motor sin cortar al tráfico.
- Failover a una réplica cuando el nodo primario se cae.
- Monitoring de IOPS, CPU, memoria, locks, slow queries, replica lag.
- Rotación de credenciales y auditoría de accesos.

Hacer esto bien, para cada stack y cada equipo, es un trabajo de dos SREs a tiempo completo por tipo de motor. AWS vende exactamente **la externalización de ese trabajo**: tú defines "quiero Postgres 16, 2 vCPU, multi-AZ, backups 7 días" y AWS entrega la operación.

Hay tres familias:

1. **RDS** — motores clásicos (Postgres, MySQL, MariaDB, Oracle, SQL Server). El servicio administra una instancia **EC2 clásica** por debajo. Multi-AZ = una **standby sincrónica** en otra AZ.
2. **Aurora** — motor **compatible con Postgres o MySQL** reescrito por AWS. **Storage layer distribuido** entre 3 AZs, compartido por hasta 15 réplicas. Failover por **promoción** de reader (segundos). Hay variante **Serverless v2** que escala por ACUs.
3. **DynamoDB** — key-value + document, totalmente administrado, sin nodos visibles. **Pagas por operación** (RCU/WCU) o por demanda. Replicación automática entre 3 AZs. SLA 99.999 % con Global Tables.

Elegir mal es caro: **DynamoDB para una query ad-hoc con joins** mata al equipo; **RDS para un patrón key-value con 50k TPS** mata la cartera.

---

## 2. RDS: topología multi-AZ y réplicas

Una instancia RDS vive en una **subnet group** (lista de subnets privadas en ≥ 2 AZs). Cuando habilitas **multi-AZ**, AWS crea:

- Un **nodo primario** en AZ-A, que atiende lectura y escritura.
- Un **nodo standby** en AZ-B, al que el primario **replica sincrónicamente** cada commit (write confirma al cliente cuando ambos han escrito en su disco).
- Un **DNS endpoint único** (`mi-db.xyz.us-east-1.rds.amazonaws.com`) que apunta siempre al primario.

```
   App ──► endpoint CNAME ──┬──► primario (AZ-A, lectura+escritura)
                             │        │ replicación sincrónica
                             │        ▼
                             │     standby (AZ-B, no visible al tráfico)
                             │
                             └─ failover: CNAME cambia a standby (~60–120 s)
```

Puntos clave:

- **No es activo-activo.** El standby **no acepta lecturas**. Si quieres offload de lectura, necesitas **read replicas** (asincrónicas).
- **El failover es por DNS**: la aplicación debe **reintentar y re-resolver DNS** para que su pool de conexiones salte al nuevo primario. Sin reintentos, verás errores por 60–120 segundos.
- **El cliente paga 2× la instancia** (primario + standby). La ganancia es RPO ≈ 0 y RTO típico ≈ 60 s.

**Read replicas** son otra cosa:

- Replicación **asincrónica** → el reader puede ir atrás algunos ms.
- Hasta **5–15** réplicas según motor.
- Pueden estar en **otra región** (cross-region read replica) para disaster recovery y lectura cercana al cliente.
- Pueden **promoverse** a primario manualmente (rompiendo la replicación) — es la vía de DR regional.

Regla gruesa:

| Necesidad | Solución |
|-----------|----------|
| RPO cero, RTO ~1 min | multi-AZ (standby sincrónico). |
| Offload de lectura | read replicas. |
| DR en otra región | cross-region read replica + promote manual. |
| Las tres | multi-AZ + read replicas + cross-region read replica. |

---

## 3. IAM database authentication (y cuándo usarla)

RDS Postgres y MySQL soportan **IAM authentication**: en lugar de un password, el cliente pide un **token de 15 min** a STS (`rds generate-db-auth-token`) y lo usa como password en la cadena de conexión.

Flujo:

```
   App (con rol IAM) ──► STS: dame token para user=api_user
                              └─► token (15 min)
   App ──► Postgres: user=api_user password=<token> sslmode=require
```

Ventajas:

- **Sin passwords estáticos** en Secrets Manager o parameter store.
- Auditable vía CloudTrail (quién pidió qué token).
- Rotación "gratis" porque cada conexión usa un token nuevo.

Limitaciones:

- Rate limit: ~200 conexiones nuevas/segundo. **No** para pools con alto churn ni para batch que abre miles de conexiones.
- No sustituye a los passwords para accesos admin de emergencia.
- Requiere `rds-db:connect` en la policy y el usuario Postgres creado con `GRANT rds_iam TO ...`.

En la práctica, **IAM auth para apps con pool estable**; **Secrets Manager con rotación** (ver `aws-09`) para apps con mucho churn o batch jobs.

---

## 4. Backups, snapshots y PITR

RDS y Aurora tienen dos mecanismos distintos:

- **Automated backups** → snapshot diario + logs de transacción continuos. Habilita **Point-In-Time Recovery** (PITR) a cualquier segundo de la ventana de retención (1–35 días).
- **Manual snapshots** → snapshot bajo demanda, retenido hasta que lo borres. Útil para "antes del upgrade" o para compartir con otra cuenta.

Trampas que cobran:

- **La retención `0` desactiva PITR y los automated backups.** Nunca pongas `backup_retention_period = 0` fuera de dev descartable.
- **Los snapshots cross-region cuestan egress.** Un cluster de 1 TB replicado diario a otra región cuesta 1 TB × precio de egress inter-región = fácilmente > 90 USD/mes solo en transferencia.
- **Al borrar la instancia, los automated backups se borran también** salvo que marques `skip_final_snapshot = false` (y crea el final snapshot, que **sí** persiste).

Aurora añade **Backtrack** (sólo MySQL): "rebobina" el cluster a un punto anterior sin restore completo. Muy útil para "borré accidentalmente media tabla". Postgres Aurora no lo tiene.

---

## 5. Aurora: por qué el storage distribuido lo cambia todo

Aurora reescribe la capa de storage. En lugar de disco EBS local al nodo, usa un **servicio de storage distribuido** que:

- Replica cada bloque en **6 copias** entre **3 AZs** (2 por AZ).
- Confirma un write cuando **4 de 6** copias han persistido (quórum).
- Los **compute nodes** (hasta 15 por cluster) comparten el mismo storage; cada reader lee del storage directamente, no del primario.

Consecuencias prácticas:

- **Failover rapidísimo** (10–30 s): no hay que replicar datos al promover; sólo apuntar el endpoint a un reader existente.
- **Lectura escalable**: añadir un reader = añadir compute, no copiar datos. Diez readers comparten el mismo storage sin impacto en el primario.
- **Backup "gratis"**: el storage ya está versionado; backups continuos no cuestan IOPS extra en el primario.
- **Precio**: la instancia Aurora cuesta ~20 % más que RDS equivalente, y pagas storage por GB usado + I/O. Para workloads con mucho I/O, puede acabar más caro que RDS; para la mayoría de OLTP, más barato por ganancia operativa.

### Aurora Serverless v2

En lugar de instancia fija, defines un rango **mínimo-máximo de ACUs** (Aurora Capacity Units; 1 ACU ≈ 2 GB RAM + CPU proporcional). El cluster escala arriba y abajo en segundos, por **saltos de 0.5 ACU**.

Cuándo encaja:

- Carga **impredecible o espiky** (dev/staging, backoffice interno, SaaS multi-tenant con tenants que duermen).
- Equipos sin DBA que no quieren "elegir el tamaño correcto".

Cuándo **no**:

- Carga constante alta → sale más caro que una instancia reservada.
- Latencia predecible bajo picos abruptos: el escalado tarda 1–2 segundos, suficiente para timeouts en algunas apps sensibles.

### Aurora Global Database

Replica un cluster entre regiones con lag **< 1 segundo** típico (replicación por storage, no por binlog). Pensada para:

- Lectura cercana al cliente global.
- DR regional con RTO < 1 min y RPO < 1 s.
- Secondary region puede promoverse en < 1 min a primario independiente.

Es la opción cara pero correcta cuando el negocio no tolera la caída de una región entera.

---

## 6. DynamoDB: el modelo que cambia la decisión

DynamoDB **no es Postgres sin joins**. Es un servicio diferente con reglas diferentes:

- **No hay esquema fijo** por item (sólo PK/SK son obligatorios).
- **No hay joins ni `GROUP BY`.** Agregaciones las haces en Streams + Lambda o en el cliente.
- **Pagas por operación**: cada read consume **RCU** (1 RCU = 1 strong-consistent read de ítem ≤ 4 KB/s), cada write consume **WCU** (1 WCU = 1 write ≤ 1 KB/s). O eliges **on-demand** y pagas por request a precio ~5× el provisioned.
- **La clave de partición define el rendimiento.** Es la decisión arquitectónica más importante.

### Partition key, sort key, GSI, LSI

Cada ítem tiene:

- **Partition key (PK)** — obligatoria. Determina la **partición física** (shard) donde vive el ítem.
- **Sort key (SK)** — opcional. Permite tener varios ítems con la misma PK, ordenados por SK, y hacer `Query` con `begins_with`, `between`, etc.

Operaciones básicas:

- `GetItem(PK, SK)` — una sola fila. Fast O(1).
- `Query(PK, SK condition)` — todos los ítems de una partición, filtrados por rango de SK. Fast.
- `Scan(table)` — recorre **toda la tabla**. Lento, caro, **evitar**. Si lo necesitas, es señal de que el modelo está mal.

Para patrones de acceso que **no** van por la PK natural, dos opciones:

- **GSI (Global Secondary Index)** — tabla "espejo" con otra PK/SK, replicada asíncronamente. Soporta reads eventual-consistent (strong consistent sólo si está en la misma región que el ítem original — detalle de implementación). Hasta **20 GSIs** por tabla. Cuesta WCU extra en cada write (se escribe también al GSI).
- **LSI (Local Secondary Index)** — mismo PK, otra SK. Debe crearse **al crear la tabla**. Máximo 5. Comparte capacidad con la tabla base. Hoy casi nadie los usa; se prefieren GSI.

### On-demand vs provisioned

- **Provisioned**: declaras N RCUs/WCUs; pagas por lo declarado 24/7, independiente de uso. Más barato si el uso es predecible y > 20 % de la capacidad.
- **On-demand**: pagas por request, sin declarar nada. ~5× más caro por request, pero no pagas por capacidad ociosa. Mejor para carga impredecible, picos o cuando no sabes aún.

Regla práctica: **empezar on-demand**, medir 2 semanas, migrar a provisioned con Auto Scaling si la carga es predecible.

### Hot partitions y write sharding

DynamoDB garantiza throughput **por partición**, no por tabla entera. Si tu PK es `user_id` y un user concentra el 80 % del tráfico, esa partición satura y **el resto de la tabla es irrelevante**.

Mitigación: **write sharding**. En lugar de `PK = user_id`, usa `PK = user_id#<bucket>` donde `bucket` ∈ `[0..N-1]` elegido random o por timestamp. Las lecturas hacen N queries (una por bucket) y agregan en cliente.

---

## 7. El patrón single-table de DynamoDB

En Postgres modelas una entidad por tabla: `users`, `orders`, `order_items`. En DynamoDB bien hecho modelas **todas las entidades en una sola tabla** con PK/SK compuestas que **codifican el patrón de acceso**.

Ejemplo e-commerce simple:

| PK                | SK                       | type       | atributos específicos             |
|-------------------|--------------------------|------------|-----------------------------------|
| `USER#u-123`      | `PROFILE`                | user       | email, name, created_at           |
| `USER#u-123`      | `ORDER#2026-10-16#o-1`   | order      | total, status                     |
| `USER#u-123`      | `ORDER#2026-10-15#o-2`   | order      | total, status                     |
| `ORDER#o-1`       | `ITEM#sku-A`             | order_item | qty, unit_price                   |
| `ORDER#o-1`       | `ITEM#sku-B`             | order_item | qty, unit_price                   |
| `PRODUCT#sku-A`   | `META`                   | product    | name, price, stock                |

Patrones de acceso que esto resuelve en **una** `Query` cada uno:

- "Perfil del usuario u-123" → `GetItem(PK=USER#u-123, SK=PROFILE)`.
- "Órdenes del usuario u-123 en octubre 2026, ordenadas por fecha" → `Query(PK=USER#u-123, SK begins_with ORDER#2026-10)`.
- "Items de la orden o-1" → `Query(PK=ORDER#o-1, SK begins_with ITEM#)`.

Para patrones nuevos ("todas las órdenes con status=pending del día"), añades un GSI con `GSI1PK = STATUS#pending#2026-10-16`, `GSI1SK = ORDER#o-xxx`.

El trade-off: tu esquema **codifica los patrones de acceso**. Si llega un patrón nuevo que no previste, hay que **añadir un GSI** o migrar datos. Por eso DynamoDB brilla cuando los patrones son **conocidos y estables**; sufre cuando el equipo analítico quiere "una query ad-hoc".

---

## 8. Conexión segura: Security Groups, endpoints y egress

### RDS/Aurora

Checklist mínimo:

- Subnet group con **subnets privadas** en ≥ 2 AZs. Nunca subnets públicas.
- Security Group de la DB: **inbound** permite `5432` (Postgres) o `3306` (MySQL) **sólo desde el SG de la app**, no desde `0.0.0.0/0` ni desde el CIDR de la VPC entera.
- `publicly_accessible = false` en Terraform. Si está en `true`, AWS asigna IP pública y la DB es alcanzable desde internet (sigue filtrada por SG, pero expone la superficie).
- `storage_encrypted = true` con KMS (ver `aws-09`).
- `deletion_protection = true` en prod.
- `skip_final_snapshot = false` → fuerza snapshot final antes de borrar.

### DynamoDB

- Es un **servicio regional**, no vive en tu VPC. Por defecto el tráfico sale por el **endpoint público de DynamoDB** usando IAM auth.
- Si tu app corre en subnet privada, cada llamada a DynamoDB sale por NAT → **cuesta egress + horas NAT**. Para workloads de alto volumen, esto es la factura #1 inesperada.
- Solución: **Gateway VPC Endpoint** para DynamoDB (gratis, igual que el de S3). Ruta a DynamoDB sin NAT.
- IAM policy para la app: `dynamodb:Query`, `dynamodb:PutItem`, `dynamodb:GetItem` **limitado al ARN de la tabla**, no `*`.

---

## 9. Criterios de elección: RDS vs Aurora vs DynamoDB

Preguntas rápidas para orientar:

| Pregunta | Si "sí" → inclinación |
|----------|-----------------------|
| ¿Necesitas Postgres/MySQL con drivers, extensiones, lenguaje SQL rico, joins arbitrarios? | RDS o Aurora. |
| ¿La carga es espiky, impredecible, o el equipo no quiere dimensionar? | Aurora Serverless v2. |
| ¿Necesitas > 5 read replicas o replica cross-region con lag < 1 s? | Aurora. |
| ¿Vas a tener > 10k TPS sostenidos con patrón key-value simple? | DynamoDB. |
| ¿Esperas picos de 100× la carga normal durante segundos? | DynamoDB on-demand o Aurora Serverless v2. |
| ¿El equipo analítico quiere queries ad-hoc con `JOIN` y `GROUP BY`? | RDS/Aurora (o replicar a Redshift/Athena). |
| ¿Presupuesto operativo cero, nadie va a monitorear nada? | DynamoDB (menos palancas que ajustar). |
| ¿Necesitas MVCC, transacciones multi-tabla ACID complejas? | RDS/Aurora. |
| ¿La latencia debe estar bajo 10 ms p99 **garantizada**? | DynamoDB (SLA explícito). |

Tres escenarios canónicos:

- **OLTP transaccional pequeño** (CRM interno, 50 users, 100 req/s pico): **RDS Postgres single-AZ** si es dev/stg, **multi-AZ** en prod. Serverless v2 no se justifica.
- **SaaS multi-tenant con tráfico impredecible por tenant**: **Aurora Serverless v2 Postgres**. Escala por tenant sin tener que dimensionar peor caso de cada uno.
- **Catálogo de productos con 10k TPS lookup por SKU y 100 writes/s**: **DynamoDB on-demand** con PK = `PRODUCT#<sku>`. Añade DAX si la p99 debe estar bajo 1 ms.

---

## 10. Costos ocultos (los que cobran de más)

Patrones que cobran sin que lo notes:

- **NAT Gateway por tráfico a DynamoDB** en subnet privada → fácilmente 50–200 USD/mes extra. Fix: Gateway endpoint.
- **Egress inter-AZ en Aurora** cuando el reader está en otra AZ que la app → 0.01 USD/GB inter-AZ, parece poco hasta que mueves TBs al mes. Fix: driver consciente de AZ (Aurora reader endpoint hace round-robin, no AZ-aware).
- **Snapshots cross-region** → egress + storage en región destino.
- **Backups retention 35 días** vs 7 días → 5× storage de snapshots. En Aurora clusters grandes se nota.
- **GSIs mal diseñados** → cada write se replica al GSI → **duplica WCU**. 3 GSIs = 4× el write cost (base + 3).
- **DynamoDB on-demand olvidado** cuando la carga se estabilizó → 5× el costo de provisioned equivalente.
- **Multi-AZ activado en staging** → paga 2× sin ganancia real. Dev/stg suelen tolerar single-AZ.
- **Performance Insights long retention** (en RDS) → cuesta extra tras los 7 días gratis.

Regla: revisar **Cost Explorer** filtrado por servicio **cada mes** los primeros 3 meses tras lanzar.

---

## 11. Qué sigue

Al terminar este módulo deberías poder:

- Leer un `terraform plan` de RDS y detectar lo que falta (encryption, deletion protection, SG abierto).
- Dibujar la topología multi-AZ de RDS vs Aurora en una pizarra.
- Diseñar una tabla DynamoDB single-table para 3 patrones de acceso y defender la PK/SK.
- Argumentar on-demand vs provisioned y cuándo migrar.
- Estimar la factura mensual aproximada de un workload dado en los tres motores.

Lo que **sigue**:

- `aws-09` — KMS, Secrets Manager, Parameter Store. **La rotación automática del password de RDS vía Secrets Manager** se construye encima de este módulo.
- `aws-12` — Observabilidad: CloudWatch metrics para RDS (CPUUtilization, DatabaseConnections, ReplicaLag), Performance Insights, CloudWatch alarmas útiles.
- `aws-14` — Serverless: DynamoDB Streams → Lambda para patrones event-driven (por ejemplo, mantener un índice derivado o enviar notificaciones).
- `aws-17` — AWS Backup para gestión centralizada de backups cross-service y cross-region.

Síntesis en una línea:

> **RDS para Postgres/MySQL con operación clásica; Aurora cuando necesitas storage distribuido, escalado de lectura o Serverless; DynamoDB cuando el patrón es key-value conocido, el tráfico es alto y predecible por partición, y el equipo acepta diseñar el esquema para el patrón de acceso, no para la query ad-hoc.**
