# Escenario inyectado — Agotamiento del pool de conexiones a PostgreSQL

> Lee este documento **antes** de abrir las plantillas de postmortem o runbook.
> El escenario es ficticio pero las señales (métricas, logs, timestamps) son plausibles
> y corresponden al stack construido en las etapas 1–14.

---

## 0. Metadata

| Campo | Valor |
|---|---|
| Incident ID | `INC-2026-0417-01` |
| Fecha | 2026-04-17 (jueves) |
| Severity | SEV-2 (user-visible, no total outage) |
| Services | `tasks-api` (FastAPI), `tasks-db` (PostgreSQL 16) |
| On-call primary | `oncall-platform` (nombre rotativo, no personal) |
| Status page | Degraded performance 14:07–15:10 UTC |
| Capstone stages | 1-14 ya desplegadas en el cluster `prod-east-1` |

---

## 1. Contexto previo (lo que estaba pasando antes del fallo)

- A las **13:45 UTC** se completa el rollout del release `v2.4.1` vía Argo CD. Trae un endpoint nuevo `GET /tasks/search?q=<text>` que ejecuta `SELECT ... WHERE title ILIKE '%'||$1||'%'` sobre la tabla `tasks` (1.8M filas).
- El equipo de producto hace un pequeño anuncio interno sobre el nuevo buscador, lo que dispara ~5x el tráfico habitual al endpoint durante los primeros 20 min.
- La configuración del pool viene de la etapa 7:
  - `pool_size = 10`
  - `max_overflow = 10`
  - `pool_timeout = 30s`
  - Total posible: 20 conexiones por réplica × 3 réplicas = 60.
- El límite de `max_connections` en el PostgreSQL RDS es **100**.
- El SLO publicado para `tasks-api`:
  - `p95 latency < 400 ms` sobre ventana 28d.
  - `success rate > 99.5%` sobre ventana 28d.
  - *Error budget* restante al inicio del día: **38%**.

---

## 2. Timeline observada (desde Grafana + Loki + PagerDuty simulado)

```
13:45 UTC — Argo CD marca v2.4.1 como Healthy. Deploy OK.
13:58 UTC — Primer request /tasks/search tarda 1.9s (p95 habitual: 180ms).
14:01 UTC — Panel "DB connections in use" sube de 12 a 48 en 90 segundos.
14:03 UTC — Alertmanager dispara `HighRequestLatency` (p95 > 1s por 2 min).
14:04 UTC — PagerDuty pagina a oncall-platform.
14:07 UTC — oncall-platform acusa recibo, abre war-room en Slack #inc-20260417.
14:09 UTC — Primera hipótesis: "upstream (Stripe) lento". Descartada en 2 min:
            dashboard de dependencies muestra Stripe sano.
14:12 UTC — Intento de rollback a v2.4.0 vía `argocd app rollback tasks-api`.
            El rollback queda `Progressing` 4 min porque los pods viejos
            tampoco pueden drenar: siguen esperando conexiones.
14:18 UTC — Se escala tasks-api de 3 → 6 réplicas pensando que "faltan workers".
            Error: multiplica el consumo de conexiones a 120 pedidas sobre 100 permitidas.
            PostgreSQL empieza a rechazar con "FATAL: remaining connection slots are reserved".
14:22 UTC — Se reduce a 2 réplicas y se baja `max_overflow` a 0 vía ConfigMap patch.
            Latencia se estabiliza en 600ms (todavía fuera de SLO pero no en caída libre).
14:30 UTC — Se identifica el endpoint culpable grepeando logs:
              {app="tasks-api"} |= "GET /tasks/search" | duration > 1s
            Count: 2143 requests en los últimos 15 min.
14:35 UTC — Se despliega un `kubectl patch deployment tasks-api` con un flag de feature
            `SEARCH_ENABLED=false` que devuelve 503 en /tasks/search.
            Pool se recupera a <20 conexiones en uso en 90 segundos.
14:50 UTC — p95 vuelve a 220ms. Error rate < 0.1%.
15:10 UTC — Status page pasa a "Operational". Se cierra el war-room.
```

