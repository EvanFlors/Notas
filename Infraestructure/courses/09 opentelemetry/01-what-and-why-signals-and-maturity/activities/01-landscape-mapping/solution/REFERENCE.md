# REFERENCE — otel-01-01-landscape-mapping

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

## Sección A — Clasificación (modelo)

| Pieza                | Categoría        | Justificación |
|----------------------|------------------|---------------|
| Prometheus (storage + PromQL) | **convive** | OTel es generación + transporte. Prometheus sigue siendo backend de métricas. Entra vía `prometheusremotewrite` exporter o vía OTLP ingest nativo del Prometheus reciente. |
| Jaeger (storage + UI) | **convive**      | Jaeger acepta OTLP como backend de traces. Las apps viejas con `jaeger-client` siguen entrando vía `receiver/jaeger` del Collector. |
| Zipkin               | **convive**      | Igual que Jaeger: puede ser backend (acepta OTLP) y hay `receiver/zipkin` para apps legacy con brave/zipkin client. |
| Loki                 | **convive**      | Backend de logs. Entra vía `exporter/loki` del Collector. OTel no sustituye el storage. |
| Vendor APM (Datadog, New Relic, Honeycomb) | **convive**, pero reemplaza su **SDK** | Los SDKs propietarios **sí** se reemplazan por OTel SDK (eso es el valor principal). El vendor sigue como backend vía `exporter/<vendor>` o OTLP directo. |
| Grafana              | **fuera-de-scope** | Es UI/dashboards/alerting. OTel no toca ese ámbito. |
| Fluentbit / Vector   | **convive** o **reemplazada parcial** | Para logs puros pueden quedar; muchos equipos los **colapsan** en el Collector para unificar. Depende del caso. |
| `prometheus_client` / `jaeger-client` / `zipkin-brave` en el código | **reemplazadas** | Son exactamente las librerías cuyo rol toma OTel (API + SDK). |

## Sección B — Diagrama (modelo)

### Antes

```
   FastAPI app ─── prometheus_client ──► /metrics ──► Prometheus
       │
       ├────── jaeger-client     ──────► Jaeger (agent → collector → storage)
       │
       └────── logging           ──────► stdout ──► Fluentbit ──► Loki

   (dashboards y alertas en Grafana leyendo Prometheus/Loki/Tempo)
```

### Después (migrado)

```
   FastAPI app ─── OTel SDK (traces + metrics + logs) ──► OTLP
                                                          │
                                                          ▼
                                        ┌───── OTel Collector ─────┐
                                        │ receivers:               │
                                        │   otlp (nuevo)           │
                                        │   jaeger (apps legacy)   │
                                        │   prometheus (scrape)    │
                                        │ processors:              │
                                        │   batch, memory_limiter, │
                                        │   attributes             │
                                        │ exporters:               │
                                        │   prometheusremotewrite  │─► Prometheus
                                        │   otlp (tempo/jaeger)    │─► Tempo
                                        │   loki                   │─► Loki
                                        │   datadog (opcional)     │─► Datadog
                                        └──────────────────────────┘
   (Grafana sigue leyendo Prometheus/Tempo/Loki — sin cambios)
```

Observa: **ningún código de aplicación habla con el backend directamente**. Todo pasa por OTLP → Collector → exporter. Esa es la frontera que hace posible cambiar de backend sin tocar código.

## Sección C — Las 5 afirmaciones (modelo)

1. *"OTel va a reemplazar a Prometheus."* → **En desacuerdo.** OTel no es un TSDB ni implementa PromQL. Puede **alimentar** Prometheus, no sustituirlo.
2. *"Si adopto OTel tengo que tirar Jaeger."* → **En desacuerdo.** Jaeger sigue siendo backend válido para traces OTel (acepta OTLP). Lo que **sí** se reemplaza es el `jaeger-client` dentro del código.
3. *"Grafana queda obsoleta con OTel."* → **En desacuerdo.** Grafana es UI/dashboards/alerting; OTel no juega en ese ámbito. De hecho, Grafana + OTel + Tempo/Loki es un combo recomendado.
4. *"Puedo migrar de Datadog a Grafana Cloud sin tocar código si uso OTel."* → **Depende.** Si disciplinas semconv y evitas atributos propietarios `dd.*`, sí — basta cambiar el exporter del Collector. Dashboards y alertas sí se reescriben.
5. *"Fluentbit queda sin sentido si uso el OTel Collector."* → **Depende.** El Collector puede recoger logs (filelog receiver). Si tu organización ya tiene Fluentbit maduro para N orígenes no OTLP, puede tener sentido mantenerlo delante y hacer que **él** envíe a OTLP. Decisión caso a caso.

## Punto a repetir hasta que suene aburrido

> OTel = **generación + transporte + semántica**. El **storage** (Prometheus, Tempo, Loki, Jaeger) y la **UI** (Grafana) viven **fuera** de OTel y, en la mayoría de los casos, **conviven** con ella en lugar de ser reemplazadas.
