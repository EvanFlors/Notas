# Unit economics — checkout, mes 202610

> Referencia razonada. Los números corresponden al `synthetic-billing.csv` y `business-metrics.csv` del starter.

## Metodología

El export de Billing a BigQuery entrega el **coste bruto** por recurso en la columna `cost`, y los **créditos aplicados** (SUDs, CUDs, promos) como registros con signo negativo en `credits`. El **coste neto** facturado se calcula como:

```
net_cost = cost + credits
```

(los credits ya traen signo negativo). Olvidar sumarlos infla la cifra 10–30 % — es el error más común en dashboards caseros.

Para unit economics del workload `checkout` del mes `202610`:

1. Filtrar filas donde `label_workload == 'checkout'` e `invoice_month == '202610'`.
2. Sumar `cost + credits` → **coste neto del workload**.
3. Dividir por la métrica de negocio correspondiente (`requests_served` o `active_customers`) tomada de un CSV independiente que la app o Cloud Monitoring publican.

## Resultados

Contra el CSV del starter:

- **Coste neto `checkout` (prod + stg) para 202610**: `2280.00 EUR`
- **Requests servidas (`checkout`, 202610)**: `1,000,000`
- **Active customers mensuales (MAC)**: `500`

### Cost per request

```
2280.00 / 1_000_000 = 0.002280 EUR/req
```

Equivale a **0,228 céntimos por request**. Baseline razonable para un API HTTP con DB persistente en GCP.

### Cost per MAC

```
2280.00 / 500 = 4.560000 EUR/customer/mes
```

### Breakdown opcional por SKU

Los mayores drivers del coste de `checkout`:

| Servicio | Coste neto EUR |
|----------|----------------|
| Compute Engine (prod+stg VMs) | 1200.00 |
| Cloud SQL (Postgres HA + Zonal) | 630.00 |
| Networking (egress) | 300.00 |
| Cloud Logging | 120.00 |
| Artifact Registry | 30.00 |

## Interpretación

- `0.00228 EUR/req` es útil **como línea base para detectar regresiones**: una release que lo mueva a `0.00500` sin razón de negocio clara es señal de problema (nuevo query N+1, cache rota, instancia sobre-dimensionada).
- `4.56 EUR/MAC` se compara con el **ARPU** (`Average Revenue Per User`) para ver margen bruto. Si ARPU=20, margen ≈ 77 %. Si ARPU=5, hay problema estructural.

## Sesgos conocidos

1. **Shared infrastructure**: la factura de `Networking` incluye egress compartido con `analytics`. Atribuirla 100 % a `checkout` infla su número. Mitigación: usar `labels` sobre los recursos de egress o repartir pro-rata por GB.
2. **Costes fijos (Cloud Logging, Artifact Registry)**: no escalan 1:1 con requests. En meses de bajo tráfico, el cost-per-request sube artificialmente. Mitigación: reportar también el **coste total absoluto** y las métricas de uso.
3. **El mes incompleto**: si el cálculo se corre a mitad de mes, hay que anualizar o normalizar por días.
4. **CUDs amortizados**: los CUDs se aplican como credit; pero si están pre-pagados, el "coste real cash" ya se gastó. Para FinOps estratégico, distinguir cash-cost vs ledger-cost.

## Cómo escala a BigQuery

El CSV sintético imita el schema del export real `gcp_billing_export_resource_v1_<BA>` en BigQuery. En producción, los mismos cálculos se expresan como:

```sql
SELECT
  (SELECT value FROM UNNEST(labels) WHERE key = 'workload') AS workload,
  invoice.month AS month,
  SUM(cost + IFNULL((SELECT SUM(c.amount) FROM UNNEST(credits) c), 0)) AS net_cost
FROM `my-project-123.billing_export.gcp_billing_export_resource_v1_...`
WHERE invoice.month = '202610'
GROUP BY workload, month
HAVING workload = 'checkout';
```

Las métricas de negocio se cruzan con un `JOIN` sobre una tabla `business_metrics` que la app publica periódicamente.

## Ritual de FinOps

- **Mensual**: Platform corre estos cálculos el día 5 del mes siguiente (cuando el export ya está estable). Publica en un dashboard Looker Studio compartido con Finance.
- **Alerta**: si el `cost-per-request` del workload crítico se desvía >30 % mes a mes, se abre ticket automático y se escala al product owner.
- **Trimestral**: revisar si procede comprar CUDs sobre el baseline estable.
