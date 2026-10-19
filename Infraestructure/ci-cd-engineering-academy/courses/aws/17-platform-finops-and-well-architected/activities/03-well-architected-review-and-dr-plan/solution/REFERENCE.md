# REFERENCE — aws-17-03-well-architected-review-and-dr-plan

> Reporte modelo del capstone. Un ADR razonado y defendible, no la única respuesta.

---

# A. WELL-ARCHITECTED-REVIEW.md (modelo)

## Resumen ejecutivo

Review conducida sobre el workload **`orders-platform`** (SaaS B2C de e-commerce) en Q4 2025. Entrevistas con platform lead, SRE y payments eng. Scope: los 6 pilares WA.

**Hallazgos principales**:

1. **Reliability (HRI)**: single-region, sin plan DR cross-region para `checkout`/`payments`. Un incidente en `us-east-1` toma el negocio offline por ≥ 24 h.
2. **Cost Optimization (HRI)**: 0 cobertura de Savings Plans sobre un baseline estable de ~`$18k/mes` en compute. Dinero sobre la mesa.
3. **Security (MRI)**: MFA no obligatorio para accesos vía SSO; Security Hub no está centralizado en `audit`.

Recomendación global: ejecutar 6 acciones priorizadas en Q1-Q2 que mitigan 3 HRIs y entregan el ahorro de 15–20 % pedido por el CFO, en paralelo al plan DR cross-region para los dos servicios críticos.

---

## 1. Operational Excellence (Excelencia Operacional)

**Preguntas cubiertas:**

- ¿Hay runbooks por servicio accesibles y actualizados?
- ¿El equipo despliega al menos una vez por semana con éxito y rollback automatizado?
- ¿Hay post-mortems blameless con *action items* trackeados?

**Estado actual:** CI/CD con GitHub Actions a ECS Fargate; despliegues ~3/semana. Runbooks dispersos entre Confluence y Notion. Post-mortems existen pero sus action items se pierden tras 1–2 semanas.

**Hallazgos:**

- **MRI-OE-1**: runbooks sin dueño ni review periódica. Riesgo: en incidente real, nadie encuentra el runbook correcto a tiempo.
- **MRI-OE-2**: action items de post-mortems sin tracking formal (issue tracker).

**Recomendaciones:**

- Consolidar runbooks en un repo `platform-runbooks` con `OWNERS` por servicio. Review trimestral.
- Pipe post-mortems a Jira/Linear con etiqueta `post-mortem` y SLO interno (todo cerrado en 30 d).

---

## 2. Security (Seguridad)

**Preguntas cubiertas:**

- ¿Es MFA obligatorio para humanos y rotación automática para secretos?
- ¿Hay Security Hub + GuardDuty + Config aggregados en una cuenta `audit`?
- ¿El cifrado at-rest y in-transit está auditado?

**Estado actual:** SSO con Identity Center pero MFA opcional. GuardDuty activo en `us-east-1` solo. Secrets Manager usado para API keys; rotación manual. Cifrado at-rest por defecto en RDS y S3.

**Hallazgos:**

- **HRI-SEC-1**: MFA no obligatorio. Un credencial filtrado = acceso total.
- **MRI-SEC-2**: Security Hub no agregado en `audit`; findings dispersos.
- **MRI-SEC-3**: secretos sin política de rotación automática.

**Recomendaciones:**

- SCP `require-mfa` sobre OU `Workloads`.
- Activar Security Hub + delegated admin en `audit` + GuardDuty en todas las regiones aprobadas.
- Habilitar rotación automática en Secrets Manager para los 5 secretos críticos (DB, Stripe, etc.).

---

## 3. Reliability (Fiabilidad)

**Preguntas cubiertas:**

- ¿Está dimensionado multi-AZ y probado?
- ¿Hay plan DR cross-region con RTO/RPO acordado con negocio?
- ¿Se corren game days?

**Estado actual:** Multi-AZ en Aurora y ECS. **Single-region** `us-east-1`. Ningún game day en los últimos 12 meses. No hay replicación cross-region para RDS ni S3.

**Hallazgos:**

