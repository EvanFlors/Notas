# Ejercicio arquitectónico — Examen AWS

Peso: **30%** del examen. Duración sugerida: **35–45 min**.

## Contexto (ficticio)

**Acme Analytics** es una scaleup europea (sede Dublín, oficina en Madrid, oficina en São Paulo). Tiene **una sola cuenta AWS** `123456789012` con todo mezclado (dev, stg, prod, logs, sandbox de ingenieros). Factura mensual ~$18k, con picos a $26k que nadie sabe explicar. Pulgares a presionar en los próximos 90 días:

- **Compliance**: están aplicando a SOC 2 Type II. El auditor exige: separación de ambientes, logs inmutables, principio de menor privilegio, MFA en acceso humano, cifrado at-rest con llaves gestionadas por el cliente para datos de clientes.
- **DR**: hoy no hay plan. El CTO acepta RPO ≤ 1 h y RTO ≤ 4 h para prod; dev/stg sin SLA.
- **FinOps**: necesitan 20–30% de reducción sin degradar producción.
- **Equipos**: 4 squads de producto + 1 squad plataforma. Hoy los product devs tienen `AdministratorAccess` vía IAM users con access keys.

## Carga de trabajo productiva

- API HTTP pública (`api.acmeanalytics.com`), FastAPI, hoy en 1 EC2 t3.large.
- 2 workers Python batch (overnight) corriendo en otras 2 EC2.
- Base de datos: Postgres en RDS single-AZ `db.t3.medium`, 500 GB.
- Un bucket S3 `acme-customer-data` con 2 TB de reportes de clientes (dato sensible).
- Un cluster EKS pequeño donde un equipo mete pet-projects; nadie sabe quién paga qué.
- CloudTrail apagado hace 6 meses "porque hacía ruido".

## Tarea

Entrega un diseño target **multi-cuenta** + plan de migración + ADR + estimación de impacto.

Formato esperado en `submission/architectural/`:

```
architectural/
  design.md            # diseño target: Organizations, cuentas, red, data, compute, obs, DevSecOps
  diagram.md           # 1-2 diagramas (mermaid o ASCII) de accounts + VPCs + flujos
  adr-0001-multi-account-landing-zone.md
  adr-0002-dr-strategy.md
  tradeoffs.md         # tabla comparando opciones consideradas y descartadas
  cost-estimate.md     # estimación mensual aproximada por cuenta (puede usar rangos; cita precios públicos)
  migration-plan.md    # fases, orden, criterio de "listo para cortar"
```

## Requisitos duros (no negociables)

1. **Organizations** con OUs: `security` (log-archive + audit), `workloads` (dev, stg, prod), `sandbox`. La cuenta de management **no** hospeda workloads.
2. **IAM Identity Center** (ex-SSO) con permission sets. Cero IAM users humanos. Cero access keys humanas.
3. **SCPs baseline**: deny leave org, deny disable CloudTrail/Config, deny regiones fuera de `eu-west-1` y `us-east-1` (CloudFront ACM), deny creación de IAM users.
4. **CloudTrail** org-trail con destino bucket en cuenta `log-archive`, cifrado con CMK, con log file validation.
5. **Pipeline CI/CD** usa OIDC (sin keys) con `sub` pinneado por env.
6. **Datos de clientes** cifrados con CMK en cada cuenta de workload; el bucket `customer-data` migra a cuenta `prod` con BPA + versioning + bucket policy que exige TLS y deniega `aws:PrincipalOrgID != o-acme`.
7. **DR**: propón concretamente **una** estrategia (pilot-light / warm standby / multi-region active-active) para prod, cumpliendo RPO 1 h / RTO 4 h, y justifica por qué descartaste las otras dos. Explica qué cambia si el bus de latencia Dublín↔São Paulo pesa en el diseño.
8. **FinOps**: identifica los **top-5 drivers** de los $18k y propón acciones concretas con ahorro estimado (NAT, egress inter-AZ, CW Logs, EC2 vs Fargate/Graviton, tagging strategy).
9. **Compute target** para la API: justifica ECS Fargate vs EKS vs App Runner para esta carga. Si eliges EKS, justifica por qué vale la cuota operativa; si eliges Fargate, qué pasa cuando el equipo quiera gRPC streaming y canary deployments.
10. **Well-Architected**: en `design.md` incluye una tabla con un ítem concreto por cada uno de los **6 pilares** (operational excellence, security, reliability, performance efficiency, cost optimization, sustainability).

