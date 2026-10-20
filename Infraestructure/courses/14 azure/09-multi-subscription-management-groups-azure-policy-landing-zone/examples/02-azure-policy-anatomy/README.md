# Ejemplo 02 — Anatomía de una Azure Policy

> Lectura y análisis. Sin ejecución. Objetivo: ser capaz de **leer una `policyDefinition`** y predecir qué efecto aplica y a qué recursos.

## 1. Esqueleto comentado

```json
{
  "properties": {
    "displayName": "Deny Public IP creation",
    "policyType": "Custom",
    "mode": "All",
    "description": "Denies creation of public IP addresses in sensitive scopes.",
    "metadata": {
      "category": "Network",
      "version": "1.0.0"
    },
    "parameters": {},
    "policyRule": {
      "if": {
        "field": "type",
        "equals": "Microsoft.Network/publicIPAddresses"
      },
      "then": {
        "effect": "deny"
      }
    }
  }
}
```

- **`properties.displayName`**: nombre legible en portal y CLI. **No** es el `name` del recurso; eso lo pone la asignación.
- **`properties.policyType`**: `Custom` para las tuyas; `BuiltIn` para las que trae Azure; `Static` para compliance regulatorio (no editables).
- **`properties.mode`**: `All` (todos los tipos de recurso, lo recomendado) o `Indexed` (solo recursos con tags y location — útil para policies de tagging, pero deja fuera p. ej. role assignments).
- **`properties.description`**: documentación. **Importante** para audit — alguien va a leerla cuando una creación se bloquee.
- **`properties.metadata.category`**: categoría (Network, Compute, Storage, General, ...). Facilita filtrado en portal.
- **`properties.parameters`**: parámetros expuestos a la asignación. Vacíos aquí; obligatorios cuando quieres reutilizar la definición.
- **`properties.policyRule.if`**: condición. Operadores: `field`, `value`, `allOf`, `anyOf`, `not`, `equals`, `notEquals`, `in`, `notIn`, `like`, `match`, `exists`.
- **`properties.policyRule.then.effect`**: `audit`, `deny`, `append`, `modify`, `deployIfNotExists`, `auditIfNotExists`, `disabled`.

## 2. Patrón: `deny-locations` (whitelist regional)

```json
{
  "properties": {
    "displayName": "Allowed locations (EU only)",
    "policyType": "Custom",
    "mode": "All",
    "parameters": {
      "allowedLocations": {
        "type": "Array",
        "metadata": {
          "displayName": "Allowed locations",
          "strongType": "location"
        },
        "defaultValue": ["westeurope", "northeurope"]
      }
    },
    "policyRule": {
      "if": {
        "allOf": [
          { "field": "location", "notIn": "[parameters('allowedLocations')]" },
          { "field": "location", "notEquals": "global" },
          { "field": "type", "notEquals": "Microsoft.AzureActiveDirectory/b2cDirectories" }
        ]
      },
      "then": { "effect": "deny" }
    }
  }
}
```

**Qué hace**: deniega la creación de cualquier recurso cuya `location` **no** esté en la lista permitida, salvo los que son `global` o excepciones conocidas.

**Qué NO hace**: no mueve recursos existentes a regiones permitidas; no afecta a recursos ya creados en regiones no permitidas (solo los marca non-compliant si se evalúan).

**Por qué exceptuar `global`**: Front Door, DNS Zones, Traffic Manager, Role Definitions son recursos con `location = "global"`. Sin la excepción, no puedes crear ninguno.

## 3. Patrón: `deny-public-ip` (reducir superficie)

```json
{
  "properties": {
    "displayName": "Deny Public IPs",
    "policyType": "Custom",
    "mode": "All",
    "policyRule": {
      "if": {
        "field": "type",
        "equals": "Microsoft.Network/publicIPAddresses"
      },
      "then": { "effect": "deny" }
    }
  }
}
```

**Qué hace**: cualquier intento de crear un `Microsoft.Network/publicIPAddresses` en el scope asignado se rechaza.

**Trampa**: esto **también** bloquea Public IPs de un Azure Load Balancer público o de un NAT Gateway. Si tu arquitectura los necesita, exceptúalos con `tags` o con un policy adicional. Mejor patrón: asignar esta policy solo en `Landing Zones/Corp` (fuerza Private Endpoints + ExpressRoute); dejar `Online` sin ella.

