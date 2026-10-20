# Postmortem — INC-2026-0417-01 Agotamiento del pool de conexiones a PostgreSQL

> Documento de referencia. Es el **ejemplo resuelto** que corresponde al escenario de
> `incident/scenario.md`. Úsalo como auto-check después de llenar tu propia versión
> con `postmortem/TEMPLATE.md`.

---

## 1. Summary

El 2026-04-17 entre 14:03 y 14:50 UTC, el servicio `tasks-api` sufrió degradación severa:
la p95 de latencia subió de 180 ms a 2.1 s y la tasa de error alcanzó 4.7 %. La causa
inmediata fue el agotamiento del pool de conexiones a PostgreSQL, disparado por un
endpoint nuevo (`GET /tasks/search`) desplegado en la versión `v2.4.1` que ejecuta
`ILIKE` sin índice sobre una tabla de 1.8 M filas.

La mitigación efectiva fue deshabilitar el endpoint vía feature flag
(`SEARCH_ENABLED=false`) a las 14:35 UTC. El pool se recuperó en 90 segundos y los
SLOs volvieron a verde a las 14:50 UTC.

- **Severity:** SEV-2 (user-visible, degradación parcial, no outage total)
- **Status:** Resolved
- **Owner del postmortem:** `platform-team`
- **Fecha del incidente:** 2026-04-17
- **Fecha del postmortem:** 2026-04-21
- **Duración detectada → mitigada:** 00:32 (14:03 → 14:35)

## 2. Impact

- Usuarios afectados: ~1 200 sesiones únicas con al menos un error.
- Requests fallidas (5xx): 8 400 sobre 180 000 totales en la ventana (4.7 %).
- Revenue / coste: estimado < 500 USD; `tasks-api` no es transaccional directo.
- SLO burn: 11 % del error budget mensual consumido en 47 minutos.
- Datos perdidos / corruptos: ninguno. Las escrituras seguían funcionando;
  los 5xx eran timeouts del pool antes de ejecutar la query.

## 3. Timeline (UTC)

| Hora  | Evento | Fuente |
|-------|--------|--------|
| 13:45 | Argo CD marca `v2.4.1` como Healthy; rollout completo. | argocd events |
| 13:58 | Primer request a `/tasks/search` tarda 1.9 s. | Grafana RED metrics |
| 14:01 | Conexiones DB en uso: 12 → 48 en 90 s. | panel `postgres/connections` |
| 14:03 | Alerta `HighRequestLatency` dispara (p95 > 1 s por 2 min). | Alertmanager |
| 14:04 | PagerDuty pagina a `oncall-platform`. | PagerDuty log |
| 14:07 | On-call acusa recibo; abre war-room en `#inc-20260417`. | Slack |
| 14:12 | Rollback a `v2.4.0` queda en `Progressing`; pods viejos tampoco drenan. | argocd |
| 14:18 | Escalado 3 → 6 réplicas empeora: PostgreSQL rechaza con `remaining connection slots`. | pg logs |
| 14:22 | Reducción a 2 réplicas + `max_overflow=0`. Latencia baja a 600 ms. | kubectl |
| 14:30 | Identificado `/tasks/search` como culpable con query LogQL. | Loki |
| 14:35 | Patch con `SEARCH_ENABLED=false`. Pool se vacía en 90 s. | kubectl |
| 14:50 | p95 vuelve a 220 ms; error rate < 0.1 %. | Grafana |
| 15:10 | Status page a Operational; war-room cerrado. | statuspage |

## 4. Detection

- Alerta: `HighRequestLatency` (warning) a las 14:03, elevada a page a los 2 min.
- Fue proactiva (alerta disparó antes del primer reporte de usuario).
- *Time to detect* desde inicio real del impacto (13:58 UTC): **5 minutos**.
- La alerta `HighErrorRate` (critical) disparó más tarde (14:11), demasiado tardía
  dado que ya se estaba paginando por latencia — ver AI-04.

## 5. Trigger

Rollout de `v2.4.1` a las 13:45 UTC que incluía el endpoint `/tasks/search`,
amplificado por un anuncio interno de producto que multiplicó por ~5 el tráfico al
nuevo endpoint durante los primeros 20 minutos.

El rollout en sí fue sano (health checks pasaron). El trigger operativo es el *tráfico
inducido* sobre un endpoint que no soportaba su propia carga.

## 6. Root cause

- **Síntoma:** p95 subió a 2.1 s, 4.7 % de requests fallando con 5xx.
- **Porque 1:** El pool de conexiones de SQLAlchemy se saturó (10 + 10 overflow por réplica).
- **Porque 2:** Las queries de `/tasks/search` tardaban 300–900 ms cada una, sosteniendo
  conexiones mucho más tiempo que la media (~15 ms del resto de endpoints).
- **Porque 3 (causa raíz técnica):** No existe índice sobre `tasks.title` apto para
  `ILIKE '%texto%'`. Cada búsqueda hace un *seq scan* de 1.8 M filas. Sin un índice
  `gin` con `pg_trgm`, el patrón `%foo%` no es indexable.
- **Causa raíz de proceso:** El PR del endpoint no pasó por un gate de carga obligatorio
  por PR. El pipeline tiene un *load test* nocturno, pero el PR mergeó al mediodía y se
  desplegó antes de la siguiente corrida. Adicionalmente, el runbook anterior "DB lenta"
  no listaba pool exhaustion como hipótesis, lo que generó ~8 min de falsas pistas.

## 7. Resolution

Mitigaciones (ordenadas por lo que realmente ayudó):

