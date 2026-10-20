# Postmortem — INC-2026-0417-01 Pool exhaustion

## 1. Summary

El 2026-04-17 un deploy nuevo rompió la DB. Fue culpa del equipo que no probó
el endpoint. La careless review del PR dejó pasar un query sin índice.

- Severity: SEV-2
- Status: Resolved
- Owner del postmortem: platform-team
- Fecha del incidente: 2026-04-17
- Fecha del postmortem: 2026-04-21
- Duración detectada → mitigada: 00:32

## 2. Impact

Afectó al 4.7% de requests, aproximadamente 8400 fallidas sobre 180000.
Consumió el 11% del error budget mensual. ~1200 usuarios con al menos un error.

## 3. Timeline (UTC)

| Hora  | Evento | Fuente |
|-------|--------|--------|
| 14:03 | Alerta HighRequestLatency dispara | Alertmanager |
| 14:07 | On-call entra al war-room | Slack |
| rollback intentado | argocd |
| 14:35 | Patch feature flag SEARCH_ENABLED=false | kubectl |
| 14:50 | p95 vuelve a 220ms | Grafana |

## 4. Detection

Alerta HighRequestLatency. 5 min desde el inicio del impacto.

## 5. Trigger

Deploy de v2.4.1 que trajo /tasks/search.

## 6. Root cause

- Síntoma: p95 subió a 2.1s.
- Porque 1: pool de conexiones saturado.
- Porque 2: query ILIKE sin índice tarda cientos de ms y sostiene conexiones.
- Porque 3: no existe índice gin + pg_trgm sobre tasks.title.

## 7. Resolution

1. kubectl set env deploy/tasks-api SEARCH_ENABLED=false — mitigación efectiva.
2. kubectl patch replicas=2 y max_overflow=0 — mitigación paliativa.
3. CREATE INDEX CONCURRENTLY ... — fix definitivo (fuera de la ventana).

## 8. What went well

- La alerta disparó rápido.
- El feature flag existía y permitió mitigar sin rollback.
- Los logs estructurados permitieron localizar el endpoint.

## 9. What went wrong

- El rollback no funcionó porque los pods viejos tampoco drenaban.
- El escalado horizontal empeoró el incidente al chocar con max_connections.
- Fue stupid escalar sin medir primero.

## 10. Where we got lucky

- Fue en horario de oficina.
- La búsqueda es un endpoint nuevo sin dependientes aguas abajo.

## 11. Action items

| ID    | Descripción | Tipo | Severidad | Owner | Due |
|-------|-------------|------|-----------|-------|-----|
| AI-01 | Crear índice gin+pg_trgm sobre tasks.title. | corrective | P0 |  |  |
| AI-02 | Añadir gate de load test por PR. | preventive | P1 |  | 2026-05-15 |
| AI-03 | Alerta en pg_stat_activity > 70%. | detective | P1 | sre-team |  |

## 12. Lessons learned

Añadir réplicas no siempre reduce presión. Para backends con capacidad fija (DB,
colas), escalar horizontal puede empeorar. Los feature flags por endpoint son
caros de implementar pero muy baratos cuando llega el incidente.

## 13. Supporting data

- Dashboard: grafana/d/tasks-api/overview
- Query LogQL: {app="tasks-api", level="error"} |= "QueuePool limit"