---

## 3. Síntomas iniciales (lo que vio la guardia a las 14:07)

Alertas disparadas:

- `HighRequestLatency` (severity: warning → page a los 2 min).
- `HighErrorRate` (severity: critical) a las 14:11 UTC.

Dashboards relevantes:

- `tasks-api / RED metrics`: p95 subió de 180ms a 2.1s. Error rate del 0.03% al 4.7%.
- `postgres / connections`: conexiones usadas pasaron de 15 a 92 (de un max de 100).
- `tasks-api / logs`: aumento de 300x en entradas con `sqlalchemy.exc.TimeoutError: QueuePool limit of size 10 overflow 10 reached`.

Nada obvio en:

- CPU/mem de los pods (dentro de rangos normales).
- Métricas de red del cluster.
- Latencia de upstream dependencies (Stripe, Sendgrid).

---

## 4. Datos para análisis forense

Snippets reales que el estudiante debe usar como fuente:

**Log línea exacta (Loki):**

```
2026-04-17T14:03:12Z ERROR [sqlalchemy.pool.impl.QueuePool]
  QueuePool limit of size 10 overflow 10 reached, connection timed out,
  timeout 30.00  (Background on this error at: https://sqlalche.me/e/20/3o7r)
```

**Query PromQL que confirma correlación con el endpoint:**

```promql
sum by (path) (
  rate(http_request_duration_seconds_count{service="tasks-api",status=~"5.."}[5m])
)
```

Resultado: 94% de los 5xx concentrados en `path="/tasks/search"`.

**Query LogQL que mide burst:**

```logql
sum(count_over_time({app="tasks-api", level="error"} |= "QueuePool limit" [5m]))
```

Resultado: pico de 1420 errores/5min a las 14:08.

**Explain plan del query culpable:**

```
EXPLAIN SELECT * FROM tasks WHERE title ILIKE '%foo%';
                            QUERY PLAN
--------------------------------------------------------------
 Seq Scan on tasks  (cost=0.00..52419.00 rows=180 width=312)
   Filter: (title ~~* '%foo%'::text)
```

**Causa raíz técnica:**

- No hay índice sobre `tasks.title` (ni `pg_trgm` para `ILIKE`), así cada búsqueda hace *seq scan* de 1.8M filas (~300–900ms en el pod).
- `pool_timeout = 30s` significa que requests encolados esperan hasta 30s antes de fallar: la cola crece más rápido de lo que se vacía.
- El autoscaler horizontal (HPA) está configurado por **CPU**, no por "connections in use" ni "request queue length": no reacciona.

**Causa raíz de proceso:**

- El PR del endpoint fue aprobado sin un *load test* específico. Hay un check de carga nocturno pero no un gate por PR.
- El runbook anterior ("DB lenta") no mencionaba agotamiento de pool como posibilidad, así que la guardia perdió ~8 min en falsas pistas.
- El dashboard de `connections in use` existía pero no estaba en el panel principal del equipo.

---

## 5. Impacto cuantificado

- Ventana degradada: 14:03 → 14:50 UTC ≈ **47 minutos**.
- Requests fallidas (5xx): ~**8 400** sobre ~180 000 totales en la ventana (≈ **4.7%**).
- Usuarios afectados estimados: **~1 200** (sesiones únicas con ≥ 1 error).
- *Error budget* consumido: ~**11%** del presupuesto mensual en una sola ventana.
- Revenue impact: no se midió formalmente; se estima en < $500 (la app no es de transacción directa).

---

## 6. Nota sobre reproducción

> `incident/trigger.sh` **no se incluye**. La etapa es documental: no requiere que el estudiante
> ejecute el fallo en una infraestructura viva, y asumir que `kind` + PostgreSQL están presentes
> excedería el scope ("stages 1–14 asumidos como hechos"). Si quisieras reproducirlo real en
> un entorno de staging, los ingredientes son: desplegar `v2.4.1`, inyectar carga con
> `hey -z 15m -c 50 'http://<svc>/tasks/search?q=aa'` y observar `pg_stat_activity`.
