# Ejemplo 03 — Budget con notificaciones

> Lectura y análisis. Las plantillas JSON son para inspeccionar; **no** se despliegan. Objetivo: entender la anatomía de un Budget y cómo conectar alertas sin bloquear gasto.

## 1. Qué es un Budget en Azure

Un **Budget** es un objeto de Azure Cost Management que:

- Monitoriza gasto **real** (`Actual`) o **previsto** (`Forecasted`).
- Dispara **alertas** cuando se cruzan umbrales expresados en % del amount definido.
- **No bloquea** gasto. Para bloquear, usa Azure Policy `deny` o subscriptions Dev/Test con tope duro.

Scope posible: Billing Account, Billing Profile, Management Group, Subscription, Resource Group.

## 2. Plantilla ARM/JSON de un Budget sobre un RG

```json
{
  "name": "budget-sandbox-dev-10usd",
  "type": "Microsoft.Consumption/budgets",
  "properties": {
    "amount": 10,
    "category": "Cost",
    "timeGrain": "Monthly",
    "timePeriod": {
      "startDate": "2026-01-01T00:00:00Z",
      "endDate":   "2027-01-01T00:00:00Z"
    },
    "filter": {
      "dimensions": {
        "name": "ResourceGroupName",
        "operator": "In",
        "values": ["rg-sandbox-dev"]
      }
    },
    "notifications": {
      "actual_50pct": {
        "enabled": true,
        "operator": "GreaterThan",
        "threshold": 50,
        "thresholdType": "Actual",
        "contactEmails": ["finops@example.com"],
        "contactGroups": [
          "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-sandbox-dev/providers/Microsoft.Insights/actionGroups/ag-finops"
        ]
      },
      "actual_80pct": {
        "enabled": true,
        "operator": "GreaterThan",
        "threshold": 80,
        "thresholdType": "Actual",
        "contactEmails": ["finops@example.com"]
      },
      "forecast_100pct": {
        "enabled": true,
        "operator": "GreaterThan",
        "threshold": 100,
        "thresholdType": "Forecasted",
        "contactEmails": ["finops@example.com"]
      }
    }
  }
}
```

> **Importante**: el GUID de subscription (`11111111-...`) es **placeholder ficticio**. En uso real, se materializa al crear la subscription.

## 3. Comando `az` (dry-run / `--help` únicamente)

```bash
# Vista de ayuda (seguro, no despliega nada):
az consumption budget create --help

# Listado de budgets existentes en la subscription activa (lectura):
az consumption budget list -o table

# Creación real — NO EJECUTAR en este módulo:
# az consumption budget create \
#     --budget-name "budget-sandbox-dev-10usd" \
#     --amount 10 \
#     --category Cost \
#     --time-grain Monthly \
#     --start-date 2026-01-01 \
#     --end-date 2027-01-01 \
#     --resource-group rg-sandbox-dev \
#     --notifications @notifications.json
```

## 4. Action Groups: el "destino" de la alerta

Un **Action Group** es la lista de destinos a los que la alerta se encamina: email, SMS, Azure Function, Logic App, webhook, ITSM. Para un sandbox personal basta con email; para una org seria, encaminar a Slack/Teams via Logic App y a un canal de PagerDuty via webhook.

```bash
# Vista de ayuda:
az monitor action-group create --help
```

## 5. Umbrales: Actual vs Forecasted

- `Actual`: dispara cuando el gasto **ya ocurrido** del periodo (mes) cruza el %. Útil para "ya nos pasamos".
- `Forecasted`: dispara cuando el **modelo** de Cost Management predice que, al ritmo actual, cruzarás el %. Útil para "a este ritmo nos vamos a pasar en 10 días".

Un patrón común para un sandbox de 10 USD/mes:

| Umbral | Tipo | Acción |
|--------|------|--------|
| 50% | Actual | Aviso suave a email. |
| 80% | Actual | Aviso urgente a email + Action Group. |
| 100% | Forecasted | Aviso a Slack #finops: "cierra el sandbox esta semana". |

Si quieres **bloquear** gasto cuando se cruce 100%, el mecanismo correcto **no** es el Budget; es un **runbook** disparado por el Action Group que ejecute `az group delete` del sandbox, o una **Azure Policy** con `deny` sobre creación de recursos caros.

## 6. Diferencias con AWS

| Concepto | AWS | Azure |
|----------|-----|-------|
| Objeto | AWS Budgets | Microsoft.Consumption/budgets |
| Alertas | SNS → email/Lambda | Action Groups → email/Logic App/webhook |
| Scope | Cuenta, Linked account, tag | MG, Subscription, RG, filtro por tag |
| Bloqueo | Vía SCPs + runbooks | Vía Azure Policy `deny` + runbooks |

## 7. Preguntas de autocomprobación

1. ¿Por qué un Budget `Actual = 100%` no es suficiente protección contra un `p5.48xlarge` encendido por accidente?
2. ¿Qué ventaja tiene un Budget con scope **Resource Group** sobre uno con scope **Subscription** para un sandbox personal?
3. ¿Cuándo preferirías Azure Policy `deny` sobre un Budget con alerta?
4. ¿Qué pasa si el Budget cruza el umbral pero el Action Group apunta a un email cuya cuenta ya no existe?

Se trabaja en la actividad `01-bootstrap-safe-subscription`.
