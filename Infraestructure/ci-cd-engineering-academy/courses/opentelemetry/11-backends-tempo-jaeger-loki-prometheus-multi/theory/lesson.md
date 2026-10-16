# Lección — Backends OTel: Tempo, Jaeger, Loki, Prometheus y multi-exportación

> Nivel avanzado. Duración lectura ≈ 60 min. Asume `otel-08` (Collector) y familiaridad con Prometheus/Loki del curso previo.

## 1. Por qué este módulo existe

El valor que OpenTelemetry prometió desde el día uno es simple: **instrumenta una vez, cambia el backend sin tocar el código**. Esa promesa solo se cumple si entiendes, en profundidad, qué backend elegir por cada **signal** y cómo el **Collector** actúa como el único punto donde esa decisión se materializa.

Hasta aquí (`otel-08`) tienes un Collector que recibe las tres señales y las valida. En este módulo pasamos del `debug` exporter al mundo real: Tempo para traces, Prometheus/Loki para los otros dos pilares, Jaeger como alternativa clásica, y vendor backends (Datadog, Honeycomb, New Relic) para equipos que no quieren o no pueden self-host. También aprendemos a **duplicar** telemetría durante una migración y a **monitorizar al propio Collector** — porque si falla, falla en silencio.

## 2. La matriz `signal × backend`

No existe "el mejor backend" en abstracto; existe el mejor para cada signal, para cada escala, para cada presupuesto. La matriz típica:

| Signal | Opción barata self-hosted | Opción clásica self-hosted | Opción vendor típica |
|---|---|---|---|
| Traces | **Tempo** | **Jaeger**, Zipkin | Datadog APM, Honeycomb, New Relic |
| Metrics | **Prometheus** (local), **Mimir** / Thanos / VictoriaMetrics (escala) | Graphite (legacy) | Datadog Metrics, Grafana Cloud, Chronosphere |
| Logs | **Loki** | OpenSearch / Elasticsearch | Datadog Logs, Splunk, Honeycomb |

El Collector es el **único** componente que conoce esta matriz. La aplicación habla OTLP; el Collector traduce.

## 3. Tempo: trace-only, barato por diseño

Grafana **Tempo** es un backend de **solo traces** cuya tesis es *"index trace-id, store the rest"*: el índice contiene únicamente el identificador del trace y punteros a los bloques comprimidos; el contenido (los spans, sus atributos, sus eventos) vive en object storage (S3, GCS, Azure, MinIO, o filesystem para labs).

Consecuencias:
- **Ingesta y storage son muy baratos** comparados con Jaeger o Elasticsearch.
- Lookup directo por `trace-id` es instantáneo.
- Búsqueda rica por atributos no está indexada: se resuelve con **TraceQL** sobre los bloques (más costoso pero posible), o se delega a **métricas y logs correlacionados** en Grafana (click-through desde un panel que *sí* tiene atributos indexados hacia el trace exacto).

TraceQL es un lenguaje tipo PromQL para traces:

```traceql
{ resource.service.name = "api" && span.http.status_code >= 500 }
{ duration > 500ms && name = "GET /orders" }
{ status = error } | by(resource.service.name) | rate()
```

El patrón canónico Grafana + Tempo:

1. Alerta dispara desde Prometheus (`error_rate > 5%`).
2. En el panel de Grafana, haces clic en un exemplar (una métrica con un `traceID` adjunto).
3. Grafana abre Tempo con ese `trace-id` exacto. Lookup instantáneo.
4. Si quieres "todos los traces lentos de las últimas 2 h", escribes TraceQL — más caro pero funciona.

En resumen: **Tempo asume que vas a Grafana para el 90% de los flujos.** Si tu organización no vive en Grafana, Tempo es menos cómodo.

## 4. Jaeger: clásico, aún vigente

**Jaeger** nació en Uber en 2015, llegó a CNCF, y durante años fue el estándar de facto de distributed tracing self-hosted. Características que lo diferencian de Tempo:

- **Indexa más que `trace-id`**: nombres de servicio, operación, tags configurables. La UI de Jaeger permite búsquedas por servicio + tag + rango de duración sin un Grafana al lado.
- **Backend storage**: Cassandra o Elasticsearch (más complejo de operar que Tempo + object storage).
- **Soporta OTLP nativo** desde v1.35; también sigue aceptando su protocolo propio gRPC/Thrift y el formato Zipkin (para migraciones).
- **UI standalone útil**: una ventaja real cuando el equipo todavía no tiene Grafana madura.

Trade-off: a escalas de 10 k–100 k spans/s, Jaeger exige más hardware que Tempo porque sus índices crecen con la cardinalidad de operaciones y tags. A escala pequeña (dev, staging, teams de 10 servicios), la diferencia de costo es irrelevante y la UI de Jaeger gana por conveniencia.

