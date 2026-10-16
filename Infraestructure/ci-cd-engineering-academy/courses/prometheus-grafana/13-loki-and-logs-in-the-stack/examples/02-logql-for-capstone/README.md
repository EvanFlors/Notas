# Ejemplo 02 — LogQL para el capstone

Colección comentada de queries LogQL que resuelven los casos típicos del capstone (una API HTTP que loguea JSON).

Ver [`queries.logql`](queries.logql) para la lista ejecutable.

## Supuestos

- La API loguea JSON por stdout con los campos `level`, `msg`, `path`, `status`, `duration_ms`, `request_id`.
- Alloy promueve `app`, `env`, `instance` como labels del stream.

## Casos cubiertos

1. **Filtro básico por app**.
2. **Errores en los últimos 5 min**.
3. **Error rate como serie temporal** (log-based metric).
4. **Top 5 paths con más errores**.
5. **p95 de latencia derivada del log** (requiere `unwrap`).
6. **Reformatear la línea** para presentar `[request_id] msg (duration ms)`.
7. **Excluir ruido de healthchecks**.
8. **Comparar hoy vs ayer** con `offset`.
9. **Alerta sobre `panic`** en cualquier app.

## Correrlas

Si tienes el ejemplo 01 arriba, pégalas en Grafana → Explore → Loki.

Sin stack: `grep` sobre `queries.logql` sirve de referencia.
