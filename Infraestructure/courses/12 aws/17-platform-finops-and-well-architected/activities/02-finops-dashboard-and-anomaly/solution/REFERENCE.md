# REFERENCE — aws-17-02-finops-dashboard-and-anomaly

> Reporte modelo basado en los CSVs del `starter/`. Es **una** respuesta correcta, no la única.

## Sección 1 — Resumen ejecutivo

Analizamos 6 meses (`2025-05` a `2025-10`) de costes atribuidos (tag `env=prd`) de tres servicios (`checkout`, `catalog`, `search`) cruzados con MAU y requests mensuales. Dos conclusiones:

1. **`checkout` presenta una anomalía clara en `2025-08`**: su `cost_per_req` saltó de ~`$0.000488` (mediana) a `~$0.000860` (**1.76× la mediana**), sin cambios proporcionales en MAU ni requests. **Causa a investigar.**
2. `catalog` y `search` muestran la curva esperada: coste crece ~2–3 % mes a mes con el volumen; `cost_per_req` y `cost_per_mau` se mantienen prácticamente planos. Son candidatos razonables para comprometer **Savings Plan** sobre el baseline.

Acción corta: investigar `checkout 2025-08` y planear SP para `catalog` + `search`.

## Sección 2 — Unit economics por servicio

### `checkout`

| month   | cost_usd | cost_per_mau | cost_per_req |
|---------|----------|--------------|--------------|
| 2025-05 | 4120.50  | 0.034337     | 0.000488     |
| 2025-06 | 4210.75  | 0.033686     | 0.000484     |
| 2025-07 | 4305.20  | 0.033634     | 0.000484     |
| 2025-08 | **7820.40** | **0.060157** | **0.000860** |
| 2025-09 | 4395.60  | 0.033300     | 0.000475     |
| 2025-10 | 4480.00  | 0.033185     | 0.000477     |

Tendencia: estable **excepto** agosto, que es un pico aislado (no es nueva línea base; septiembre vuelve al patrón).

### `catalog`

| month   | cost_usd | cost_per_mau | cost_per_req |
|---------|----------|--------------|--------------|
| 2025-05 | 2015.30  | 0.008061     | 0.000129     |
| 2025-06 | 2060.10  | 0.008079     | 0.000130     |
| 2025-07 | 2080.75  | 0.008065     | 0.000129     |
| 2025-08 | 2110.20  | 0.008116     | 0.000129     |
| 2025-09 | 2135.90  | 0.008152     | 0.000129     |
| 2025-10 | 2165.00  | 0.008170     | 0.000130     |

Tendencia: baseline sólido y predecible. Candidato ideal para SP.

### `search`

| month   | cost_usd | cost_per_mau | cost_per_req |
|---------|----------|--------------|--------------|
| 2025-05 | 3210.80  | 0.017838     | 0.000146     |
| 2025-06 | 3285.40  | 0.017953     | 0.000147     |
| 2025-07 | 3340.15  | 0.017958     | 0.000147     |
| 2025-08 | 3395.60  | 0.018061     | 0.000148     |
| 2025-09 | 3450.25  | 0.018159     | 0.000147     |
| 2025-10 | 3510.00  | 0.018187     | 0.000148     |

Tendencia: ligera presión alcista (+2 % en 6 m). Vale analizar si hay subida de almacenamiento (OpenSearch índices creciendo) antes de comprometer SP.

## Sección 3 — Anomalía detectada

- **Servicio:** `checkout`
- **Mes:** `2025-08`
- **Métrica:** `cost_per_req = 0.000860`, mediana del servicio = `0.000484`, **ratio = 1.78×**.
- **Regla aplicada:** `ratio_to_median >= 1.5` (umbral del script `compute_unit_economics.py`).

**Hipótesis de causa raíz** (ordenadas por probabilidad a priori):

1. **Data transfer cross-AZ no controlado.** Un deploy en agosto podría haber movido réplicas de un `StatefulSet` o shards de ElastiCache a otra AZ, encareciendo el tráfico intra-región que es gratis dentro de AZ pero `$0.01/GB` cross-AZ. **Confirmar con VPC Flow Logs** y métrica `NetworkOut` por AZ.
2. **NAT Gateway saturado** por un cambio aplicativo (por ejemplo, un nuevo integration con un API externo descargando payloads grandes). `$0.045/GB processed by NAT` sube rápido. **Confirmar en CloudWatch `BytesOutToDestination`** del NAT.
3. **Rightsizing inverso**: alguien subió instancias de `m6i.large` a `m6i.2xlarge` en respuesta a un alert de CPU puntual y nunca bajó. **Confirmar con Compute Optimizer** y `CPUUtilization` horaria.
4. **Snapshot/backup runaway**: una política de AWS Backup añadida en agosto que replica cross-region. **Confirmar con AWS Backup activity log** y S3 bucket size.
5. **Cold starts / errores**: picos de 5xx que hacen retries exponenciales y multiplican requests internos (no visibles en el `requests` externo). **Confirmar con RED metrics por servicio** y log de 5xx.

