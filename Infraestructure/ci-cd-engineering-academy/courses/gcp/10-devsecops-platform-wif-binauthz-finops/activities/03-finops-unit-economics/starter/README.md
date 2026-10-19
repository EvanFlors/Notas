# Starter — gcp-10-03

Esta carpeta trae dos CSV sintéticos:

- `synthetic-billing.csv` — imita el export de Billing a BigQuery, aplanado. Columnas: `invoice_month, project_id, service, sku, usage_amount, usage_unit, cost, credits, label_env, label_workload, label_cost_center, region`.
- `business-metrics.csv` — métricas de negocio por workload y mes. Columnas: `month, workload, requests_served, active_customers`.

## Pasos

```bash
mkdir -p /tmp/gcp-10-03-finops
cp synthetic-billing.csv business-metrics.csv /tmp/gcp-10-03-finops/
cd /tmp/gcp-10-03-finops
```

Escribe los tres entregables:

- `cost_per_request.py`
- `cost_per_customer.py`
- `README-UNIT-ECONOMICS.md`

Valida:

```bash
bash <ruta-al-repo>/courses/gcp/10-devsecops-platform-wif-binauthz-finops/activities/03-finops-unit-economics/tests/validate.sh /tmp/gcp-10-03-finops
```

## Convención de salida de los scripts

Cada script debe:

- Aceptar dos argumentos: `python3 cost_per_request.py <billing_csv> <business_csv>`.
- Procesar solo el workload `checkout` para el mes `202610`.
- Calcular **coste neto** por fila como `cost + credits` (los credits ya vienen con signo negativo).
- Imprimir en stdout **solo un número** (float, 6 decimales), por ejemplo:

```
0.002280
```

El validador parsea ese número con tolerancia pequeña.
