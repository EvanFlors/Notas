# aws-08 — Datos administrados: RDS, Aurora y DynamoDB

## Identificación

- **ID:** `aws-08-managed-data-rds-aurora-dynamodb`
- **Curso:** `aws`
- **Nivel:** intermedio
- **Duración estimada:** 5 h
- **Prerrequisitos:** `aws-03` (VPC) y `aws-06` (IAM avanzado). Opcional: curso **terraform** Nivel 1–2 para el ejemplo RDS en `tf`.

## Objetivo

Entender **cuándo elegir** cada motor administrado de AWS para datos — **RDS** (motores clásicos), **Aurora** (storage distribuido compatible con Postgres/MySQL) y **DynamoDB** (key-value NoSQL) — y aprender a **operarlos sin reinventar la operación**: topología multi-AZ, auth IAM, backups, costos de egress, diseño de clave de partición y de GSI.

Al terminar deberías poder:

- Justificar RDS vs Aurora vs DynamoDB para 3 workloads distintos.
- Dibujar la topología multi-AZ de un RDS Postgres y explicar por qué el failover sincrónico tarda segundos (no es activo-activo).
- Diseñar la **clave de partición** de una tabla DynamoDB para un patrón de acceso dado y evitar hot partitions.
- Enumerar los costos ocultos: NAT para connect pool, backups cross-region, egress inter-AZ en Aurora reader.

## Alcance

Este módulo cubre:

- **RDS** — instancia, **multi-AZ** (standby sincrónico), **read replicas** (asincrónicas), backups automáticos, snapshots manuales, parameter groups, option groups, **IAM database authentication**, Enhanced Monitoring, Performance Insights.
- **Aurora** — arquitectura con **storage layer compartido** entre hasta 15 réplicas, failover ≤ 30 s por promoción de reader, **Serverless v2** (ACUs, auto-scaling por carga), Global Database (réplica cross-region), Backtrack (sólo MySQL).
- **DynamoDB** — modelo **key-value + document**, **partition key** y **sort key**, **GSI** (índice secundario global) vs **LSI** (local), **on-demand** vs **provisioned** (RCU/WCU), **DAX** (cache in-memory), **Streams** + Lambda triggers, **PITR** (Point-in-Time Recovery).
- **Patrón single-table** en DynamoDB: una sola tabla modelando varios tipos de entidad con PK/SK compuestas (`USER#123` / `ORDER#2026-10-16#abc`).
- **Conexión segura**: Security Group mínimo (puerto 5432 sólo desde el SG de la app), VPC endpoints Gateway para DynamoDB, IAM auth cuando aplique.

Lo que **no** cubre (otros módulos):

- KMS, Secrets Manager, rotación automática → `aws-09`.
- Backups centralizados con AWS Backup → `aws-17`.
- Observabilidad RDS/DynamoDB con CloudWatch + Performance Insights → `aws-12`.
- Migración desde on-prem (DMS, SCT) → fuera del alcance del programa.

## Enfoque sin coste real

Este módulo **no provisiona recursos AWS reales**. Todo se practica con:

- **Terraform `plan`** (nunca `apply`) para los ejemplos de RDS y Aurora. Se razona sobre la topología sin crear instancias.
- **Postgres local en contenedor** (`postgres:16`) para los ejercicios de modelo de datos y conexión. El estudiante practica `psql`, DDL y connection pooling sin pagar RDS.
- **LocalStack** (si está disponible) para el **data plane** de DynamoDB: crear tabla, poblar ítems, consultar con `boto3`, probar GSI. Si LocalStack no está instalado, la actividad lo marca como **SKIP** con mensaje claro, no falla.
- **ADR de topología** escrito a mano para RDS/Aurora: el estudiante justifica multi-AZ vs single-AZ, read replicas, Serverless v2.

Objetivo: cero facturas de AWS y práctica real de las decisiones.

## Materiales

- **`theory/lesson.md`** — lección profunda con 11 secciones.
- **`examples/`** — tres ejemplos de lectura (no se ejecutan contra AWS):
  - `01-rds-postgres-multi-az-tf/` — snippet Terraform de RDS Postgres multi-AZ con SG, subnet group, parameter group, IAM auth. Comentado para que se vea `terraform plan` sin `apply`.
  - `02-aurora-serverless-v2/` — snippet Terraform de Aurora Postgres Serverless v2 con rango de ACUs.
  - `03-dynamodb-single-table/` — tabla single-table con PK/SK y un GSI, con ejemplos de ítems para 3 patrones de acceso.
- **`activities/`** — dos actividades independientes:
  - `01-provision-rds-and-connect/` — leer un `main.tf` de RDS, ejecutar `terraform plan` sin credenciales reales (plan-only), levantar un `postgres:16` local, modelar un esquema OLTP y escribir un **TOPOLOGY.md** con la justificación de multi-AZ y la ADR.
  - `02-dynamodb-partition-key-design/` — diseñar PK/SK para 3 patrones de acceso de un dominio e-commerce, implementar en LocalStack (o SKIP) con `boto3`, verificar queries y escribir un **ACCESS_PATTERNS.md** con el modelo single-table.
- **`resources/links.md`** — docs oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar storage compartido de Aurora vs multi-AZ de RDS. Nombrar los 4 estados típicos de un failover. Distinguir on-demand vs provisioned en DynamoDB. |
| Operativa (sin infra real) | Leer un `terraform plan` de RDS y detectar un SG abierto a `0.0.0.0/0`. Modelar DynamoDB single-table para 3 patrones de acceso. Conectar `psql` a Postgres local y crear esquema con FKs e índices razonables. |
| Arquitectónica | Elegir RDS vs Aurora vs DynamoDB para 3 workloads (OLTP transaccional pequeño, OLTP con picos impredecibles, catalog con 10k TPS clave-valor) y defender con costo y disponibilidad. |

## Criterios de evaluación

- Diferencia RDS multi-AZ (standby sincrónico, 1 AZ espera) de Aurora (storage compartido entre 3 AZs, cualquier reader puede promoverse) con palabras propias.
- Dado un patrón de acceso ("buscar todas las órdenes de un usuario, ordenadas por fecha"), propone una PK/SK y, si hace falta, un GSI, y explica por qué no sirve `scan`.
- Argumenta por qué una PK como `user_id` puede ser un hot partition si 1 user concentra el 80 % del tráfico, y propone un `write-sharding` (`user_id#bucket`).
- Entrega las dos actividades con validadores estructurales en verde.

## Entregables

- `TOPOLOGY.md` con la ADR de RDS multi-AZ (sale de la actividad 01).
- `ACCESS_PATTERNS.md` con el modelo single-table DynamoDB (sale de la actividad 02).
- Esquema SQL en Postgres local funcional (`\d` muestra las tablas) y un script `boto3` que ejecuta las 3 queries sobre DynamoDB (LocalStack) o explica por qué fue SKIP.

## Siguiente módulo

→ `aws-09-kms-secrets-manager-parameter-store` — gestión de claves y secretos (rotación automática de la password de RDS vía Secrets Manager).