## Reglas de higiene

- Prosa en español, código y nombres de recursos en inglés.
- Account IDs: `123456789012` (management), `210987654321` (log-archive), y continúa con dummies secuenciales. **No** uses IDs reales de ningún cliente/empleador.
- Nada de secretos. Nada de passwords de ejemplo "reales".
- Diagramas pueden ser mermaid o ASCII; **no** se evalúa estética sino *qué comunican* (AZs, route tables, flujos de datos, confianza entre cuentas).

## Puntos clave que debe tocar el ADR (checklist instructor)

### ADR-0001 — Landing zone

- [ ] Contexto: por qué una sola cuenta no sobrevive al audit.
- [ ] Opciones: (a) status quo + tags, (b) Control Tower, (c) Organizations + Terraform propio.
- [ ] Decisión con criterio: control vs opinión; usualmente Control Tower para empezar.
- [ ] Consecuencias: cuentas adicionales a presupuestar, limitaciones de CT en customización inicial.

### ADR-0002 — DR

- [ ] Define RPO/RTO oficialmente.
- [ ] Compara pilot-light / warm standby / active-active con **tabla**: costo, complejidad, RPO/RTO reales, superficie de bugs cross-region.
- [ ] Elige una, descarta las dos con razón.
- [ ] Habla de cómo se replica: RDS cross-region read replica vs AWS Backup copy; S3 Cross-Region Replication; Route 53 health checks + failover routing.
- [ ] Toca el bus de latencia Dublín↔São Paulo (si eligen multi-region, qué región secundaria).

## Rúbrica

| Criterio | Peso | Insuf (0) | Básico (1) | Comp (2) | Experto (3) |
|---------|------|-----------|------------|----------|-------------|
| **Separación de cuentas y guardrails** | 20% | Mantiene single-account o OUs sin SCPs | OUs correctas sin SCPs útiles | OUs + SCPs baseline cubriendo los 4 invariantes requeridos | + Control Tower / AFT / lifecycle de accounts documentado |
| **IAM, OIDC y acceso humano** | 15% | Deja IAM users / access keys | IdC sin permission sets definidos | IdC con permission sets por OU + OIDC con `sub` pinneado | + boundary para delegación + rotación / revocación / break-glass |
| **Red y datos** | 15% | VPCs flat o sin endpoints | Multi-AZ pero sin TGW ni endpoints | Hub-and-spoke con TGW, endpoints S3/ECR, Route 53 resolver, egress controlado | + inspection VPC + Network Firewall justificado |
| **DR** | 15% | Sin plan o afirma "multi-region active-active" sin costo ni análisis | Elige una estrategia sin tabla comparativa | Tabla + decisión + RPO/RTO validables | + prueba del plan (game day) + runbook + fallback |
| **FinOps** | 15% | Sin drivers ni números | Drivers nombrados sin acción | Top-5 drivers + acciones + ahorro estimado | + tagging como enforcement SCP + Savings Plan sizing + anomaly detection |
| **Well-Architected (6 pilares)** | 10% | Omite ≥3 pilares | Toca 4-5 superficialmente | Un ítem concreto y accionable por pilar | + mapea cada ítem a un servicio AWS y a una métrica de éxito |
| **Compute target** | 10% | Mantiene EC2 single-AZ | Elige servicio sin trade-off | Elige + justifica contra alternativas + cubre canary/gRPC/etc | + fuga de costos entre staging y prod + autoscaling policy |

Umbral de aprobación para el arquitectónico: **60%** del peso (18/30 pts).

## Guía de corrección (instructor-only)

### Respuesta de referencia (resumen)

**Topología esperada**:

```
Organization o-acme
├── OU security
│   ├── log-archive (210987654321): bucket cloudtrail + bucket config + bucket s3 access logs
│   └── audit (210987654323): Security Hub delegated admin, GuardDuty org, Inspector org
├── OU workloads
│   ├── dev   (210987654324)
│   ├── stg   (210987654325)
│   └── prod  (210987654326): API + RDS + customer-data bucket + EKS si justifica
├── OU sandbox (210987654327)
└── management (123456789012): sólo Organizations, IdC, CT, billing. CERO workloads.
```

