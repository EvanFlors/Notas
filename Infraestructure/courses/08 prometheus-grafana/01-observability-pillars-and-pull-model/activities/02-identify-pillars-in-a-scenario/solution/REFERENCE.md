# REFERENCIA — obs-01-02-identify-pillars-in-a-scenario

> Esta es **una** solución defendible. El valor está en tu criterio, no en reproducir esta tabla.

## A. Mapeo pregunta → pilar

| # | Pregunta | Pilar primario | Pilar de apoyo | Señal concreta que hace falta |
|---|----------|----------------|----------------|-------------------------------|
| 1 | Patrón temporal (empeorando/estable)       | metrics  | events     | `rate(http_requests_total{service="api-gateway",status=~"5.."}[5m])` graficado con anotación de deploy |
| 2 | ¿Está pasando ahora?                       | metrics  | —          | mismo rate anterior en tiempo real |
| 3 | Qué dijo `bank-adapter` a las 10:14:03     | logs     | traces     | log estructurado con `trace_id`, `req_id`, `acquirer`, `status_code`, mensaje |
| 4 | Dónde se perdió el tiempo en `req_id=def456` | traces | metrics    | spans completos desde `frontend` hasta el upstream `visa-sandbox` |
| 5 | Fallos por `acquirer` en 10 min            | metrics  | logs       | `payment_requests_total{acquirer, status}` como counter (cardinalidad baja: ~5 valores) |
| 6 | Correlación con deploy de 10:10            | events   | metrics    | anotación de deploy en Grafana (events) + rate de errores superpuesto |
| 7 | CPU por función en `bank-adapter`          | profiling| metrics    | perfil continuo (Pyroscope/Parca) correlacionado con release |
| 8 | Patrón `User-Agent` en los fallos          | logs     | traces     | log con `user_agent` indexado O span-attribute (NUNCA label de métrica: cardinalidad explota) |

## B. Lagunas de observabilidad detectadas

### Laguna 1 — No hay `trace_id` propagado entre servicios

**Síntoma durante el incidente:** a las 10:14 no se puede saber qué log de `bank-adapter` corresponde al request que un cliente concreto reporta. Horas de grep manual.

**Pilar afectado:** logs + traces (correlación entre ambos).

**Propuesta concreta:**

- Instrumentar OpenTelemetry en los 4 servicios (frontend, api-gateway, payments, bank-adapter).
- Propagar `traceparent` W3C header entre ellos.
- Logger estructurado que inyecte `trace_id` y `span_id` automáticamente en cada log.
- Cardinalidad: 0 impacto en métricas (los IDs van a logs/traces, no a labels).

### Laguna 2 — Métricas de `payments` no tienen la label `acquirer`

**Síntoma durante el incidente:** a las 10:17 preguntan "cuántos por acquirer" y nadie puede responder desde PromQL. Vuelven a grep.

**Pilar afectado:** metrics.

**Propuesta concreta:**

- Añadir label `acquirer` a `payment_requests_total` y `payment_request_duration_seconds` en `payments`.
- Cardinalidad: ~5 valores (`visa`, `mastercard`, `amex`, `paypal`, `other`). Seguro.
- Dashboard panel "errores por acquirer" como top-level.

### Laguna 3 — No hay instrumentación de trace en `bank-adapter`

**Síntoma durante el incidente:** a las 10:24 el trace termina en `payments`. No se ve qué pasó aguas abajo contra el acquirer. Toca abrir el código.

**Pilar afectado:** traces.

**Propuesta concreta:**

- Span `bank-adapter.charge` con atributos `acquirer`, `card_bin_prefix`, `retry_attempt`, `upstream_latency_ms`.
- Child span por cada reintento (ver explícitamente 5 reintentos en el UI de trazas).

### Laguna 4 — No hay anotaciones de deploy en Grafana

**Síntoma durante el incidente:** la correlación con el deploy de 10:10 se hace de memoria, no por evidencia visual. 20 minutos perdidos sin esa hipótesis.

**Pilar afectado:** events.

**Propuesta concreta:**

- Hook de CD que publica un event a Grafana (o anotación en Prometheus) por cada deploy, con labels `service`, `version`, `env`.
- Overlay en todos los dashboards operativos.

### Laguna 5 — No hay alerta sobre `up == 0` ni sobre budget de retry

**Síntoma durante el incidente:** `bank-adapter-1` llevaba 6 min caído sin alertar; además, el retry policy no tenía un budget total y no se detectó por métrica.

**Pilar afectado:** metrics (alerting).

**Propuesta concreta:**

- Alerta `up{service="bank-adapter"} == 0 for 2m`.
- Métrica nueva `bank_adapter_retry_budget_seconds_consumed` como histograma, alerta si p95 > 5 s.

## C. Síntesis — monitoring vs observabilidad

1. **Qué fue monitoring (ya se medía lo correcto):** el "dashboard golden signals" captó el salto de `5xx rate` de 0.1 % a 11 % a las 10:12. Esa parte funcionó — mide lo que se sabía que importaba.

2. **Qué fue falta de observabilidad:** las preguntas "cuántos por `acquirer`", "qué pasó entre `payments` y el upstream", "qué request falló para el cliente X" **no se podían responder sin desplegar código** (añadir labels, instrumentar spans, propagar `trace_id`). Eso es exactamente lo contrario de observabilidad.

3. **Si solo pudiera añadir una señal:** `trace_id` propagado end-to-end + inyectado en logs. Es la señal con mayor retorno: desbloquea de golpe la correlación logs↔traces y permite responder la pregunta 3 y la 4 sin instrumentación adicional. Sin esto, cada incidente degenera en grep manual.
