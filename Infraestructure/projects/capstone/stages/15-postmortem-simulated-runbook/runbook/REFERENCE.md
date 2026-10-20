# Runbook — DB connection pool exhaustion (tasks-api → PostgreSQL)

> Documento de referencia. Es el runbook canónico derivado del incidente
> `INC-2026-0417-01`. Léelo después de tu propia versión (TEMPLATE.md).

---

## Metadata

| Campo | Valor |
|---|---|
| Runbook ID | `RB-db-pool-exhaustion` |
| Última revisión | 2026-04-25 |
| Owner | `oncall-platform` |
| Services afectados | `tasks-api`, `tasks-db` (PostgreSQL RDS) |
| Severity típica | SEV-2 (puede escalar a SEV-1 si impacta escrituras) |
| Postmortems relacionados | `INC-2026-0417-01` |

## 1. Symptoms

Este runbook aplica cuando ves **todo esto a la vez**:

- Alerta `HighRequestLatency` para `service="tasks-api"` activa.
- Dashboard primario: `grafana/d/tasks-api/overview` muestra p95 > 1 s subiendo rápido.
- Dashboard de soporte: `grafana/d/postgres-main/connections` muestra "connections in use"
  cercano al 80 % de `max_connections` o creciendo &gt; 1 conn/s.
- Patrón de logs (grep en Loki):

  ```logql
  {app="tasks-api", level="error"} |= "QueuePool limit"
  ```

  devuelve recuento creciente. También puede aparecer:
  `FATAL: remaining connection slots are reserved`.

**Qué NO es (desambigua):**

- Si **solo** sube la latencia y las conexiones DB están estables → runbook
  `RB-upstream-dependency-slow` (upstream HTTP lento).
- Si disparó `CertExpiringSoon` → runbook `RB-cert-rotation`.
- Si Argo CD marcó la app como `Degraded` justo antes de los síntomas → runbook
  `RB-bad-deploy-rollback`.

## 2. Diagnostics

### Diagnóstico 1 — Confirmar que el pool está saturado

```bash
kubectl -n prod logs deploy/tasks-api --since=5m \
  | grep -c "QueuePool limit of size"
```

- Expected (sano): `0`.
- Bad (confirmado): &gt; 50 ocurrencias en 5 min.

### Diagnóstico 2 — Confirmar que la DB es la víctima, no la causa remota

```bash
# Si tienes acceso al RDS:
psql -h "$PG_HOST" -U readonly -c "
  SELECT state, count(*) FROM pg_stat_activity
  WHERE datname='capstone' GROUP BY state ORDER BY 2 DESC;"
```

- Expected (sano): `idle` dominante, `active` &lt; 10.
- Bad: `active` + `idle in transaction` cerca o encima del 70 % de `max_connections`.

### Diagnóstico 3 — Localizar el endpoint culpable

```promql
topk(5,
  sum by (path) (
    rate(http_request_duration_seconds_count{service="tasks-api",status=~"5.."}[5m])
  )
)
```

- Bad: &gt; 80 % de los 5xx concentrados en un path. Anótalo.

### Descartes rápidos (&lt; 1 min cada uno)

- Upstream Stripe/Sendgrid: dashboard `grafana/d/deps/overview`. Si está verde, descarta.
- Cert expirado: `kubectl get certificate -A | grep False`. Si vacío, descarta.
- Bad deploy reciente que ya rollbackeó: `argocd app list --output json | jq -r '.[]|select(.status.sync.status!="Synced")|.metadata.name'`. Si vacío, descarta.

## 3. Mitigations

### Mitigación 1 — Deshabilitar el endpoint culpable con feature flag (menos invasiva)

Si identificaste el path culpable y existe un flag para desactivarlo
(convención `<FEATURE>_ENABLED`):

```bash
kubectl -n prod set env deploy/tasks-api <FEATURE>_ENABLED=false
```

- Impacto: ese endpoint devuelve 503; el resto del tráfico sigue sano.
- Efecto visible: pool se vacía en 60–120 s en `postgres/connections`.
- No hagas: desactivar un flag no relacionado "por si acaso" — complica el postmortem.