- **HRI-REL-1**: sin plan DR cross-region para `checkout` y `payments`. RTO actual ante caída regional: indefinido, probablemente ≥ 24 h.
- **MRI-REL-2**: no se corren game days ni tabletops.

**Recomendaciones:**

- Implementar **pilot-light** cross-region (`us-west-2`) para `checkout` y `payments` (ver `DR-PLAN.md`).
- Instalar cadencia de game days trimestrales y tabletops semestrales.

---

## 4. Performance Efficiency (Rendimiento)

**Preguntas cubiertas:**

- ¿Usamos los recursos adecuados (familias, tamaños, Graviton)?
- ¿Las métricas de latencia son observadas y hay SLOs?
- ¿Cacheamos lo que debemos?

**Estado actual:** Fargate con tareas `vCPU=2, mem=4GB`. CPU promedio 25–30 % → sobredimensionado. CloudFront + Redis cubren assets y sesiones. Sin uso de Graviton.

**Hallazgos:**

- **MRI-PERF-1**: tareas Fargate sobredimensionadas (Compute Optimizer sugiere `vCPU=1, mem=2GB` para 2 de 3 servicios).
- **MRI-PERF-2**: imágenes ECR no multi-arch; no se puede probar Graviton sin trabajo previo.

**Recomendaciones:**

- Habilitar Compute Optimizer y aplicar rightsizing en 2 iteraciones (dev → prd).
- Build multi-arch (`amd64` + `arm64`) en CI; probar Graviton primero en `catalog` (menor riesgo).

---

## 5. Cost Optimization (Optimización de Costos)

**Preguntas cubiertas:**

- ¿Cuál es el `$/MAU`, `$/req` por servicio?
- ¿Qué cobertura de Savings Plans / RIs tenemos?
- ¿Hay tagging obligatorio y Cost Explorer con dueños identificados?

**Estado actual:** `$42k/mes` total. Sin cobertura de SP ni RI. Tags presentes pero no obligatorios por SCP; cobertura real `~60 %`. Nadie "dueño" formal de la factura.

**Hallazgos:**

- **HRI-COST-1**: 0 % cobertura Savings Plan sobre un baseline estable (ver actividad 02).
- **MRI-COST-2**: `$/req` de `checkout` tuvo pico anómalo en agosto sin postmortem FinOps.
- **MRI-COST-3**: tagging al 60 %; segmentación de la factura es incompleta.

**Recomendaciones:**

- Comprar **Compute SP 1y no-upfront** cubriendo 60 % del baseline (ahorro estimado `$17k/año`, break-even ~90 d).
- Instaurar **ritual FinOps mensual** (ver `COST-EXPLORER-WALKTHROUGH.md`).
- Enforce tagging obligatorio con SCP (ver actividad 01 y ejemplo 01).

---

## 6. Sustainability (Sostenibilidad)

**Preguntas cubiertas:**

- ¿Elegimos regiones con huella de carbono baja?
- ¿Hay rightsizing e idle shutdown en entornos no-prd?
- ¿Usamos arquitecturas eficientes (Graviton, serverless, Fargate)?

**Estado actual:** `us-east-1` por histórico (huella media). `dev`/`stg` corren 24×7 por defecto. Sin estimación de `gCO2/req`.

**Hallazgos:**

- **MRI-SUS-1**: `dev` y `stg` encendidos 24×7 sin necesidad (ahorro energético + coste).
- **MRI-SUS-2**: sin uso de Graviton (menos eficiente energéticamente).

**Recomendaciones:**

- Scheduler para apagar `dev`/`stg` 20:00-08:00 y fines de semana (ahorro energético y `~$3k/mes`).
- Plan de migración gradual a Graviton (ver pilar Performance).

---

## Plan de mejora priorizado

