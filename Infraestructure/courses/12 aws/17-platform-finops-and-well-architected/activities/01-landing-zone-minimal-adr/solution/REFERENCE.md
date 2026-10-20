# REFERENCE — aws-17-01-landing-zone-minimal-adr

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

## Sección 1 — Contexto

Scaleup de 60 ingenieros con una única cuenta AWS. Síntomas: factura opaca, un `terraform destroy` erróneo tiró staging, auditores piden separación entre `audit`, `log-archive` y `workload`, 7 NAT Gateways sin dueño claro. Se aprueba 2 semanas de trabajo para montar la landing zone definitiva.

Objetivos: controlar blast radius, segmentar la factura por equipo/servicio, satisfacer auditoría y preparar el terreno para FinOps repetible.

## Sección 2 — Decisión

Adoptamos una **landing zone multi-cuenta sobre AWS Organizations**, con **4 OUs** (`Security`, `Infrastructure`, `Workloads`, `Sandbox`), **7 cuentas iniciales**, **red hub-and-spoke** centralizada con **Transit Gateway** en la cuenta `network`, logging centralizado en `log-archive` y governance delegada a `audit`.

## Sección 3 — Estructura de cuentas y OUs

```
AWS Organization (root)
│
├── OU: Security
│     ├── log-archive        (111111111111)  — bucket central de logs, write-once (Object Lock)
│     └── audit              (222222222222)  — Security Hub, GuardDuty, Config aggregator
│
├── OU: Infrastructure
│     ├── network            (333333333333)  — Transit Gateway, inspection VPC, NAT central
│     └── shared-services    (444444444444)  — Route 53 PHZ, SSO, ECR, artifact repos
│
├── OU: Workloads
│     ├── workload-dev       (555555555555)
│     ├── workload-stg       (666666666666)
│     └── workload-prd       (777777777777)
│
└── OU: Sandbox              (opcional; cuentas efímeras para experimentos)
```

- `management` (`000000000000`) es la **raíz de la Org**, paga la factura consolidada y **no** ejecuta workloads.
- `log-archive` es inmutable para los operadores humanos (SCP de deny delete).
- `audit` es el único panel único de seguridad.
- `network` posee el TGW y la *inspection VPC*.
- `shared-services` tiene lo compartido no-sensible (DNS interno, SSO, ECR).
- Los 3 `workload-*` son los únicos que ejecutan apps de producto.

> Todos los IDs son **ficticios**; en real se generan al crear la cuenta.

## Sección 4 — Red (hub-and-spoke con Transit Gateway)

```
   workload-dev VPC ─┐
   workload-stg VPC ─┼──► TGW (cuenta network) ──► inspection VPC ──► NAT GW ──► Internet
   workload-prd VPC ─┘                                    │
                                                          └──► (futuro) Network Firewall

   Resolver endpoints (inbound/outbound) en inspection VPC
   PHZ (private hosted zone) en shared-services, asociada a todas las VPCs vía TGW
```

**Trade-off de coste:** cada NAT Gateway cuesta `~$32/mes` de fijo + `~$0.045/GB` procesado. Pasar de **7 NATs** (uno por VPC) a **1 NAT central** colapsa `7 × $32 = $224/mes` a `~$32/mes` (`+ segundo NAT en otra AZ para HA = ~$64/mes`). El ahorro fijo mensual es `~$160/mes`, antes de contar tráfico. **A cambio** se paga el TGW (`$0.05/attachment-hour` por VPC-attachment + `$0.02/GB` procesado). En volúmenes moderados **el saldo es positivo**; en volúmenes muy altos de tráfico cross-VPC la cuenta se vuelve a mirar.

## Sección 5 — SCPs base

1. **`deny-non-approved-regions`** — adscrita a OUs `Workloads` e `Infrastructure`. Deniega acciones fuera de `us-east-1` y `eu-west-1` (regiones aprobadas) para evitar costes y riesgos en regiones no monitorizadas. No se aplica a `Security` por si Security Hub/Config necesitan operar global.
2. **`require-mandatory-tags-on-create`** — adscrita a OU `Workloads`. Deniega `ec2:RunInstances`, `s3:CreateBucket`, `rds:CreateDBInstance`, `eks:CreateCluster` sin los tags `cost_center`, `env`, `service`, `team`, `data_classification`. Ver `examples/01-tagging-strategy-and-enforcement-scp/`.
3. **`deny-log-archive-delete`** — adscrita **solo a la cuenta `log-archive`** (SCP a nivel cuenta o OU `Security` con condición). Deniega `s3:DeleteObject*`, `s3:DeleteBucket`, `kms:Delete*` sobre los recursos de logging incluso al root.
4. **`deny-leave-organization`** — adscrita al root o OU `Workloads`. Deniega `organizations:LeaveOrganization` para evitar que una cuenta se desprenda de la Org por error o malicia.
5. **`require-mfa-for-iam-admin`** — adscrita a OU `Workloads`. Deniega acciones IAM si el principal no está autenticado con MFA.

