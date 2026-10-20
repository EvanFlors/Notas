# API reference

API REST del `checkout-service`. Contract completo en `docs/api/openapi.yaml` (no incluido en esta referencia mínima).

| Endpoint | Method | Descripción |
|----------|--------|-------------|
| `/health` | GET | Health check. |
| `/checkout` | POST | Procesa un carrito. `202 Accepted` + `location`. |
| `/orders/{id}` | GET | Devuelve una orden. `404` si no existe. |

Para generar la referencia interactiva, añade al `mkdocs.yml`:

```yaml
plugins:
  - techdocs-core
  - render_swagger
```

Y en esta página:

```markdown
!!swagger openapi.yaml!!
```
