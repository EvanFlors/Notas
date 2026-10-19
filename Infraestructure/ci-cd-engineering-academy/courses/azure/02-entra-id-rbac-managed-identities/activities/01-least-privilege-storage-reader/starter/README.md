# Starter — az-02-01-least-privilege-storage-reader

Esta actividad es **independiente**: produces 2 archivos JSON + 1 Markdown.

## Pasos

1. Lee `../README.md` completo y recorre `../../examples/03-custom-role-json/`.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/az-02-role
   cd /tmp/az-02-role
   ```
3. Escribe los 2 archivos de role (nombres exactos):
   - `role-storage-blob-reader.json`
   - `role-storage-blob-reader-with-condition.json`
4. Verifica que son JSON válidos:
   ```bash
   for f in role-*.json; do echo "--- $f"; jq . "$f" >/dev/null && echo OK; done
   ```
5. Escribe `README-INTENT.md` con las secciones listadas en `../README.md` §5.3.
6. Valida:
   ```bash
   bash <ruta-repo>/courses/azure/02-entra-id-rbac-managed-identities/activities/01-least-privilege-storage-reader/tests/validate.sh /tmp/az-02-role
   ```
7. Compara con `../solution/` para autoevaluarte.

## Esqueleto base

```json
{
  "Name": "<nombre descriptivo>",
  "Description": "<qué hace y por qué existe>",
  "Actions": [],
  "NotActions": [],
  "DataActions": [
    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read"
  ],
  "NotDataActions": [],
  "AssignableScopes": [
    "/subscriptions/<SUB-UUID-PLACEHOLDER>/resourceGroups/<RG-NAME-PLACEHOLDER>"
  ]
}
```

## Esqueleto con condition (patrón oficial Azure ABAC)

```json
{
  "Name": "<nombre descriptivo> (public prefix only)",
  "Description": "<...>",
  "Actions": [],
  "NotActions": [],
  "DataActions": [
    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read"
  ],
  "NotDataActions": [],
  "AssignableScopes": [
    "/subscriptions/<SUB-UUID-PLACEHOLDER>"
  ],
  "Condition": "((!(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read'})) OR (@Resource[Microsoft.Storage/storageAccounts/blobServices/containers/blobs:path] StringStartsWith 'public/'))",
  "ConditionVersion": "2.0"
}
```

> El validador comprueba sintaxis y presencia de claves mínimas, **no** el effect en una subscription real.
