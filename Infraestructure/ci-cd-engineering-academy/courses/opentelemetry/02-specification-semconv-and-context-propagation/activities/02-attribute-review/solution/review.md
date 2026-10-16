# Reference review — otel-02-02

Format: `<name>: <RESOURCE|SEMCONV|CUSTOM_OK|REJECT> -- <reason>`

1. service.name: **RESOURCE** -- obligatorio por spec; identifica el productor.
2. service.version: **RESOURCE** -- recomendado; útil para correlacionar regresiones con release.
3. deployment.environment: **RESOURCE** -- separa prod / staging / dev en el backend.
4. k8s.pod.name: **RESOURCE** -- lo idóneo es dejar que lo adjunte el `k8sattributes` processor del Collector, no el SDK; aun así se acepta.
5. http.request.method: **SEMCONV** -- current HTTP semconv v1.
6. http.response.status_code: **SEMCONV** -- current HTTP semconv v1.
7. url.full: **REJECT** -- contiene `?token=abc123` → **PII/secreto en query string**. Emitir `url.path` + redactar query, o aplicar `redaction` processor.
8. server.address: **SEMCONV** -- current HTTP semconv v1.
9. userEmail: **REJECT** -- es **PII** sin cifrar; además camelCase (nombre fuera de convención). Nunca en spans.
10. request_id: **REJECT** -- **alta cardinalidad** (UUID por request) y además redundante con `trace_id`; usar `trace_id` para correlación.
11. acme.cart.item_count: **CUSTOM_OK** -- prefijado por organización (`acme.*`), de baja cardinalidad, útil para dominio.
12. acme.cart.total_cents: **CUSTOM_OK** -- idem; dominio claro, unidad explícita en el nombre.
13. password: **REJECT** -- **secreto en claro**. Jamás.
14. http.method: **REJECT** -- **deprecated** (migrado a `http.request.method`). Eliminar para no duplicar; dejar sólo el nuevo.
15. timestampMs: **REJECT** -- redundante con `start_time` del span; camelCase; cambia por request (alta cardinalidad si acaba en label).

## Final clean list

- service.name
- service.version
- deployment.environment
- k8s.pod.name (idealmente añadido por el Collector)
- http.request.method
- http.response.status_code
- url.path (reemplaza url.full tras redactar query)
- server.address
- acme.cart.item_count
- acme.cart.total_cents

## Notes

- Añadir un `redaction` o `attributes` processor en el Collector como última red para `url.full`, `*.email`, `password`.
- Documentar la convención: todos los atributos custom deben prefijarse `acme.*`.
- Lint CI: fallar PRs que introduzcan atributos con nombres `camelCase` o que contengan los substrings `email`, `password`, `token`, `ssn`.
