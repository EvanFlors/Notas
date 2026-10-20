# Ejemplo 03 — Budget con notificaciones

> Lectura y analisis. **Sin ejecucion contra GCP real**. Objetivo: leer una definicion de budget y predecir que alertas disparara, para que sirve Pub/Sub como *sink* y como se integra con Monitoring notification channels.

## 1. Para que sirve un Budget

Un **Budget** es una definicion en Cloud Billing que:

1. Vigila un **scope** (toda la BA, 1+ projects, por labels).
2. Define un **amount** esperado por periodo (`MONTH` tipicamente).
3. Lista **threshold rules** (`percent, basis`) que disparan **notificaciones**.
4. Rutea las notificaciones a **email** (default a admins/users de la BA), **Pub/Sub** (programatico) y/o **Monitoring notification channels** (Slack, SMS, PagerDuty via webhook).

Un Budget **no limita** gasto. **Notifica**. Para "frenar" hay que automatizar a partir del Pub/Sub message (p. ej., Cloud Function que **desenlaza** la Billing Account del project — matando el project). Este patron de *hard-stop* se trabaja en `gcp-10` (FinOps).

## 2. Anatomia de un budget YAML

Formato aceptado por `gcloud alpha billing budgets create --budget-from-file=`. Esquema simplificado:

```yaml
displayName: "checkout-dev monthly budget"

budgetFilter:
  projects:
    - "projects/my-project-123"
  calendarPeriod: MONTH
  # Alternativa: customPeriod con startDate/endDate.
  # Opcional: filtrar por label
  # labels:
  #   env:
  #     values: ["dev"]
  creditTypesTreatment: INCLUDE_ALL_CREDITS

amount:
  specifiedAmount:
    currencyCode: "USD"
    units: "100"
    # Para fracciones: nanos: 500000000 == 0.5

thresholdRules:
  - thresholdPercent: 0.5
    spendBasis: CURRENT_SPEND
  - thresholdPercent: 0.9
    spendBasis: CURRENT_SPEND
  - thresholdPercent: 1.0
    spendBasis: CURRENT_SPEND
  - thresholdPercent: 1.0
    spendBasis: FORECASTED_SPEND

notificationsRule:
  pubsubTopic: "projects/my-project-123/topics/budget-alerts"
  schemaVersion: "1.0"
  monitoringNotificationChannels:
    - "projects/my-project-123/notificationChannels/1234567890"
  disableDefaultIamRecipients: false
```

Elementos:

- **`displayName`**: cadena humana. Util en la UI de Billing.
- **`budgetFilter.projects`**: lista de `projects/<id>`. Si se omite, el budget cubre **toda** la BA.
- **`budgetFilter.calendarPeriod`**: `MONTH` reinicia cada mes; `QUARTER`/`YEAR` disponibles.
- **`amount.specifiedAmount`**: monto fijo. Alternativa: `lastPeriodAmount` para "igual que el mes anterior" (adaptativo).
- **`thresholdRules`**: lista de `(thresholdPercent, spendBasis)`:
  - `CURRENT_SPEND`: gasto acumulado del periodo.
  - `FORECASTED_SPEND`: proyeccion al fin de periodo. Dispara antes.
- **`notificationsRule`**:
  - `pubsubTopic`: topic donde Billing publica un message JSON cada vez que un threshold se cruza. Formato documentado.
  - `monitoringNotificationChannels`: canales (email, SMS, Slack via webhook, PagerDuty) definidos en Cloud Monitoring.
  - `disableDefaultIamRecipients`: si `false`, admins y users de la BA reciben email automatico.

## 3. Que mensaje publica Pub/Sub

Cuando un threshold se cruza, Billing publica un `PubsubMessage` cuyo `data` (base64) decodifica a JSON:

```json
{
  "budgetDisplayName": "checkout-dev monthly budget",
  "alertThresholdExceeded": 0.9,
  "costAmount": 92.37,
  "costIntervalStart": "2026-10-01T00:00:00Z",
  "budgetAmount": 100.0,
  "budgetAmountType": "SPECIFIED_AMOUNT",
  "currencyCode": "USD"
}
```

Y los atributos del mensaje incluyen `budgetId`, `billingAccountId`, `schemaVersion`.

Patrones habituales de consumo:

