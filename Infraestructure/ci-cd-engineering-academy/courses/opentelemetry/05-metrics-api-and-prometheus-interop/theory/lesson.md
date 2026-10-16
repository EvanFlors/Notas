# Lección — Metrics API de OpenTelemetry e interoperabilidad con Prometheus

## 1. Por qué métricas en OTel si ya tengo `prometheus_client`

`prometheus_client` lleva años siendo el estándar de facto en Python para exponer métricas Prometheus: `start_http_server`, `make_asgi_app`, Counter/Gauge/Histogram/Summary. Es simple, maduro y suficiente **cuando el único destino de las métricas es Prometheus**.

La API de métricas de **OpenTelemetry** aparece cuando el equipo quiere lo mismo que ya consiguió con tracing: *instrumentar una vez y decidir el backend después*. Si mañana la organización migra a Datadog, Honeycomb, Grafana Cloud, StatsD o a un collector multi-backend, el código instrumentado con OTel no cambia; solo cambia el exporter.

La respuesta corta a "¿cuándo usar OTel metrics?" es:

- Si la app ya emite **traces** con OTel y quiere **exemplars**: usar OTel metrics (los exemplars se conectan de forma nativa al span activo).
- Si el equipo mantiene **varios lenguajes** y quiere un contrato uniforme (semconv, naming): OTel.
- Si solo existe Prometheus, el equipo es pequeño y no hay plan de cambiar backend: `prometheus_client` sigue siendo correcto.
- Nunca emitir la **misma** métrica desde ambas librerías: duplica series, confunde dashboards.

## 2. Modelo mental: Provider → Meter → Instrument

OTel metrics replica la jerarquía de tracing:

```
MeterProvider  (global, configurado una sola vez en main)
    └── Meter("my.library.name", version="1.0.0")
            └── Counter("http.server.requests")
            └── Histogram("http.server.duration")
            └── ObservableGauge("queue.depth", callbacks=[...])
```

Los **nombres** son opacos: por convención se usan **puntos** (`http.server.requests`). Cuando la métrica se exporta a Prometheus, los puntos pasan a underscores (`http_server_requests_total`) y OTel añade sufijos (`_total`, `_bucket`, `_sum`, `_count`) según el instrument.

El `MeterProvider` se configura en el arranque del proceso con uno o varios **MetricReaders** (Periodic + OTLP, Prometheus, Console) y, opcionalmente, **Views** que redefinen aggregation o filtran atributos.

## 3. Instruments síncronos

Se llaman desde el hilo que ejecuta la lógica de negocio.

| Instrument      | Sentido     | Monotonic | Mapea a Prometheus |
|-----------------|-------------|-----------|---------------------|
| `Counter`       | sube        | sí        | `*_total` (Counter) |
| `UpDownCounter` | sube/baja   | no        | sin sufijo (Gauge-like) |
| `Histogram`     | distribución| —         | `*_bucket` + `_sum` + `_count` |

Los métodos son `add(value, attributes=...)` para contadores y `record(value, attributes=...)` para histogramas. Los **atributos** son el equivalente a los *labels* en Prometheus y tienen las **mismas reglas de cardinalidad**: nunca `user_id`, `request_id`, `email`.

```python
from opentelemetry import metrics

meter = metrics.get_meter("myapp.http", "1.0.0")

requests = meter.create_counter(
    "http.server.requests",
    unit="1",
    description="Count of HTTP requests served",
)
duration = meter.create_histogram(
    "http.server.duration",
    unit="s",
    description="Duration of HTTP requests",
)

requests.add(1, {"http.request.method": "GET", "http.response.status_code": 200})
duration.record(0.023, {"http.request.method": "GET"})
```

## 4. Instruments asíncronos (observables)

Para valores que **ya existen** en algún estado (longitud de cola, memoria, conexiones abiertas) no tiene sentido llamar un `add` cada vez que cambian. OTel ofrece *observable instruments* registrados con **callbacks** que el SDK ejecuta **en cada ciclo de export**:

```python
def _cb_queue_depth(options):
    yield metrics.Observation(len(queue), {"queue.name": "jobs"})

meter.create_observable_gauge(
    "myapp.queue.depth",
    callbacks=[_cb_queue_depth],
    unit="1",
    description="Jobs pending in the local queue",
)
```

El SDK invoca `_cb_queue_depth` sin que el código de negocio tenga que recordarlo. Equivale al `Gauge().set()` de `prometheus_client` pero sin tener que mantener la variable sincronizada manualmente.

## 5. Temporality: `cumulative` vs `delta`

Es el concepto que **más confusión** genera y el que primero rompe una integración con Prometheus.