**Red**: cada workload account con VPC propia; TGW hub en una `network` account (opcional en V1, obligatorio al escalar) para conectar prod↔log-archive y prod↔shared-services; endpoints Gateway S3+DynamoDB (gratis), Interface endpoints para ECR, Secrets Manager, STS, CloudWatch Logs; NAT GW único por AZ en cada cuenta de workload hasta justificar hub centralizado.

**Compute**: para esta carga, **ECS Fargate** basta. EKS sólo si el equipo plataforma ya corre K8s y los product teams lo demandan. App Runner descartado por falta de VPC privada para la DB sin complejidad adicional. Explicar costo de EKS control plane ($73/mes/cluster) + perfil Fargate + la deuda operativa de upgrades trimestrales.

**DR**: con RPO 1 h / RTO 4 h → **warm standby** cross-region (`eu-west-1` primario, `eu-central-1` secundario). RDS cross-region read replica; S3 CRR; EKS/Fargate con infra idéntica apagada o escalada a 0; Route 53 failover con health check. Pilot-light no cumple RTO 4 h si los contenedores deben hornearse. Active-active duplica costos y añade complejidad de consistency en RDS. Para São Paulo, latencia justifica un **CloudFront + edge locations** antes que una tercera región.

**FinOps top-5 esperados**:

1. **NAT GW** multi-AZ en todas las cuentas → consolidar en inspection VPC o reemplazar por VPC endpoints. Ahorro orden de magnitud: $200-800/mes.
2. **EC2 under-utilized** (t3.large para FastAPI) → Fargate con autoscaling o Graviton t4g. Ahorro: 30-40%.
3. **CloudWatch Logs** sin retención → aplicar retention + subscription a S3 + Glacier. Ahorro variable.
4. **RDS single-AZ oversized** sin backups → right-size + reserved instance 1-year, multi-AZ para prod (costo extra justificado por SLA audit).
5. **Egress inter-AZ** por workers batch cross-AZ → colocar workers en misma AZ que la DB o usar VPC endpoint para S3.

### Errores comunes y cómo puntuar

- **"Vamos a Control Tower y listo"** sin OUs ni SCPs: Básico (1). Falta diseño propio.
- **"Multi-region active-active"** sin tabla de costos: Básico (1). Over-engineered para el caso.
- **"Pilot-light"** sin reconocer que RTO 4h es apretado: Básico. Experto reconoce y mitiga.
- **Mantiene EKS "porque ya lo tienen"** sin preguntar qué corre allí: Básico. Experto propone auditoría primero y evalúa migrar.
- **No cuantifica FinOps**: Insuficiente en ese criterio.
- **Deja la cuenta de management con workloads**: red flag → tope en Básico global.

### Red flags que bajan dos niveles automáticamente

Ver `../competency-matrix.yaml`. En particular:

- Deja IAM users humanos.
- Trust policy OIDC sin pinnear.
- CloudTrail sigue off o escribe en la misma cuenta.
- Account IDs reales en el entregable.
- Workloads en management.
- `"Action":"*"` en permission sets productivos.

### Preguntas de seguimiento (live)

- "¿Qué pasa el día 1 después del corte si un product dev necesita hotfix en prod y SSO cae?"
- "Enséñame la SCP que impide a un dev crear un bucket público. Ahora, ¿qué pasa si crea el bucket con la bucket policy en vez de ACL?"
- "Tu diseño de warm standby, ¿cómo detecta que el failover es necesario sin flap? ¿Qué métrica, qué threshold, qué duración?"
- "El bucket `customer-data` se migra a `prod`: ¿cómo garantizas que durante la migración no hay ventana donde el bucket sea legible por `sandbox`?"
- "FinOps: si el CFO pide 50% de ahorro, ¿qué cortas que hoy no estás recomendando cortar? ¿Qué rompes al hacerlo?"
- "En tu tabla de Well-Architected, el pilar de sustainability dice X. ¿Cómo mides si cumpliste?"
