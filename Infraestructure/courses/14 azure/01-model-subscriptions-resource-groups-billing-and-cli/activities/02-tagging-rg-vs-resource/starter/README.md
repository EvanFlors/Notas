# Starter — az-01-02-tagging-rg-vs-resource

Esta actividad es **independiente**: produces 3 archivos JSON + 1 Markdown.

## Pasos

1. Lee `../README.md` completo y recorre `../../examples/02-rg-delete-cascades/`.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/az-01-tagging
   cd /tmp/az-01-tagging
   ```
3. Escribe los 3 archivos JSON (nombres exactos):
   - `tags-rg.json`
   - `tags-resource.json`
   - `tag-policy.json`
4. Verifica que son JSON válidos:
   ```bash
   for f in tags-rg.json tags-resource.json tag-policy.json; do
     echo "--- $f"; jq . "$f" >/dev/null && echo OK
   done
   ```
5. Escribe `README-INTENT.md` con 4 secciones (`## tags-rg`, `## tags-resource`, `## tag-policy`, `## Herencia`).
6. Valida:
   ```bash
   bash <ruta-repo>/courses/azure/01-model-subscriptions-resource-groups-billing-and-cli/activities/02-tagging-rg-vs-resource/tests/validate.sh /tmp/az-01-tagging
   ```
7. Compara con `../solution/REFERENCE.md` para autoevaluarte.

## Esqueletos útiles

### `tags-rg.json`

```json
{
  "env": "dev",
  "owner": "team-checkout",
  "cost-center": "CC-1234",
  "workload": "checkout",
  "managed-by": "terraform"
}
```

### `tags-resource.json`

```json
{
  "component": "blob-storage",
  "data-classification": "internal",
  "backup-policy": "daily-7d"
}
```

### `tag-policy.json` (sketch)

```json
{
  "properties": {
    "displayName": "Require env tag on resources",
    "policyType": "Custom",
    "mode": "Indexed",
    "parameters": {},
    "policyRule": {
      "if": { "field": "tags['env']", "exists": "false" },
      "then": { "effect": "audit" }
    }
  }
}
```
