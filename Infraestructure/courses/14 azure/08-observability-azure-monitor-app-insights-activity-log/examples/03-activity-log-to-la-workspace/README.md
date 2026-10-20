# Ejemplo 03 — Enviar el Activity Log de la suscripción a un Log Analytics Workspace

> Lectura y análisis. Sin ejecución. Objetivo: entender cómo se *exporta* el Activity Log a un workspace para hacer KQL sobre él, qué recurso ARM lo hace y por qué el default (90 días en la plataforma) rara vez es suficiente.

## 1. El flujo

```
Suscripción (control plane)
    │   emite eventos a Activity Log (azure.monitor.activity)
    │   (retención gratis: 90 días, solo lectura en portal)
    ▼
Diagnostic Setting a nivel suscripción
    │   categorías seleccionadas: Administrative, Policy, ...
    ▼
Log Analytics Workspace
    tabla: AzureActivity
    retención: 31–730 días (facturada)
    consultable con KQL + alertable
```

**Idea clave:** el Activity Log *existe por defecto* y es gratis durante 90 días; el **export** a Log Analytics es lo que cuesta (ingestion GB) y lo que te permite escribir KQL y alertas de log.

## 2. Recurso ARM: `diagnosticSettings` a nivel suscripción

```json
{
  "name": "to-la-shared-security",
  "properties": {
    "workspaceId": "/subscriptions/REDACTED-SUB-ID/resourceGroups/rg-platform-observability/providers/Microsoft.OperationalInsights/workspaces/la-shared-security",
    "logs": [
      { "category": "Administrative",  "enabled": true  },
      { "category": "Security",        "enabled": true  },
      { "category": "ServiceHealth",   "enabled": true  },
      { "category": "Alert",           "enabled": true  },
      { "category": "Policy",          "enabled": true  },
      { "category": "Autoscale",       "enabled": false },
      { "category": "Recommendation",  "enabled": false },
      { "category": "ResourceHealth",  "enabled": true  }
    ]
  }
}
```

- `workspaceId` apunta al workspace de destino. En un entorno real, se parametriza por Terraform; aquí se muestra con `REDACTED-SUB-ID` para que **no haya IDs reales de tenant/subscription** en el repo.
- Se puede enviar a Storage Account (archivo), Event Hub (streaming a Splunk/Datadog) o Partner solution **a la vez**.
- Categorías `Autoscale` y `Recommendation` apagadas por default — generan mucho ruido con poca señal operativa.

## 3. Verificar que llega

Una vez aplicado, pasados 5–10 minutos:

```kql
AzureActivity
| where TimeGenerated > ago(1h)
| summarize events = count() by CategoryValue
| order by events desc
```

Columnas típicas:

| Columna | Qué contiene |
|---------|--------------|
| `TimeGenerated` | Timestamp de la operación. |
| `CategoryValue` | Nombre de la categoría (`Administrative`, `Policy`...). |
| `OperationNameValue` | Operación ARM (`Microsoft.Network/networkSecurityGroups/delete`). |
| `ActivityStatusValue` | `Started` / `Succeeded` / `Failed`. |
| `Caller` | Objeto principal (UPN de usuario, appId de SPN, GUID de MI). |
| `ResourceId` | ARM id del recurso afectado. |
| `Properties` | JSON con detalles específicos de la operación. |

## 4. Alerta de ejemplo: alguien borró una NSG

Dos opciones.

### 4.1 Activity Log Alert (`activityLogAlerts`) — recomendado

Reacciona al evento directamente, sin pasar por KQL:

```json
{
  "name": "alert-nsg-delete",
  "properties": {
    "scopes": ["/subscriptions/REDACTED-SUB-ID"],
    "condition": {
      "allOf": [
        { "field": "category",            "equals": "Administrative" },
        { "field": "operationName",       "equals": "Microsoft.Network/networkSecurityGroups/delete" },
        { "field": "status",              "equals": "Succeeded" }
      ]
    },
    "actions": {
      "actionGroups": [{ "actionGroupId": "/subscriptions/REDACTED-SUB-ID/resourceGroups/rg-platform-observability/providers/Microsoft.Insights/actionGroups/ag-platform-oncall" }]
    },
    "enabled": true
  }
}
```

**Ventaja**: casi gratis, latencia baja, no requiere ingestión en workspace.

### 4.2 Scheduled Query Rule (`scheduledQueryRules`) — para casos sin evento directo

Útil cuando necesitas un *patron* sobre varios eventos (p. ej. "5 roles diferentes modificados en 10 minutos"):

```json
{
  "name": "alert-role-churn",
  "properties": {
    "severity": 2,
    "enabled": true,
    "scopes": ["<workspaceResourceId>"],
    "evaluationFrequency": "PT5M",
    "windowSize": "PT10M",
    "criteria": {
      "allOf": [{
        "query": "AzureActivity | where OperationNameValue has 'roleAssignments/write' | summarize c = dcount(ResourceId)",
        "timeAggregation": "Count",
        "operator": "GreaterThan",
        "threshold": 5
      }]
    },
    "actions": { "actionGroups": ["<actionGroupId>"] }
  }
}
```

## 5. Lo que suele salir mal

- **Habilitar todas las categorías** → factura explota. `Autoscale` y `Recommendation` *rara vez* ayudan en respuesta a incidentes.
- **Enviar a un workspace equivocado** (uno operativo, no uno de seguridad): logs de audit mezclados con logs de app, RBAC complicado.
- **No alertar nada**: ingerir Activity Log sin reglas asociadas es casi tirar el dinero — la mayor parte del valor viene de *reaccionar*, no de guardar.
- **Olvidar que el management account/suscripción raíz** necesita *su propio* diagnostic setting; no se hereda automáticamente de uno aplicado al tenant.

## 6. Terraform conceptual (fuera del alcance de este ejemplo)

```hcl
resource "azurerm_monitor_diagnostic_setting" "sub_to_la" {
  name                       = "to-la-shared-security"
  target_resource_id         = "/subscriptions/${var.subscription_id}"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.sec.id

  enabled_log { category = "Administrative" }
  enabled_log { category = "Security"       }
  enabled_log { category = "ServiceHealth"  }
  enabled_log { category = "Alert"          }
  enabled_log { category = "Policy"         }
  enabled_log { category = "ResourceHealth" }
}
```

En Fase 4 se traduce — aquí el entregable es sólo entender el JSON ARM equivalente y las categorías.
