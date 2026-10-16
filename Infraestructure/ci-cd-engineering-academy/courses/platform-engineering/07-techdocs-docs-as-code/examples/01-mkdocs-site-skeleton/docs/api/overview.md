# API overview

El servicio expone una API REST pequeña.

| Endpoint | Method | Descripción |
|----------|--------|-------------|
| `/health` | GET | Health check, siempre `200 OK`. |
| `/orders/{id}` | GET | Devuelve una orden por id. `404` si no existe. |

Ver también:

- Contract OpenAPI (si existiera): `docs/api/openapi.yaml`.
- Ejemplos de uso en el [runbook](../runbook/incident-500s.md).