| # | Hallazgo | Pilar | Riesgo | Esfuerzo | Impacto | Owner | Trimestre |
|---|----------|-------|--------|----------|---------|-------|-----------|
| 1 | HRI-REL-1 pilot-light cross-region para checkout+payments | Reliability | HRI | alto | alto | platform | Q1 |
| 2 | HRI-COST-1 compra Savings Plan 1y sobre baseline | Cost Optimization | HRI | bajo | alto | finops | Q1 |
| 3 | HRI-SEC-1 SCP require-mfa + rotación de secretos | Security | HRI | medio | alto | security | Q1 |
| 4 | MRI-PERF-1 rightsizing Fargate (2 servicios) | Performance Efficiency | MRI | medio | medio | platform | Q2 |
| 5 | MRI-COST-3 enforce tagging con SCP | Cost Optimization | MRI | medio | medio | platform | Q2 |
| 6 | MRI-SUS-1 scheduler dev/stg off-hours | Sustainability | MRI | bajo | medio | platform | Q2 |
| 7 | MRI-REL-2 game days trimestrales | Reliability | MRI | medio | alto | sre | Q2 |

---

# B. DR-PLAN.md (modelo)

## 1. Clasificación de workloads

| Workload | Criticidad | RTO objetivo | RPO objetivo | Patrón DR |
|----------|------------|--------------|--------------|-----------|
| `checkout` | crítico | ≤ 60 min | ≤ 5 min | pilot-light cross-region |
| `payments` | crítico | ≤ 60 min | ≤ 5 min | pilot-light cross-region |
| `catalog` | medio | 24 h | 24 h | backup + restore (cross-region snapshots) |
| batch nocturno (Redshift ingest) | bajo | 24 h | 24 h | backup + restore |

## 2. Justificación de patrones

- **`checkout` y `payments` → pilot-light**: el negocio exige RTO ≤ 60 min para transacciones y pagos. `backup+restore` no cumple (RTO ≥ 4 h). `warm-standby` cumple pero duplica la factura compute (`~2.0–2.5× baseline`); `active-active` es excesivo para una SaaS donde una ventana de 30–60 min de degradación es tolerable 1 vez al año. Pilot-light da el balance correcto (`~1.3–1.6× baseline del workload`, RTO 10–60 min).
- **`catalog` → backup + restore**: aunque está en el camino crítico de UX, el catálogo puede ser servido con una copia cacheada en CloudFront por horas; una restauración de 24 h es aceptable. No justifica pilot-light.
- **Batch Redshift → backup + restore**: workload offline, retrabajable al día siguiente.

## 3. Factura relativa a baseline

- Baseline mensual total: `~$42k`.
- Compute+DB de `checkout` + `payments`: `~$12k/mes`.
- Pilot-light añade **replicación Aurora cross-region** (`~$5–6k`), **S3 CRR** para assets críticos (`~$0.3–0.5k`), **ECR replication** (marginal), **network/TGW en secundaria** (`~$0.5k`), y **compute idle** (~0). Delta esperado: `+$6–7k/mes = +15–17 %` sobre total.
- `catalog`/batch con backup+restore: delta marginal (`<$500/mes` por snapshots cross-region).
- **Total DR cross-region esperado**: `+$6.5–7.5k/mes ≈ +16–18 %`. Dentro del presupuesto porque los Savings Plans del plan de mejora (`-$17k/año` ≈ `-$1.4k/mes`) y rightsizing (`-$2–3k/mes`) compensan parcialmente.

## 4. Runbook de failover (workload: `checkout`)

1. **Confirmar incidente** (sev-1): AWS Service Health Dashboard, métricas internas, confirmación de SRE on-call. Decisión humana del Incident Commander.
2. **Comunicar inicio**: canal `#incidents` + status page externa (banner "degraded").
3. **Promover Aurora read replica** `us-west-2` a *standalone* (o apuntar a Aurora Global secondary). Verificar `read_only=0`.
4. **Escalar ECS services** en `us-west-2`: `checkout` desired = 70 % del tamaño primario (12 tasks → 8–10) con autoscaling a 100 % en 10 min.
5. **Warm-up**: ejecutar 500 req sintéticas al endpoint `/health` + `/ready` + 20 req al endpoint real. Verificar p95 < 300 ms.
6. **Switch de DNS**: cambiar Route 53 primary record a `us-west-2`; el health check ya habrá iniciado el failover si está bien configurado. TTL del record debe estar a 60 s pre-incidente.
7. **Verificar SLOs**: dashboards de Grafana apuntando a métricas de `us-west-2`. Confirmar error rate < 1 %, p99 < 1 s.
8. **Monitorizar 1 h** con el on-call rotando. Preparar comunicación de "estamos en secundaria, los pedidos están completándose".
9. **Documentar**: timeline + decisiones en el canal `#incidents` para post-mortem.
10. **Vuelta a primaria** (una vez `us-east-1` sea estable): plan separado, con ventana de mantenimiento acordada.