(3 son el mínimo requerido; 5 es el baseline recomendado.)

## Sección 6 — Logging y governance

- **CloudTrail Organization Trail** creado desde `management`, destino: bucket versionado en `log-archive` con **Object Lock (compliance mode, retención 1 año)** y **SSE-KMS** con key en `log-archive`.
- **VPC Flow Logs** de todas las VPCs → mismo bucket (prefijo `vpc-flow-logs/`) con retención a 90 d en S3 Standard-IA y 7 años en Glacier Deep Archive.
- **AWS Config** activado en todas las cuentas con **aggregator** en `audit`. Conformance packs: `Operational-Best-Practices-for-AWS-Well-Architected` + `Operational-Best-Practices-for-CIS-AWS-Foundations-Benchmark`.
- **Security Hub + GuardDuty + IAM Access Analyzer** con `audit` como **delegated administrator**.
- **CloudTrail Lake** para queries SQL sobre eventos (opcional, considerar coste).

**Habilitador FinOps indirecto:** Config mantiene inventario de todos los recursos con sus tags; cualquier recurso sin `cost_center`, `env` o `team` sale en un reporte semanal, y se usa para campañas de limpieza antes de que el coste se acumule.

## Sección 7 — Alternativas consideradas y rechazadas

- **Alternativa A: single-account con tags.** Rechazada. No resuelve blast radius; una SCP no puede limitar permisos dentro de una misma cuenta con la misma granularidad que separar cuentas; los auditores exigen separación física de `audit`/`log-archive`/`workload`.
- **Alternativa B: full-mesh VPC peering en lugar de Transit Gateway.** Rechazada. `O(N²)` peerings a mantener a partir de ~5 VPCs; cada nueva VPC requiere `N` nuevas conexiones + rutas; sin visibilidad central ni inspección; no soporta patrones hub-and-spoke sin trucos. TGW cuesta más por hora, pero su overhead operativo es dramáticamente menor.
- **Alternativa C: AWS Control Tower "chavo"** (sin personalización). Rechazada **parcialmente**: Control Tower es una buena primera iteración, pero nuestra organización ya tiene VPCs preexistentes y conformance packs no estándar; preferimos **Landing Zone Accelerator** o IaC propio con Terraform para control fino. Mantenemos CT como opción para dev/sandbox.
- **Alternativa D: NAT por cuenta.** Rechazada por el cálculo de la sección 4.

## Sección 8 — Consecuencias

**Positivo**:

- **Blast radius** acotado por cuenta.
- **Factura segmentada real** por cuenta + tag.
- **Auditoría** satisfecha con separación `audit`/`log-archive`/`workload`.
- **Ahorro NAT** de `~$160/mes` fijo (datos ilustrativos).
- **FinOps habilitado**: tags obligatorios + Config inventariado + Cost Explorer por tag.
- **Governance centralizada** en `audit` para SOC.

**Negativo** (asumido con los ojos abiertos):

- **Overhead humano**: necesita un *platform team* (al inicio 0.5 FTE).
- **Coste fijo plataforma**: Transit Gateway attachments, Config, Security Hub, CloudTrail trails suman 5–15 % del total en orgs pequeñas.
- **Curva de aprendizaje IAM cross-account**: roles asumidos, `sts:AssumeRole` desde `management`.
- **Fricción inicial**: SCPs mal calibradas al principio pueden bloquear equipos; se mitiga con un canal `#platform-support` y ciclo de iteración rápido.
- **Lock-in AWS** reforzado (Organizations, SCP, TGW son AWS-only).

**Decisión de revisión**: este ADR se revisa a los 6 meses con métricas de adopción (cuentas creadas, SCP violations, cost allocation coverage).