- **Cumulative**: cada export reporta el **valor total acumulado desde el inicio del proceso**. Un Counter que lleva 73 incrementos exporta `73`. Es lo que Prometheus espera: `rate()` lo deriva internamente.
- **Delta**: cada export reporta **solo lo que cambió desde el último export**. El mismo Counter exportaría `12`, luego `9`, luego `8`... Es lo que StatsD / Datadog consumen directamente.

El SDK de Python por default usa `CUMULATIVE` para contadores e histogramas, que es lo correcto para interop con Prometheus. Se puede sobreescribir por instrument-type al crear el reader:

```python
from opentelemetry.sdk.metrics.export import (
    PeriodicExportingMetricReader,
    AggregationTemporality,
    ConsoleMetricExporter,
)
from opentelemetry.sdk.metrics import Counter, Histogram

exporter = ConsoleMetricExporter(
    preferred_temporality={
        Counter: AggregationTemporality.DELTA,
        Histogram: AggregationTemporality.DELTA,
    }
)
```

**Diagnóstico típico**: migras a OTel, apuntas a Prometheus, los gráficos se ven planos o inestables. Casi siempre la causa es que alguien cambió a `DELTA`. También puede pasar al revés: exportas `CUMULATIVE` a un backend StatsD-like y ves "contadores que nunca bajan".

Si por alguna razón hace falta cambiar la temporalidad en el borde del pipeline (por ejemplo, un servicio exporta `DELTA` pero el backend quiere `CUMULATIVE`), el **Collector** tiene el processor `cumulativetodelta` (y en contrib existe `deltatocumulative`) que hace la conversión sin tocar la app.

## 6. Aggregation por default y Views

Cada tipo de instrument tiene una *aggregation* por default:

- `Counter`, `UpDownCounter` → `SumAggregation`
- `Histogram` → `ExplicitBucketHistogramAggregation` con buckets por default (muy parecidos a los de Prometheus client).
- `ObservableGauge` → `LastValueAggregation`.

Para redefinir — por ejemplo, cambiar los buckets del histograma o eliminar atributos de alta cardinalidad — se registran **Views** en el `MeterProvider`:

```python
from opentelemetry.sdk.metrics.view import View, ExplicitBucketHistogramAggregation

view_http_duration = View(
    instrument_name="http.server.duration",
    aggregation=ExplicitBucketHistogramAggregation(
        boundaries=[0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]
    ),
)
```

Un View se aplica por `instrument_name`, `meter_name` o patrón; permite también renombrar la métrica, filtrar atributos o descartarla entera (`DropAggregation`). Es el mecanismo oficial para **control de cardinalidad** del SDK antes de que la métrica salga del proceso.

## 7. Exporters y camino hacia Prometheus

Hay tres caminos realistas:

### 7.1 PrometheusMetricReader — scrape directo

El paquete `opentelemetry-exporter-prometheus` ofrece un reader que mantiene un `/metrics` compatible con Prometheus **dentro del propio proceso**. Es la ruta más corta para migrar un servicio que ya era "scrapeable".

```python
from prometheus_client import start_http_server
from opentelemetry.exporter.prometheus import PrometheusMetricReader

start_http_server(9464)  # expone /metrics usando el REGISTRY global de prometheus_client
reader = PrometheusMetricReader()
provider = MeterProvider(metric_readers=[reader], resource=resource)
```

Prometheus hace scrape de `http://host:9464/metrics` como siempre. Lo pagas con: Prometheus-only (sin OTLP) y acople al runtime de la app.

### 7.2 OTLP → Collector → Prometheus

Más portable: la app exporta OTLP (gRPC o HTTP). El **Collector** recibe, procesa y escribe a Prometheus de dos formas distintas:

- `prometheusremotewrite` exporter — Collector hace push via remote-write a Prometheus/Mimir.
- Prometheus (v2.47+) acepta **OTLP ingest nativo** por `/api/v1/otlp/v1/metrics`; no hace falta Collector si no se necesita transformar.

```yaml
# collector.yaml
receivers: { otlp: { protocols: { grpc: {} } } }
exporters:
  prometheusremotewrite:
    endpoint: http://prometheus:9090/api/v1/write
service:
  pipelines:
    metrics: { receivers: [otlp], processors: [batch], exporters: [prometheusremotewrite] }
```

### 7.3 Collector `prometheusreceiver` (lectura por scrape)

Útil durante migraciones: el Collector scrapea los `/metrics` existentes (de `prometheus_client` o node_exporter) y los convierte a OTLP para distribuirlos. Permite centralizar todo en el pipeline OTel sin reinstrumentar.

## 8. Exemplars: puente métrica ↔ trace

Un **exemplar** es una muestra individual adjunta a un bucket de histograma que incluye `trace_id` y `span_id`. Grafana los pinta como puntos sobre la gráfica y permite click-through al trace completo.

