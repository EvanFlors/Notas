# SLOs del pipeline OTel — solución ejemplo

> Esta es *una* solución coherente, no la única. Las cifras son defendibles pero no "correctas" en abstracto.

## SLIs

1. **Availability (gateway up)** — ¿el gateway Collector está procesando datos?
   - Métrica: `rate(otelcol_exporter_sent_spans[5m]) > 0` por instancia.
2. **Loss rate** — ¿qué fracción de spans que entraron se perdieron en el pipeline?
   - Métrica: `sum(rate(otelcol_exporter_send_failed_spans[5m])) / sum(rate(otelcol_receiver_accepted_spans[5m]))`.
3. **Freshness (end-to-end latency)** — ¿cuánto demora un span desde que entra al agent hasta que el backend confirma recepción?
   - Métrica: `histogram_quantile(0.99, sum by (le) (rate(otelcol_exporter_send_duration_bucket[5m])))` (p99 del batch send, proxy razonable).
4. **Saturation (queue depth)** — ¿qué fracción de la cola está ocupada?
   - Métrica: `otelcol_exporter_queue_size / otelcol_exporter_queue_capacity`.

## SLOs

| SLI | SLO | Ventana |
|-----|-----|---------|
| Availability | 99.9% (nunca más de 43 min de gateway "muerto" al mes) | 30 días rolling |
| Loss rate | < 0.1% de spans perdidos | 30 días rolling |
| Freshness | p99 send duration < 2s | 30 días rolling |
| Saturation | queue_size / capacity < 0.5 en p95 | 7 días rolling |

**Por qué 99.9 y no 99.99**: el Collector es un sistema interno; nueve-nines-trough es caro (requiere HA, PVC RWX, blue/green permanente). 99.9 es "profesional sin heroísmo".

## Error Budget

Mensual (30 días = 43 200 min):

- Availability 99.9% → budget = 43.2 min de downtime/mes.
- Loss rate 0.1% con 1M spans/min → budget = ~1000 spans/min pérdida (acumulado ~43M spans/mes).

**Escenario 1 — fast burn**: 10 min de outage total consume ~23% del budget → alerta crítica inmediata.

**Escenario 2 — slow burn**: 0.05% drop sostenido durante 20 días consume ~70% del budget → alerta warning, acción en horario hábil.

## Alertas

Ver `alerts.yaml`. Tres alertas:

- `PipelineFastBurn` — consume > 2% del budget en 1h (crítica).
- `PipelineSlowBurn` — consume > 10% del budget en 6h (warning).
- `PipelineQueueSaturated` — queue > 80% capacidad sostenido (warning).

## Playbook

1. **PipelineFastBurn dispara**:
   - Verifica `otelcol_exporter_send_failed_spans` para identificar backend caído.
   - Verifica estado del backend (Mimir/Tempo). Si down, incident en ese sistema primero.
   - Pausa deploys del Collector hasta recuperación.
2. **PipelineSlowBurn dispara**:
   - Revisa alertas de capacidad (CPU/memoria) del gateway.
   - Verifica `otelcol_processor_refused_spans` (memory_limiter activando).
   - Si pattern: considera escalar gateway o subir `limit_mib`.
3. **PipelineQueueSaturated dispara**:
   - Backend lento o insuficiente; verifica métricas del backend.
   - Si crece sin fondo, considerar temporalmente subir `queue_size` o rotear tráfico.
   - Comunicación proactiva a equipos consumidores si vas a perder datos.