**Qué pedir para confirmar:**

- CloudWatch Metrics por recurso del servicio `checkout` en agosto vs julio/septiembre.
- VPC Flow Logs filtrados por ENIs del servicio.
- Cost Explorer → group by `Usage Type` filtrando por tag `service=checkout` y mes agosto.
- Compute Optimizer recommendations para las instancias del servicio.
- Changelog de deploys/infra entre `2025-07-25` y `2025-08-10`.

## Sección 4 — Acciones FinOps priorizadas

1. **Investigar `checkout 2025-08` (prioridad P1).** Palanca: **data transfer / NAT**. Esfuerzo: medio. Ahorro esperado: `$3,000–$3,500` del mes anómalo + evitar recurrencia (banda `$3k–$5k/año`). Dependencias: VPC Flow Logs activos (si no, activar y esperar semana para repro).
2. **Compute Savings Plan 1y no-upfront sobre baseline de `catalog` + `search`.** Palanca: **SP**. Esfuerzo: bajo. Ahorro: ~27 % sobre coste cubierto (`~$5,250` × 12 × 0.27 ≈ `$17k/año`). Dependencia: confirmar baseline estable 2 meses más y aplicar primero rightsizing.
3. **Rightsizing guiado por Compute Optimizer** para los 3 servicios. Palanca: **rightsizing**. Esfuerzo: medio (requiere ventana de prueba por servicio). Ahorro estimado: 10–20 % del compute afectado. Dependencia: Compute Optimizer con mínimo 14 días de datos.
4. **Migrar workloads elegibles a Graviton (`t4g` / `m7g` / `c7g`).** Palanca: **Graviton**. Esfuerzo: medio (recompilar o imágenes multi-arch, pruebas de performance). Ahorro: 20–40 % en compute. Dependencia: dependencias nativas compiladas para ARM.
5. **Mover el batch de reindexación de `search` a Spot.** Palanca: **Spot**. Esfuerzo: medio (manejo de interrupción con checkpointing). Ahorro: 60–80 % sobre on-demand del batch. Dependencia: trabajo tolerante a interrupción.
6. **Centralizar NAT en inspection VPC** (si aún no está). Palanca: **arquitectura de red**. Esfuerzo: alto (requiere TGW + inspection VPC + migración de rutas por VPC). Ahorro fijo recurrente ~`$32 × (N-1)` dólares/mes + mejor visibilidad. Dependencia: landing zone decidida (actividad 01).

## Sección 5 — Walkthrough de Cost Explorer (textual)

Pasos canónicos para confirmar los hallazgos de este reporte en Cost Explorer **si tuvieras acceso real** (en esta actividad no lo tienes):

1. **Login en `management` (o cuenta con permiso de billing).** Abrir Cost Explorer.
2. **Filtro: `Time range` = últimos 6 meses, `Granularity` = Monthly.**
3. **Group by: `Service`.** Mira el top 5 y confirma `EC2 — Other`, `EC2 — Instance`, `RDS`, `S3`, `CloudWatch`.
4. **Add filter: `Tag` → `service` = `checkout`.** Observa el salto en agosto comparado con el resto de meses.
5. **Group by: `Usage Type`** manteniendo el filtro. El salto normalmente se concentra en `NatGateway-Bytes`, `DataTransfer-Regional-Bytes` o `BoxUsage:*` según la causa.
6. **Group by: `Linked Account`.** Confirma que el impacto está en `workload-prd` y no se "escapó" a otro env.
7. **Group by: `AZ`** si el `Usage Type` sugiere data transfer. Confirma movimiento cross-AZ.
8. **Volver a 3 meses y filtrar por `service=catalog` + `service=search`.** Verifica planitud para justificar la compra de Savings Plan.
9. **Pestaña `Savings Plans` → `Recommendations`.** Ventana 60 días, option `No Upfront 1-year, Compute SP`. Lee *estimated savings* y *break-even*. Guardar la recomendación.
10. **Guardar las vistas** como *Saved Reports* (`checkout-aug-anomaly`, `catalog+search-sp-candidate`) para repetir el ritual mensual sin reconstruir filtros.