En OTel Python, los exemplars se adjuntan **automáticamente** al bucket cuando se llama `histogram.record(...)` dentro de un span activo, siempre que el reader soporte exemplars (los exporters OTLP y Prometheus los soportan). No hay que configurar nada en la app más allá de tener tracing activo:

```python
with tracer.start_as_current_span("handle_request") as span:
    span.set_attribute("http.route", "/api/items")
    start = time.monotonic()
    do_work()
    duration.record(time.monotonic() - start, {"http.route": "/api/items"})
    # el exemplar queda adjunto con el trace_id del span actual
```

Para que Prometheus los almacene hace falta habilitar `--enable-feature=exemplar-storage`. Para que Grafana los dibuje hace falta configurar el datasource con el link a Tempo/Jaeger.

## 9. Comparación detallada con `prometheus_client`

| Dimensión                    | `prometheus_client`           | OTel metrics API                     |
|------------------------------|-------------------------------|--------------------------------------|
| Alcance                      | Prometheus-only               | Multi-backend (OTLP, Prom, StatsD…)  |
| Tipos                        | Counter/Gauge/Histogram/Summary | Counter/UpDown/Histogram/Observable* |
| Labels / Attributes          | labels fijos declarados       | attributes libres por call           |
| Exposición                   | `/metrics` HTTP               | `/metrics` (opcional) + OTLP push    |
| Exemplars                    | Sí, manual                    | Sí, automático con span activo       |
| Multi-proceso (gunicorn)     | `PROMETHEUS_MULTIPROC_DIR`    | OTLP push por worker (recomendado)   |
| Madurez                      | Muy maduro                    | GA desde 2022, ampliamente usado     |

**Guía práctica**:

- App nueva, se emiten también traces OTel → **OTel metrics**.
- App legacy con `prometheus_client` ya probado y sin planes de cambiar backend → **mantener**.
- Migración gradual → **PrometheusMetricReader** mientras se desacopla el runtime, luego cambiar a OTLP cuando el Collector esté listo.

## 10. Antipatrón: doble emisión

Durante una migración es tentador dejar `prometheus_client` ejecutando "por si acaso" y añadir OTel al lado. Si **ambas librerías emiten la misma métrica** pasa alguna de estas:

1. Dos series distintas en Prometheus con nombres casi iguales — dashboards rotos.
2. La misma serie emitida dos veces — valores sumados o alternantes, imposible de reconciliar.
3. Trabajo duplicado en el runtime (dos registries, dos locks, dos pipelines de export).

La disciplina correcta durante la migración:

- Añadir OTel **sin** quitar `prometheus_client` solo para métricas **nuevas** que no existían.
- Para métricas **existentes**, migrar en PR único: borrar la emisión `prometheus_client`, añadir la OTel con el **mismo nombre resultante en Prometheus** (nombrarla `http.server.requests` para que exporte como `http_server_requests_total`).
- Verificar con `curl /metrics | grep` que la serie sigue apareciendo tras el deploy.

## 11. Checklist de migración `prometheus_client` → OTel

1. ¿La app ya emite traces OTel? Si no, instrumentar antes para que los exemplars funcionen.
2. Elegir **temporalidad**: `CUMULATIVE` siempre que el destino sea Prometheus.
3. Decidir **transport**: `PrometheusMetricReader` para empezar (menos cambios); OTLP para desacoplar del backend.
4. Mapear cada métrica existente a su equivalente OTel; respetar nombres resultantes (sufijos `_total`, puntos → `_`).
5. Añadir **Views** para reproducir buckets custom del histograma anterior.
6. Borrar la emisión antigua en el mismo commit; validar scrape con tests.
7. Si se pasa por Collector, revisar que `batch` + `memory_limiter` estén configurados y que el exporter use `prometheusremotewrite` o el ingest OTLP de Prometheus v2.47+.
8. Observar durante 24–48 h: diferencias en `rate()`, picos nuevos en `_bucket`, exemplars visibles en Grafana.

## 12. Qué llevar al capstone

- Un servicio del capstone con **Counter + Histogram** en OTel.
- Reader Prometheus **y/o** OTLP a Collector — el equipo elige en función del backend objetivo.
- Un **View** aplicado para redefinir buckets o filtrar un atributo (ejercicio de control de cardinalidad explícito).
- Exemplars visibles en Grafana enlazando a Tempo (requiere que `obs-07` y los módulos de tracing estén en pie).
- Decisión documentada: por qué OTel (o por qué no todavía) y qué pasa con las métricas de infraestructura (`node_exporter`, `kube-state-metrics`) — típicamente siguen como Prometheus scrape porque son de terceros y no tiene sentido reinstrumentarlas.