1. **(FIX efectivo)** `kubectl set env deploy/tasks-api SEARCH_ENABLED=false` — a las
   14:35, deshabilita el endpoint con feature flag. Mitigación.
2. **(Ayudó parcial)** `kubectl patch deployment tasks-api --patch '{"spec":{"replicas":2}}'`
   a las 14:22 — reduce la presión total sobre el pool. Mitigación paliativa.
3. **(No ayudó)** `argocd app rollback tasks-api` a las 14:12 — se quedó `Progressing`
   porque los pods viejos tampoco podían drenar sus conexiones ocupadas.
4. **(Empeoró)** Escalado a 6 réplicas a las 14:18 — multiplicó la demanda sobre
   `max_connections=100` del RDS. Lección registrada.

Fix definitivo (fuera de la ventana del incidente, abierto como AI-01):

```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX CONCURRENTLY idx_tasks_title_trgm
  ON tasks USING gin (title gin_trgm_ops);
```

## 8. What went well

- La alerta `HighRequestLatency` disparó solo 5 min después del inicio del impacto.
- El feature flag `SEARCH_ENABLED` **existía** (buena práctica de la etapa 11).
  Sin él, la mitigación habría requerido un rollback real que no funcionaba.
- La comunicación en el war-room fue puntual: timestamp cada decisión importante.
- Los logs estructurados permitieron localizar el endpoint culpable en una sola query.

## 9. What went wrong

- El rollback vía Argo CD no funcionó porque los pods viejos heredan el problema de
  "pool ocupado", y Argo CD no mata conexiones activas al cambiar de versión.
- El escalado horizontal fue instintivo y empeoró el incidente al chocar con
  `max_connections` del RDS. No hubo un gate que lo impidiera.
- El dashboard de "connections in use" existía pero no estaba en el panel principal
  del equipo, por lo que la hipótesis "upstream Stripe" ganó tiempo que no merecía.
- La alerta de `HighErrorRate` disparó 8 min después que la de latencia, aunque la
  tasa de error ya era > 1 % mucho antes.
- No había gate de carga por PR; solo el nocturno.

## 10. Where we got lucky

- El incidente cayó en horario de oficina. En madrugada, el on-call habría tardado
  más en identificar el endpoint culpable sin el ambiente del war-room completo.
- La búsqueda era un endpoint *nuevo*, así que no había consumidores dependientes
  encadenados; devolver 503 al endpoint no derribó otros servicios.
- El RDS no se cayó. Varias conexiones en espera no son lo mismo que `max_connections`
  excedido crónicamente; en una ventana mayor, PostgreSQL habría empezado a rechazar
  escrituras y entonces sí perderíamos datos.

## 11. Action items

| ID    | Descripción | Tipo | Severidad | Owner | Due |
|-------|-------------|------|-----------|-------|-----|
| AI-01 | Crear índice `gin + pg_trgm` sobre `tasks.title` vía migración Alembic. | corrective | P0 | `platform-team` | 2026-04-24 |
| AI-02 | Añadir gate de load test por PR para endpoints marcados `@slow_query`. | preventive | P1 | `platform-team` | 2026-05-15 |
| AI-03 | Alertas en `pg_stat_activity.count` > 70 % de `max_connections` por 2 min. | detective | P1 | `sre-team` | 2026-05-01 |
| AI-04 | Reconfigurar `HighErrorRate` para disparar a 1 % con ventana 2 min. | detective | P1 | `sre-team` | 2026-04-28 |
| AI-05 | Añadir panel `connections in use` al dashboard principal `tasks-api`. | preventive | P2 | `platform-team` | 2026-04-30 |
| AI-06 | Actualizar runbook de "DB lenta" para incluir pool exhaustion y HPA checklist. | preventive | P1 | `oncall-platform` | 2026-04-25 |

## 12. Lessons learned

Durante años asumimos implícitamente que *agregar réplicas* siempre reduce presión.
En aplicaciones *stateless* con *backends* compartidos de capacidad fija (DB con
`max_connections`, colas con rate limit, APIs upstream con cuotas), escalar
horizontal puede *amplificar* el problema. El HPA por CPU no modela estos límites.
Nuestro mental model necesita incorporar los "cuellos de botella de terceros" como
primera clase, con sus propios SLOs y alertas.

En segundo lugar, confirmamos que la práctica de *feature flags por endpoint* (que
introdujimos en la etapa 11) tiene retorno de inversión altísimo: fue la diferencia
entre un incidente de 47 min y uno potencialmente de horas. Vale la pena extender la
convención a cualquier endpoint que toque un recurso compartido (DB, cache, cola).

Finalmente, los dashboards son *árbol de decisión*, no catálogo. Si una señal
relevante no está en el panel principal del servicio, no existe operacionalmente.

## 13. Supporting data

- Dashboard snapshot (Grafana): `grafana/d/tasks-api/overview?from=1744900980000&to=1744905600000`
- Dashboard `postgres/connections`: `grafana/d/postgres-main/connections?from=1744900980000&to=1744905600000`
- Query PromQL (correlación por path):

  ```promql
  sum by (path) (
    rate(http_request_duration_seconds_count{service="tasks-api",status=~"5.."}[5m])
  )
  ```

- Query LogQL (burst de errores de pool):

  ```logql
  sum(count_over_time({app="tasks-api", level="error"} |= "QueuePool limit" [5m]))
  ```

- PR del endpoint (`v2.4.1`): `#4211` (hipotético, link en Backstage).
- PR del índice (AI-01): `#4237`.
- Runbook: `runbook/db-pool-exhaustion.md` (actualizado tras este incidente).