- **Slack notifier** (Cloud Function): formatea y postea a un webhook.
- **Hard-stop automation** (Cloud Function): si `alertThresholdExceeded >= 1.0` y `env=sandbox`, `gcloud billing projects unlink <PROJECT>`. **Riesgoso** — nunca en prod sin aprobacion manual.
- **FinOps dashboard** (BigQuery): combinar con billing export.

## 4. Thresholds razonables por tipo de project

| Tipo de project | Amount tipico (USD/mes) | Thresholds | Pub/Sub? |
|-----------------|-------------------------|------------|----------|
| `sandbox-<user>` | 10-30 | 50%, 90%, 100% CURRENT + 100% FORECASTED | Si — hard-stop auto. |
| `*-dev` | 50-200 | 50%, 90%, 100% CURRENT + 100% FORECASTED | Opcional — Slack notifier. |
| `*-stg` | similar a dev | igual | Opcional. |
| `*-prod` | lo que diga Finance | 50%, 90%, 100% CURRENT + 100% FORECASTED | **Nunca** hard-stop; solo alertas. |
| BA entera (fallback) | gasto estimado total | 90%, 100% CURRENT + 100% FORECASTED | Email a Finance. |

**Regla**: siempre al menos un budget **a nivel BA** (fallback global) **mas** budgets especificos por project critico.

## 5. Precaucion con `FORECASTED_SPEND`

`FORECASTED_SPEND` proyecta linealmente desde el gasto parcial del mes. En proyectos con picos puntuales (una ejecucion de BigQuery de 500 USD un dia 2 del mes) la proyeccion se vuelve histerica y dispara el 100% forecasted dia 3. Util como *canary* temprano; **no** como senal de que algo esta mal irreversiblemente.

Mitigacion: tener **ambos** thresholds (CURRENT + FORECASTED) y tratar la alerta FORECASTED como *info*, no como *page*.

## 6. Como se crea desde la CLI (dry-run conceptual)

```bash
# NO EJECUTAR contra una BA real sin governance.
# Comando intencionalmente mostrado para lectura:
gcloud alpha billing budgets create \
  --billing-account=XXXXXX-XXXXXX-XXXXXX \
  --budget-from-file=budget.yaml
```

Alternativas:

- **UI**: Console -> Billing -> Budgets & alerts -> Create budget. Mismos campos.
- **Terraform**: `google_billing_budget` (recomendado — versionado).
- **API REST** directa: `POST https://billingbudgets.googleapis.com/v1/billingAccounts/XXX/budgets`.

## 7. Trampas habituales

1. **Granularidad de billing**: los datos llegan a Billing con **4-24 h de retraso**. Un gasto a las 10:00 puede no aparecer hasta la medianoche siguiente. Los budgets reaccionan sobre esos datos; **no son real-time**.
2. **Pub/Sub topic debe existir antes** y la cuenta del servicio Billing debe tener `roles/pubsub.publisher` en el. `gcloud alpha billing budgets create` **no** lo crea por ti.
3. **Monitoring notification channel ID** es opaco (`1234567890`), no legible. Debes crearlo primero (`gcloud alpha monitoring channels create`) y copiar el ID.
4. **Un budget borrado deja de notificar inmediatamente**. Si un atacante tiene `roles/billing.budgets.admin` puede borrarlo. Mitigacion: `roles/billing.budgets.viewer` por default; `admin` solo para FinOps/Platform; alerta en Cloud Logging cuando se borra un budget (filter: `protoPayload.methodName="google.cloud.billing.budgets.v1.BudgetService.DeleteBudget"`).
5. **El amount se expresa en `units` + `nanos`** (formato `google.type.Money`). Para 100.50 USD: `units: "100", nanos: 500000000`. No es un `float`.

## 8. Preguntas de autocomprobacion

1. Un budget con `thresholdPercent: 0.9` y `spendBasis: FORECASTED_SPEND`, ¿cuando dispara? ¿Depende del dia del mes?
2. Si tienes un project `sandbox-alice` y quieres cortar hard a 10 USD, ¿que piezas necesitas (budget + Pub/Sub + Cloud Function + roles)?
3. ¿Que pasa si borras el `pubsubTopic` referenciado por un budget? ¿El budget sigue "funcionando" para los emails?
4. Un budget con filtro por `labels.env=prod`, ¿cubre un project cuyo recurso lleva el label pero el project no?
5. ¿Por que un budget **no es** un mecanismo de "stop automatico de gasto"? ¿Cual es, entonces, el mecanismo?
