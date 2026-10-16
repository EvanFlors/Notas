# REFERENCIA — obs-01-01-when-not-prometheus

> Esta es **una** solución defendible, no la única. El objetivo de la actividad es tu criterio, no reproducir este documento.

## Escenario 1 — Microservicios FastAPI en EKS

**Decisión:** Prometheus SÍ.

**Justificación:**

- Procesos de larga vida (pods), alcanzables por red interna del cluster: pull aplica trivialmente.
- Service discovery de Kubernetes elimina configuración manual (`ServiceMonitor`/`PodMonitor` del Operator).
- RED metrics por middleware HTTP es un patrón resuelto en FastAPI con `prometheus_client`.
- Cardinalidad controlada si se evitan labels como `user_id`, `request_id`.
- Equipo plataforma de 3 personas puede operar `kube-prometheus-stack` sin dolor.

**Alternativa / complemento:**

- Loki para logs y Tempo para traces (vía OpenTelemetry) completan el stack LGTM.
- Datadog sería alternativa SaaS si prefieren pagar por no operar.

**Riesgo si lo haces mal:**

- No controlar cardinalidad: TSDB se infla y los scrapes se vuelven lentos; costo de RAM se dispara.

---

## Escenario 2 — Job de ETL cada hora

**Decisión:** Prometheus parcial. Usar **Pushgateway** o convertir en servicio.

**Justificación:**

- El proceso vive 90 s cada hora: entre ejecuciones no hay nada que scrapear.
- `scrape_interval` default 15 s no se alinea con una ventana de 90 s cada 3600 s.
- Pushgateway es exactamente el caso canónico: el job empuja al final; Prometheus scrapea al Pushgateway.
- Alternativa limpia: convertir el proceso en un servicio permanente que exponga una `gauge` "`last_run_processed`" + un `counter` acumulado — así evitas estado en Pushgateway.

**Alternativa / complemento:**

- Pushgateway + reglas de alerta sobre `time() - job_last_success_unixtime > 7200`.
- Si el equipo ya tiene Airflow/Dagster, usar sus propios hooks de métricas puede ser más simple.

**Riesgo si lo haces mal:**

- Pushgateway con métricas que nunca se limpian: datos obsoletos quedan "pegados" para siempre y producen alertas falsas o métricas confusas.

---

## Escenario 3 — Flota IoT de 500 000 dispositivos

**Decisión:** Prometheus NO (para la telemetría de dispositivos).

**Justificación:**

- Dispositivos detrás del NAT del cliente: el scraper no los alcanza. Pull no aplica estructuralmente.
- 500 000 dispositivos × labels por dispositivo explotan la cardinalidad de Prometheus; incluso con push, pondría de rodillas a Prometheus single-node.
- Pushgateway **no arregla esto**: Pushgateway es para jobs batch cortos, no para fan-in de telemetría masiva.
- La frecuencia (1 muestra / 10 min / dispositivo) es baja, pero el fan-out es imposible.

**Alternativa / complemento:**

- Pipeline MQTT (broker tipo EMQX/Mosquitto) → **VictoriaMetrics** (que acepta remote-write y escala a millones de series) o un backend de time-series dimensionado para IoT.
- Prometheus **sí** puede monitorear la infraestructura del broker/ingesta (meta-observabilidad del pipeline).

**Riesgo si lo haces mal:**

- Intentar meter 500 k series en un Prometheus single-node: OOM, scrapes lentísimos, retention imposible, alert fatigue.

---

## Escenario 4 — Base histórica de 7 años para analítica de producto

**Decisión:** Prometheus NO (para analítica de producto). SÍ para alerting operativo (en paralelo).

**Justificación:**

- Prometheus no es un sistema de retención larga. El default es 15 días; subirlo a 7 años es técnicamente posible pero disfuncional (RAM = f(series activas), compaction cada vez más cara).
- La analítica de producto necesita joins, cohortes, agregaciones por `user_id`, segmentos — PromQL no es SQL ni data warehouse.
- Mezclar observabilidad operativa con analítica de producto es un anti-patrón de gobernanza: distintos consumidores, distintos SLOs, distintos costos.

**Alternativa / complemento:**

- Data warehouse (BigQuery, Snowflake, Redshift) con pipeline de events (Segment, RudderStack, Kafka → warehouse).
- Prometheus **sí** se queda para métricas operativas con retención corta + `remote_write` a Thanos/Mimir para retención media (90–180 d operativa).

**Riesgo si lo haces mal:**

- Subir retention de Prometheus a 7 años: coste de storage y RAM creciendo linealmente, imposibilidad práctica de hacer cohorts, bloqueos del equipo de observabilidad por pedidos de producto.

---

## Síntesis

**Regla pull-first que me llevo:** usa pull por defecto; cualquier otro modelo requiere justificar por qué pull no aplica para *este* proceso concreto.

**Rol del Pushgateway:** es la válvula de escape **específica** para jobs batch que viven menos que un `scrape_interval` razonable. No es "la forma más fácil de hacer push" ni un fan-in de telemetría masiva. Toda métrica en Pushgateway debe tener política de limpieza (`DELETE`) o quedará obsoleta.

**7 preguntas-criterio para decidir Prometheus vs alternativas:**

1. ¿Los procesos viven más que el `scrape_interval` (al menos 60 s)?
2. ¿El scraper puede alcanzar los targets por red (sin NAT ni firewall bloqueante)?
3. ¿La cardinalidad total esperada cabe en un Prometheus single-node (<1–5 M series activas)?
4. ¿La retención requerida es ≤ 90 días (operativa) o se puede delegar a Thanos/Mimir/VM?
5. ¿Los consumidores quieren alertar y debuggear operativamente, o hacer analítica de negocio histórica?
6. ¿Hay service discovery disponible (K8s, Consul, EC2) o la lista es realmente estática?
7. ¿El equipo puede operar un stack self-hosted, o conviene SaaS (Datadog, Grafana Cloud, Chronosphere)?
