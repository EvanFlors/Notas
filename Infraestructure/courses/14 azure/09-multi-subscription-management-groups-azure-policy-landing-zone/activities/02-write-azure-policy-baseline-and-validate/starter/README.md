# Starter — az-09-02

Esta actividad **no** tiene starter de código. Debes escribir los 3 JSON desde cero.

## Pasos

1. Crea el directorio de trabajo:

   ```bash
   mkdir -p /tmp/az-09-policy
   cd /tmp/az-09-policy
   ```

2. Crea los 3 archivos:
   - `policy-deny-locations.json`
   - `policy-deny-public-ip.json`
   - `policy-audit-diagnostic-settings.json`

3. Crea `README-INTENT.md` con una sección por policy.

4. Valida:

   ```bash
   bash <ruta-al-modulo>/activities/02-write-azure-policy-baseline-and-validate/tests/validate.sh /tmp/az-09-policy
   ```

5. Compara con `solution/*.json` y `solution/README-INTENT.md` para autoevaluación.

## Skeleton mínimo de un policyDefinition

```json
{
  "properties": {
    "displayName": "<nombre humano>",
    "policyType": "Custom",
    "mode": "All",
    "description": "<qué hace y por qué>",
    "metadata": {
      "category": "<Network|General|Monitoring|...>",
      "version": "1.0.0"
    },
    "parameters": {},
    "policyRule": {
      "if": { "<condition>": "..." },
      "then": {
        "effect": "<deny|audit|auditIfNotExists|deployIfNotExists|modify|append>"
      }
    }
  }
}
```

Útil tener a mano:

- `jq .` para validar JSON: `jq . policy-deny-locations.json`
- `jq -r .properties.policyRule.then.effect policy-deny-locations.json` para inspeccionar un campo.
- Referencia: `../../../examples/02-azure-policy-anatomy/README.md`.