**Jaeger NO está deprecado**; sigue activo. La elección Tempo vs Jaeger es táctica.

## 5. Loki para logs vía Collector

Ya conoces Loki del curso `prometheus-grafana` (`obs-13`). Lo nuevo aquí es llegar a Loki **sin un agente dedicado (Alloy, Promtail, Fluent Bit)**, usando el Collector OTel como único recolector:

```yaml
exporters:
  otlphttp/loki:
    endpoint: http://loki:3100/otlp
```

Loki ≥ 3.0 acepta OTLP nativo en `/otlp/v1/logs` (sin necesidad del exporter `loki` que se marcó como deprecado). El Collector recibe logs OTel (desde el `otlp` receiver o desde `filelog`, `journald`, `k8sobjects`), aplica procesadores (semconv, PII scrubbing, muestreo) y los envía a Loki.

**Trampa clásica**: los atributos OTel se convierten en labels Loki si no se tiene cuidado. `request_id` o `trace_id` como label Loki = cardinalidad explosiva. Hay que mantenerlos como **structured metadata** (soporte reciente en Loki) o como contenido del log, no como label.

## 6. Prometheus para métricas: tres formas de llegar

Prometheus es modelo **pull por default**: él raspa (`scrape`) a los targets. OTel invierte el modelo (push). Hay tres estrategias para que convivan:

### 6.1 `prometheusexporter` — expose como target

El Collector expone un endpoint `/metrics` en formato Prometheus; Prometheus lo scrapea.

```yaml
exporters:
  prometheus:
    endpoint: 0.0.0.0:8889
service:
  pipelines:
    metrics:
      receivers: [otlp]
      exporters: [prometheus]
```

Ventaja: cero cambio en Prometheus. Desventaja: cardinalidad y temporalidad del Collector deben coincidir con lo que Prometheus espera (`cumulative`).

### 6.2 `prometheusremotewrite` — push vía remote_write

El Collector hace `remote_write` a Prometheus (o a Mimir/Thanos).

```yaml
exporters:
  prometheusremotewrite:
    endpoint: http://prometheus:9090/api/v1/write
    tls:
      insecure: true
```

Ventaja: push, atraviesa NAT, se adapta bien a entornos cloud. Desventaja: Prometheus necesita `--enable-feature=remote-write-receiver`.

### 6.3 OTLP ingest nativo

**Nueva ruta**: Prometheus ≥ 2.47 acepta OTLP directamente en `/api/v1/otlp/v1/metrics` con la flag `--web.enable-otlp-receiver`. El Collector puede exportar OTLP a Prometheus **sin ningún "puente"**:

```yaml
exporters:
  otlphttp/prom:
    endpoint: http://prometheus:9090/api/v1/otlp
```

Ventaja: una sola ruta OTLP para los tres signals cuando el destino de métricas también es OTLP-capaz; menos superficies de configuración. Desventaja: feature relativamente nueva; algunas conversiones (histogramas delta ↔ cumulative) todavía afinándose.

**Regla práctica**: si estás arrancando ahora y tu Prometheus es ≥ 2.47, OTLP ingest nativo simplifica. Si tienes `remote_write` ya operando a Mimir/Thanos, no lo cambies por cambiar.

## 7. Multi-exportación: cuándo y cuándo no

El Collector puede enviar la **misma** pipeline a **N exporters** a la vez:

```yaml
service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlp/tempo, otlp/jaeger, otlphttp/datadog]
```

Esto se llama **fan-out**. Casos legítimos:

- **Migración blue/green**: envías a los dos backends durante 2–4 semanas, comparas, cortas el viejo.
- **Dev + prod paralelo**: mandas una muestra a un backend de dev para experimentos.
- **Validación cross-vendor**: pruebas Datadog antes de firmar el contrato.

Caso **no** legítimo: multi-exportar "para siempre" como estrategia. Duplicas el ancho de banda de salida y la factura del vendor. La neutralidad vendor se logra con **un** backend por signal y la capacidad de **cambiarlo** en 24 h — no manteniendo dos a la vez.

## 8. Vendor backends sobre OTLP

Los grandes vendors ya aceptan OTLP:

- **Datadog**: `datadogexporter` (específico, mapea semconv OTel a convenciones Datadog) o `otlphttp` con endpoint `https://trace.agent.<site>.datadoghq.com/api/v0.2/traces` + header `DD-API-KEY`.
- **Honeycomb**: endpoint `https://api.honeycomb.io` + header `x-honeycomb-team: <api-key>`.
- **New Relic**: endpoint OTLP `https://otlp.nr-data.net` + header `api-key: <license-key>`.
- **Grafana Cloud**: endpoints OTLP por región + basic auth con `instance-id:api-token`.
- **Lightstep (ServiceNow Cloud Observability)**: `https://ingest.lightstep.com:443` + `lightstep-access-token`.