## 4. Patrón: `audit-diagnostic-settings` (detectivo)

```json
{
  "properties": {
    "displayName": "Audit diagnostic settings for Key Vault",
    "policyType": "Custom",
    "mode": "All",
    "policyRule": {
      "if": {
        "field": "type",
        "equals": "Microsoft.KeyVault/vaults"
      },
      "then": {
        "effect": "auditIfNotExists",
        "details": {
          "type": "Microsoft.Insights/diagnosticSettings",
          "existenceCondition": {
            "allOf": [
              { "field": "Microsoft.Insights/diagnosticSettings/logs.enabled", "equals": "true" },
              { "field": "Microsoft.Insights/diagnosticSettings/workspaceId", "exists": "true" }
            ]
          }
        }
      }
    }
  }
}
```

**Qué hace**: para cada Key Vault, Azure busca un recurso hijo `Microsoft.Insights/diagnosticSettings` con `logs.enabled` y un `workspaceId`. Si no existe, marca el Key Vault como **non-compliant** (no lo bloquea).

**Por qué `auditIfNotExists` y no `deny`**: `deny` evalúa solo las propiedades del recurso que se crea (en el momento del `PUT`). Pero diagnostic settings son un **recurso hijo separado** que suele crearse después. `auditIfNotExists` evalúa el estado conjunto en el barrido periódico. Para forzar la creación, usarías `deployIfNotExists` que **auto-remedia** desplegando el diagnostic setting.

## 5. Comparación con una SCP de AWS

| Dimensión | AWS SCP | Azure Policy |
|-----------|---------|--------------|
| Formato | JSON IAM policy | JSON `policyDefinition` |
| Lenguaje de condición | `Condition` con operadores IAM (`StringNotEquals`, etc.) | `policyRule.if` con `field`/`value`/`allOf`/`anyOf` |
| Scope de aplicación | Attached a OU o cuenta | Assigned a MG, Subscription o RG |
| Herencia | Descendente intersectiva | Descendente acumulativa |
| Efectos | `Deny`, `Allow` (poco útil) | `deny`, `audit`, `append`, `modify`, `deployIfNotExists`, `auditIfNotExists` |
| Autoremediación | No | Sí (`deployIfNotExists` + Managed Identity) |
| Default | Todo denegado si no hay `FullAWSAccess` | Todo permitido si no hay policy |
| Evaluación | En el momento de la acción | En el momento del ARM PUT + barrido periódico 24h |

**Diferencia práctica más grande**: Azure Policy tiene **efectos activos** (`deployIfNotExists`, `modify`) que AWS SCP no tiene. Las SCPs solo pueden denegar; Azure Policy puede remediar.

## 6. Operadores comunes en `policyRule.if`

| Operador | Qué hace | Ejemplo |
|----------|----------|---------|
| `field` | Referencia una propiedad del recurso evaluado. | `{ "field": "location", "equals": "westeurope" }` |
| `value` | Evalúa una expresión. | `{ "value": "[length(field('tags'))]", "greater": 0 }` |
| `allOf` | AND lógico. | `{ "allOf": [cond1, cond2] }` |
| `anyOf` | OR lógico. | `{ "anyOf": [cond1, cond2] }` |
| `not` | NOT lógico. | `{ "not": cond1 }` |
| `exists` | ¿la propiedad existe? | `{ "field": "tags['env']", "exists": "true" }` |
| `in` / `notIn` | Pertenencia a lista. | `{ "field": "location", "in": ["westeurope"] }` |
| `like` / `match` | Pattern matching glob/regex. | `{ "field": "name", "like": "prod-*" }` |

## 7. Qué llevarse

- Una `policyDefinition` es declarativa, versionable y auditable.
- `deny` es el equivalente del `SCP Deny`; úsalo con pruebas en Sandbox primero.
- `auditIfNotExists` y `deployIfNotExists` **no tienen equivalente directo en SCPs**; son herramientas únicas de Azure que compensan la ausencia de allow-list nativa.
- Siempre documentar `description` claro — alguien va a leerlo cuando una creación se bloquee.