### Mitigación 2 — Reducir réplicas y max_overflow

Si no hay feature flag disponible:

```bash
kubectl -n prod scale deploy/tasks-api --replicas=2
kubectl -n prod set env deploy/tasks-api SQLALCHEMY_MAX_OVERFLOW=0
```

- Impacto: baja throughput global, pero evita saturar `max_connections` del RDS.
- Efecto visible: en 2–3 min, "connections in use" baja a &lt; 40 por réplica.
- No hagas: `scale --replicas=6+` *antes* de atacar el pool. Multiplicar réplicas
  sobre un backend con `max_connections` fijo **empeora** el incidente
  (confirmado en INC-2026-0417-01, mitigación 4).

### Mitigación 3 — Last resort: modo mantenimiento

```bash
kubectl -n prod apply -f manifests/maintenance-mode.yaml
```

Devuelve 503 global con `Retry-After: 300`. Úsalo solo si Mitigación 1 y 2 fallan y
el pool está rechazando también lecturas simples.

## 4. Escalation

- **¿Cuándo escalar?** Si tras aplicar Mitigación 1 (o 2 si no hay flag) el síntoma
  persiste > 10 min, o si `pg_stat_activity` reporta &gt; 90 % de `max_connections`
  sostenido &gt; 5 min.
- **A quién:**
  - L2: `#oncall-platform` + page secundario (rol `platform-sre-secondary`).
  - L3 (DBA / RDS vendor): abrir caso con `aws-support` severity *production system
    impaired*; mencionar `max_connections` y `pg_stat_activity.state` observados.
- **Canal:** war-room en `#inc-<YYYYMMDD>`, pager vía PagerDuty.
- **Contexto a llevar:**
  1. Timeline hasta ahora (copiar del war-room).
  2. Mitigaciones intentadas y su efecto medible.
  3. Dashboards abiertos (link con tiempo congelado).
  4. Snapshot de `pg_stat_activity` (CSV).

## 5. Recovery

Mitigar es parar el sangrado; recuperar es cerrar la causa raíz.

- Mergear la migración Alembic que crea el índice adecuado al endpoint culpable.
  Ejemplo para `/tasks/search`:

  ```sql
  CREATE EXTENSION IF NOT EXISTS pg_trgm;
  CREATE INDEX CONCURRENTLY idx_tasks_title_trgm
    ON tasks USING gin (title gin_trgm_ops);
  ```

  Usar `CONCURRENTLY` para no bloquear la tabla en producción.
- Rehabilitar el feature flag con Argo Rollouts al 10 % de tráfico primero;
  observar 15 min antes de progresar.
- Revisar el HPA: añadir métrica custom "connections in use por réplica" si el
  equipo decide seguir escalando por tráfico de queries largas.

## 6. Verification

- [ ] Alerta `HighRequestLatency` **resuelta** en Alertmanager (estado `inactive`),
      no silenciada manualmente.
- [ ] p95 &lt; 400 ms sostenido 10 min en `grafana/d/tasks-api/overview`.
- [ ] Error rate &lt; 0.1 % sostenido 10 min.
- [ ] "Connections in use" &lt; 30 por réplica en `grafana/d/postgres-main/connections`.
- [ ] 0 ocurrencias de `QueuePool limit` en los últimos 10 min (LogQL).
- [ ] Status page a Operational; mensaje de cierre en el war-room; resumen a
      stakeholders por el canal pactado.

## 7. Post-incident

- [ ] Abrir postmortem con `postmortem/TEMPLATE.md` dentro de 24 h.
- [ ] Revisar este runbook: ¿faltó algún diagnóstico? ¿sobró algún paso? ¿orden mal?
- [ ] Si el runbook falló (p.ej. una mitigación no funcionó), registrar el aprendizaje
      en "What went wrong" del postmortem y abrir action item para arreglarlo aquí.

---

## Changelog del runbook

| Fecha | Autor | Cambio |
|---|---|---|
| 2026-04-25 | `oncall-platform` | Creado tras INC-2026-0417-01. |
| 2026-04-28 | `sre-team` | Añadido Diagnóstico 3 (localizar endpoint con topk PromQL). |