**Patrón portable**: siempre que el vendor acepte OTLP genérico, prefiérelo sobre el exporter dedicado. Un día cambias de vendor y solo tocas endpoint + header. El exporter dedicado (Datadog, Honeycomb) aporta valor cuando necesitas el mapeo propietario (p. ej. convertir métricas OTel a métricas `distribution` nativas de Datadog).

**NUNCA** pongas la API key en el YAML comiteado. Siempre `${env:DD_API_KEY}`.

## 9. Meta-telemetría del Collector

El Collector **es** un servicio como cualquier otro: puede fallar, saturarse, perder datos. OTel incluye `service.telemetry` para que el Collector exponga sus propias métricas Prometheus en `:8888/metrics`:

```yaml
service:
  telemetry:
    metrics:
      level: detailed
      readers:
        - pull:
            exporter:
              prometheus:
                host: 0.0.0.0
                port: 8888
```

Métricas que importan:

- `otelcol_receiver_accepted_spans` / `_refused_spans` — entrada.
- `otelcol_processor_batch_batch_send_size` — tamaño típico de batch.
- `otelcol_processor_dropped_spans` — señal crítica: se está perdiendo telemetría.
- `otelcol_exporter_sent_spans` / `_send_failed_spans` — salida y fallos de exporter.
- `otelcol_exporter_queue_size` / `_queue_capacity` — presión sobre la cola.

Alertas mínimas: `rate(otelcol_exporter_send_failed_spans[5m]) > 0`, `otelcol_processor_dropped_spans > 0`, `queue_size / queue_capacity > 0.8`.

Sin estas alertas, el pipeline falla en silencio: la app sigue emitiendo, pero el backend se queda a oscuras.

## 10. Patrón canónico: Grafana LGTM

**L**oki + **G**rafana + **T**empo + **M**imir (o Prometheus) es la "pila LGTM" promovida por Grafana Labs. Todos aceptan OTLP (directo o vía Collector). Ventajas:

- Único UI (Grafana) para los tres signals.
- Correlación nativa: exemplar en Prometheus → `traceID` → Tempo; línea en Loki → `traceID` → Tempo.
- Ecosistema coherente, mismas convenciones, misma empresa detrás.

Desventaja: dependes de Grafana Labs para la hoja de ruta. Si cambias a Datadog, tiras la UI entera y rehaces dashboards.

LGTM es un **default razonable**; no es la única respuesta válida.

## 11. Diseñando una migración de backend sin tocar código

Objetivo: pasar de **Jaeger self-hosted** a **Datadog APM** en 90 días sin tocar las 40 apps instrumentadas.

1. **Día 0** — El Collector exporta solo a Jaeger. La app emite OTLP al Collector.
2. **Día 7** — PR al YAML del Collector: añade `datadogexporter` al pipeline `traces`. **Fan-out activo**: cada trace va a los dos backends.
3. **Días 7–60** — El equipo compara, aprende la UI de Datadog, migra dashboards y alertas.
4. **Día 60** — Nuevo PR: quita `jaeger` del pipeline. Ahora solo Datadog.
5. **Día 90** — Apaga Jaeger. Elimina su infraestructura.

Cero commits en el repo de la aplicación. Cero reinicios de la app. El Collector se reinicia por hot-reload o rolling restart.

**Esto es la promesa de OTel materializada.**

## 12. Antipatrones y cuándo detenerte

- **Multi-exportar como "fallback"** — si pierdes la primera salida querrás saberlo, no esconderlo. Usa `sending_queue` + alertas, no un segundo backend.
- **Vendor-specific attributes esparcidos en el código** — rompes la portabilidad. Usa atributos OTel neutros; traduce en el Collector si el vendor exige nombres propios.
- **API keys en YAML comiteado** — accidente que no se perdona. `${env:...}` siempre, secrets manager mejor.
- **Olvidar meta-telemetría** — Collector sin monitorización propia = pérdida silenciosa. Nunca.
- **Elegir Tempo "porque es más nuevo"** sin tener Grafana + exemplars + logs — pierdes la UX. Jaeger standalone puede ser mejor para ti ahora mismo.
- **Elegir Datadog "porque es más fácil"** y escribir código con sus SDKs propietarios — vuelves al lock-in que OTel vino a resolver.

La decisión correcta por default: **OTLP en la app, Collector como router, backend elegido por YAML**. Si cambia, cambia el YAML.
