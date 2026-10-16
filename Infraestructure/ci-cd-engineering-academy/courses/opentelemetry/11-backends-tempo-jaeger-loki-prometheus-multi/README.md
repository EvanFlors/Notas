# otel-11 — Backends: Tempo, Jaeger, Loki, Prometheus y multi-exportación

## Identificación

- **ID:** `otel-11-backends-tempo-jaeger-loki-prometheus-multi`
- **Nivel:** avanzado
- **Duración estimada:** 4 h
- **Prerrequisitos:** `otel-08-collector-architecture-receivers-processors-exporters`

## Objetivo

Elegir el backend correcto por **signal** (traces, metrics, logs) y operar el Collector como **router multi-backend**: Tempo o Jaeger para traces, Loki para logs, Prometheus (vía `remote_write`, `prometheusremotewrite` o OTLP ingest nativo) para métricas; añadir vendor backends (Datadog, Honeycomb, New Relic) sin tocar el código de la aplicación; migrar un backend por otro cambiando solo el YAML del Collector.

## Temas y subtemas

1. **Panorama de backends por signal**
   - Traces: Tempo, Jaeger, Zipkin, vendor (Datadog, Honeycomb, New Relic, Lightstep).
   - Metrics: Prometheus, Mimir, Cortex, Thanos, VictoriaMetrics, vendor.
   - Logs: Loki, OpenSearch/Elasticsearch, vendor.
2. **Tempo (Grafana)**
   - Trace-only, index solo de `trace-id`.
   - Chunks en object storage (S3/GCS/Azure/MinIO/filesystem).
   - **TraceQL** para búsqueda rica directamente sobre el storage.
   - Barato por diseño; UX avanzada requiere Grafana (métricas y logs correlacionados).
3. **Jaeger**
   - Clásico (CNCF), indexa más atributos que Tempo.
   - Más caro a escala pero más expresivo en búsqueda sin Grafana.
   - Soporta OTLP nativo desde v1.35+; también acepta su propio protocolo gRPC/Thrift.
4. **Loki para logs vía Collector**
   - `loki` o `lokiexporter` del Collector → `/loki/api/v1/push`.
   - Promoción selectiva de atributos a labels Loki (misma trampa de cardinalidad).
5. **Prometheus para métricas**
   - **`prometheusexporter`** (expose `/metrics` → Prometheus scrape — modelo pull).
   - **`prometheusremotewrite`** exporter → `remote_write` (modelo push).
   - **OTLP ingest nativo** en Prometheus (feature flag) → aceptar OTLP directo sin Collector intermedio.
6. **Multi-exportación**
   - Un pipeline → N exporters (fan-out).
   - Útil para **migraciones blue/green de backend** y para dev + prod en paralelo.
   - Costo: duplicación de tráfico de salida.
7. **Vendor backends sobre OTLP**
   - Datadog, Honeycomb, New Relic, Lightstep, Grafana Cloud: todos aceptan OTLP.
   - Exporter dedicado (`datadogexporter`) vs OTLP genérico con header de auth.
   - Datos propietarios/semconv específicos: trade-off vs portabilidad.
8. **Meta-telemetry del Collector**
   - `service.telemetry.metrics` del Collector expone métricas Prometheus sobre sí mismo.
   - Métricas clave: `otelcol_exporter_sent_*`, `otelcol_exporter_send_failed_*`, `otelcol_processor_dropped_*`, `otelcol_receiver_refused_*`.
   - Alertas sobre el pipeline mismo.

## Conceptos internos (fundamentos)

- **Tempo** acepta la pérdida de riqueza de búsqueda por ganar costo barato de ingesta — la búsqueda rica se delega a métricas y logs correlacionados en Grafana.
- **Jaeger** mantiene índices de operaciones y tags; a 100 k RPS la factura empieza a doler, pero sin Grafana el navegador es mejor que el de Tempo.
- **OTLP ingest nativo** en Prometheus elimina el "último hop" para equipos que ya tienen Prom self-hosted; el Collector sigue aportando valor por `transform`, `tail_sampling`, enriquecimiento con `k8sattributes`, etc.
- **Multi-exportación es un patrón táctico**, no estratégico: se usa para **migrar** o **validar**, no como estado permanente (duplica costo).
- La **meta-telemetría del Collector** es la primera cosa que se olvida: sin alertas sobre `send_failed`, el pipeline falla en silencio.

## Competencias

- **Conceptual:** justificar la matriz `signal × backend` para una organización; explicar por qué Tempo es barato y por qué TraceQL hace que ese ahorro sea viable; defender cuándo usar vendor backend y cuándo no.
- **Operativa:** configurar el Collector para exportar a Tempo, a Jaeger, a Loki y a Prometheus (los tres modos); ejecutar una migración blue/green de backend sin tocar la app.
- **Arquitectónica:** diseñar un pipeline multi-backend coherente con la estrategia vendor-neutral; definir métricas y alertas sobre el propio Collector; estimar el costo marginal del fan-out multi-exporter.

## Ejemplos

- [`examples/01-tempo-with-collector/`](examples/01-tempo-with-collector/) — docker-compose con Tempo + Collector + Grafana; genera traces vía telemetrygen; se consultan con TraceQL en Grafana.
- [`examples/02-prom-otlp-ingest/`](examples/02-prom-otlp-ingest/) — Prometheus con `--web.enable-otlp-receiver`; el Collector exporta OTLP directo a Prometheus (sin `remote_write`).
- [`examples/03-multi-export-datadog-plus-tempo/`](examples/03-multi-export-datadog-plus-tempo/) — pipeline único → fan-out a Tempo (self-hosted) **y** Datadog (vendor). Walkthrough-only si no hay `DD_API_KEY`.

## Actividades

- [`activities/01-switch-backend-no-code-change/`](activities/01-switch-backend-no-code-change/) — **guided-lab**: un servicio exporta OTLP a Tempo; el estudiante cambia el YAML del Collector para enviar a Jaeger en vez de a Tempo. Cero cambios de código en la app.
- [`activities/02-tempo-vs-jaeger-adr/`](activities/02-tempo-vs-jaeger-adr/) — **independent (architecture)**: redactar un ADR eligiendo Tempo o Jaeger para una organización ficticia con requisitos dados.

## Entregables

- Capstone con el **mismo binario** apuntado alternativamente a Tempo y a Jaeger — demostración de la neutralidad vendor.
- ADR firmado comparando Tempo vs Jaeger con decisión defendida.
- Pipeline del Collector con fan-out opcional a vendor (Datadog) documentado para migraciones.
- Dashboard mínimo de **meta-telemetría** del Collector (queue, dropped, failed).

## Criterios de evaluación

- **Conceptual:** explicar en qué momento Tempo deja de ser más barato que Jaeger y por qué; justificar `remote_write` vs OTLP ingest nativo para una org dada; defender cuándo multi-exportar y cuándo no.
- **Operativa:** cambiar el backend de traces del capstone con un solo PR al YAML del Collector y sin tocar la app; demostrar que las traces siguen llegando al nuevo backend.
- **Arquitectónica:** redactar un ADR técnico razonado; diseñar el fan-out para una migración de 90 días y describir cómo se corta el backend viejo.

## Recursos

- [`resources/links.md`](resources/links.md)