## 5. Prueba y mantenimiento

- **Trimestral**: DNS failover simulado (sin tráfico real) + verificación de replicación RDS.
- **Semestral**: game day completo — forzar failover de `checkout` en horario de bajo tráfico, con tráfico sintético. Medir RTO real; registrar.
- **Anual**: ejercicio tabletop con producto, operaciones, finanzas y legal. Simular pérdida regional completa durante 2 h.
- **Post cambio arquitectónico mayor** (nueva DB, cambio de red): re-correr el pilot-light test aplicable.

---

# C. COST-EXPLORER-WALKTHROUGH.md (modelo)

Pasos para una **revisión mensual de 20 minutos** de `orders-platform` en Cost Explorer (**textual; sin acceso real**).

1. **Login en la cuenta `management`** (o cuenta delegada con permisos `ce:*`). Abrir **AWS Cost Management → Cost Explorer**.
2. **Time range**: últimos 3 meses, **Granularity**: Monthly. Esto da la base para comparar el mes actual contra los 2 anteriores.
3. **Group by: `Service`**. Observar el top 5. Esperable: `EC2 — Other` (incluye EBS, data transfer, NAT), `RDS`, `EC2 — Instance` (Fargate), `S3`, `CloudWatch`.
4. **Click en `EC2 — Other` → Group by: `Usage Type`**. Esto separa `NatGateway-Bytes`, `NatGateway-Hours`, `DataTransfer-Regional-Bytes`, `EBS:VolumeUsage.gp3`. Es el **mejor atajo** para detectar NAT o cross-AZ runaway.
5. **Filter: `Linked Account` = `workload-prd`** (filtro `linked_account_id`). Repetir el análisis solo para producción.
6. **Group by: `Tag` → `service`** (requiere que `service` esté activado como cost allocation tag en Billing). Comparar `checkout`, `catalog`, `payments`. Alinear con el reporte FinOps mensual (actividad 02).
7. **Group by: `Tag` → `env`**. Mirar que `dev` + `stg` juntos pesen menos del 15 % de `prd`. Si pesan más, hay instancias olvidadas.
8. **Pestaña `Savings Plans` → `Coverage`**. Leer `% coverage` del compute cubierto. Objetivo: 60–80 %. Debajo = compra pendiente; encima = sobrecompra (desperdicio).
9. **Pestaña `Savings Plans` → `Recommendations`**. Ventana de análisis 60 días, option `No Upfront, Compute SP 1y`. Leer *estimated monthly savings* y *break-even*. Si break-even > 180 d, no comprar.
10. **Pestaña `Reservations` → `Coverage`** para RDS. Objetivo similar.
11. **Guardar la vista** actual como *Saved Report* (`orders-platform-monthly`). Permite repetir el ritual sin reconstruir filtros.
12. **Documentar hallazgos** en el `FINOPS-REPORT.md` del mes y crear acciones en Jira con etiqueta `finops`.

### Ritual mensual (quién, cuándo)

- **Cuándo**: segundo martes del mes (ya cerrada la facturación del mes anterior).
- **Quién**: FinOps lead + platform lead + un ingeniero rotativo. 45 min max.
- **Qué se produce**: `FINOPS-REPORT-YYYY-MM.md`, 3–5 acciones priorizadas, review de los *Saved Reports*.
- **Dónde se guarda**: repo `platform-finops`, carpeta `monthly/`.

### Qué NO se hace en Cost Explorer

- Querys arbitrarios SQL — para eso **CUR en S3 + Athena**.
- Alertas en tiempo real — para eso **Cost Anomaly Detection** y **Budgets**.
- Forecast de >3 meses — Cost Explorer forecast es simple; para planificación anual, usar CUR + modelo propio.
