# Teoria — OTel Collector: arquitectura, receivers, processors, exporters

## 1. Que es el Collector y por que existe

El **OpenTelemetry Collector** es un *proxy/daemon* vendor-neutral que recibe telemetria en multiples formatos, la procesa (filtra, enriquece, agrupa, muestrea) y la exporta a uno o varios backends. Es el **data plane** reutilizable que separa el productor (SDK en la app) del consumidor (Prometheus, Tempo, Loki, Datadog, etc.).

Problemas que resuelve:

- Centralizar politicas (sampling, PII scrubbing, enriquecimiento con metadata del nodo).
- Desacoplar el SDK del backend: la app solo habla OTLP; el Collector decide a donde va.
- Reducir trafico y costo (batch, compresion, dropping, cardinality control).
- Traducir formatos legacy (Prometheus, Jaeger, Zipkin) a OTLP y viceversa.

```
+------------------+        +-------------------------+        +-----------+
| App + SDK OTel   | OTLP ->| OTel Collector          | OTLP ->| Backend A |
| (traces/metrics/ |        | receivers -> processors |        +-----------+
|  logs)           |        |          -> exporters   | --->   +-----------+
+------------------+        +-------------------------+        | Backend B |
                                                               +-----------+
```

## 2. Core vs Contrib (y las distros)

Hay dos distribuciones oficiales:

- **otelcol (core)**: solo componentes "estables" mantenidos por el proyecto. Pocos receivers/exporters: `otlp`, `prometheus`, `otlphttp`, `debug`, `batch`, `memory_limiter`, `attributes`, `resource`, pocos mas.
- **otelcol-contrib**: incluye todos los componentes de la comunidad: receivers (`kafka`, `filelog`, `journald`, `hostmetrics`, `k8sobjects`, `syslog`...), processors (`transform`/OTTL, `tail_sampling`, `routing`, `k8sattributes`, `filter`...), exporters (`loki`, `datadog`, `honeycomb`, `prometheusremotewrite`...).

En la practica, **contrib** es lo que se usa en produccion. Las "distros" vendor (ADOT, Grafana Alloy, Splunk) son builds de componentes seleccionados; funcionalmente similares a contrib con extensiones propias.

Verificar siempre:

```sh
otelcol validate --config=file.yaml       # core
otelcol-contrib validate --config=file.yaml   # contrib
```

El binario rechazara la config si menciona un componente no incluido en la distro.

## 3. El modelo de pipelines

Una **pipeline** procesa **una** signal (traces, metrics o logs). No se pueden mezclar signals en la misma pipeline. Un Collector puede tener N pipelines, incluso varias para la misma signal con nombres distintos (`traces/main`, `traces/tail-sampled`).

Esqueleto conceptual:

```
pipeline(signal) = receivers[] -> processors[] (ordered) -> exporters[]
```

Diagrama de un Collector tipico:

```
                 +----------------- Collector -----------------+
OTLP (gRPC/HTTP) |                                             |
Prometheus scrape|  traces:  [otlp]  -> [memlim,batch] -> [otlp/tempo]
Jaeger thrift  ->|                                             |
Zipkin JSON    ->|  metrics: [otlp,prometheus] -> [memlim,batch] -> [prw]
filelog         |                                              |
journald      ->|  logs:    [otlp,filelog] -> [memlim,batch] -> [loki]
                 +---------------------------------------------+
```

Los componentes son **declarativos**: cada uno se define una vez en su catalogo (`receivers:`, `processors:`, `exporters:`) y luego las pipelines **lo referencian por nombre**.

## 4. Receivers

Reciben datos. Los mas comunes:

| Receiver | Signal(s) | Notas |
|----------|-----------|-------|
| `otlp` | traces, metrics, logs | gRPC `:4317`, HTTP `:4318`. El default moderno. |
| `prometheus` | metrics | Scrape de endpoints `/metrics` (config estilo prometheus.yml). |
| `jaeger` | traces | Thrift gRPC/HTTP, para apps legacy. |
| `zipkin` | traces | HTTP JSON v2. |
| `kafka` | traces, metrics, logs | Consumer de topics con payload OTLP. |
| `filelog` | logs | Lee archivos (nginx, app logs). |
| `journald` | logs | Lee `systemd-journald`. |
| `hostmetrics` | metrics | CPU, memoria, disco, red del host. |
| `k8sobjects` | logs | K8s events y objetos como log stream. |

Un receiver puede alimentar varias pipelines. Ejemplo: `otlp` entra a `traces`, `metrics` y `logs` simultaneamente.

## 5. Processors

Los processors transforman o filtran los datos. **El orden importa** porque cada processor recibe lo que el anterior le pasa.

**Reglas de pulgar:**

1. `memory_limiter` **siempre primero** — si no hay memoria libre, rechaza en el borde en vez de encolar y morir.
2. Enriquecedores (`resource`, `attributes`, `k8sattributes`) despues: anaden metadata estable.
3. Filtros (`filter`, `tail_sampling`) a continuacion: dropean lo que no interesa (ahorra downstream).
4. Transformacion compleja (`transform` con OTTL) donde haga falta.
5. `batch` **siempre ultimo** — agrupa para exportar eficientemente.

Lista corta:

- **`memory_limiter`**: monitorea RSS; si pasa el soft limit, hace GC; si pasa el hard limit, rechaza datos (devuelve error al receiver).
- **`batch`**: agrupa N items o espera T ms para exportar un unico request.
- **`attributes`**: `insert`, `update`, `upsert`, `delete`, `hash` sobre atributos de span/metric/log.
- **`resource`**: lo mismo pero sobre atributos del Resource (`service.name`, `deployment.environment`...).
- **`filter`**: dropea items que matchean una expresion.
- **`transform`** (OTTL): mini-lenguaje para `set(attributes["foo"], "bar") where resource.attributes["k"] == "v"`. Poderoso.
- **`tail_sampling`**: espera a que se completen los traces (buffer en memoria por `decision_wait`) y decide con policies (`status_code`, `latency`, `probabilistic`).
- **`routing`**: envia a distintos exporters segun atributo (tenant, env).

## 6. Exporters

Envian al backend. Comunes:

| Exporter | Destino | Protocolo |
|----------|---------|-----------|
| `otlp` | Otro Collector / backend OTel-nativo | gRPC |
| `otlphttp` | Idem via HTTP (util para Tempo, Jaeger moderno, Honeycomb) | HTTP |
| `prometheusremotewrite` | Prometheus, Mimir, VictoriaMetrics | remote_write |
| `prometheus` | Expone `/metrics` para que otro servicio scrape | pull |
| `loki` | Grafana Loki | HTTP |
| `datadog`, `honeycomb` | SaaS vendors | HTTP, OTLP |
| `debug` | stdout del Collector (antes `logging` exporter) | — |
| `file` | escribe a disco (JSON lines) | — |

**`debug` y `file`** son los dos amigos del troubleshooting: muestran *exactamente* que esta llegando y que esta saliendo.

Cada exporter soporta `sending_queue` (buffer en memoria o disco) y `retry_on_failure` (backoff) — critico en produccion.

## 7. Un Collector minimo

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 400
    spike_limit_mib: 100
  batch:
    send_batch_size: 1024
    timeout: 2s

exporters:
  debug:
    verbosity: detailed

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [debug]
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [debug]
    logs:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [debug]
  telemetry:
    logs:
      level: info
```

Validar antes de levantar:

```sh
otelcol-contrib validate --config=config.yaml
```

## 8. OTTL — OpenTelemetry Transformation Language

OTTL es el DSL del `transform` processor (y de algunos otros como `filter` y `routing`). Permite expresiones sobre `attributes`, `resource.attributes`, `name`, `status`, etc.

```yaml
processors:
  transform:
    trace_statements:
      - context: span
        statements:
          - set(attributes["deployment.environment"], "prod")
          - set(attributes["team"], "payments") where resource.attributes["service.name"] == "checkout"
          - delete_key(attributes, "pii.email")
    metric_statements:
      - context: datapoint
        statements:
          - set(attributes["deployment.environment"], "prod")
```

OTTL permite condicionales (`where`), funciones (`Concat`, `Substring`, `Hash`), y manipulacion de arrays. Es la navaja suiza para no tener que escribir un processor custom en Go.

Tambien existe el processor `attributes` mas simple:

```yaml
processors:
  attributes:
    actions:
      - key: deployment.environment
        value: prod
        action: upsert
```

Para operaciones triviales (set, delete, hash), `attributes`/`resource` suelen bastar y son mas legibles. OTTL brilla con condicionales y transformacion.

## 9. Multi-pipeline y multi-exporter

Un mismo receiver puede alimentar varias pipelines; una misma pipeline puede abanicar a varios exporters:

```yaml
service:
  pipelines:
    traces/main:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp/tempo, debug]
    traces/sampled:
      receivers: [otlp]
      processors: [memory_limiter, tail_sampling, batch]
      exporters: [otlp/datadog]
```

Dos usos tipicos:

1. **Migracion de backend**: `exporters: [otlp/old, otlp/new]` manda a los dos a la vez; comparas; cuando el nuevo esta OK, quitas el viejo. Cero cambios en el productor.
2. **Observabilidad del Collector mismo**: pipeline `metrics/collector` que recibe de `prometheus` (scrape del propio Collector) y exporta a Prometheus. "Meta-telemetry".

## 10. service.telemetry y observabilidad propia

El bloque `service.telemetry` configura logs y metricas del Collector mismo:

```yaml
service:
  telemetry:
    logs:
      level: info
      encoding: json
    metrics:
      address: 0.0.0.0:8888   # expone /metrics del propio Collector
```

Metricas importantes para alertar:

- `otelcol_exporter_send_failed_*` — perdida silenciosa si no se vigila.
- `otelcol_receiver_refused_*` — el Collector esta rechazando (memoria).
- `otelcol_processor_batch_batch_send_size` — tamano real de los batches.
- `otelcol_processor_dropped_*` — items tirados por `memory_limiter` o filtros.

Sin monitorear estas metricas, un Collector puede estar perdiendo datos y nadie se da cuenta.

## 11. Depuracion y validacion

Flujo recomendado al construir una config nueva:

1. Escribir el YAML.
2. `otelcol-contrib validate --config=config.yaml` — detecta tipos, nombres de componentes, campos faltantes.
3. Arrancar con `exporters: [debug]` y `verbosity: detailed`.
4. Mandar datos de prueba (ver ejemplos y actividades).
5. Confirmar que el `debug` imprime lo esperado.
6. Reemplazar `debug` por el exporter real; dejar `debug` en paralelo durante el bringup.
7. Vigilar `service.telemetry.metrics` del propio Collector.

**Si no llegan datos al backend**, revisar en orden: receiver abierto en el puerto correcto; el productor apunta al endpoint correcto; `memory_limiter` no esta rechazando (ver metrica `refused`); el exporter apunta al endpoint correcto y con el protocolo correcto (gRPC vs HTTP); TLS y auth (en produccion).

## 12. Resumen y antipatrones

**Lo que si:**

- Core vs contrib: elegir contrib en produccion (y verificar que los componentes usados estan ahi).
- Una pipeline por signal; nombrar `traces/main`, `traces/sampled` cuando hay mas de una.
- `memory_limiter` primero, `batch` ultimo, siempre.
- `debug`/`file` exporter durante bringup; retirarlos en produccion.
- `otelcol validate` en CI/CD antes de desplegar config nueva.
- Monitorear el Collector mismo via `service.telemetry.metrics`.

**Antipatrones:**

- Omitir `memory_limiter` -> OOMKill bajo spike.
- Poner `batch` antes de `attributes`/`transform` -> procesas por item cuando podrias por batch, mas caro.
- Un unico Collector sin backup para toda la empresa -> SPOF.
- Multi-exporter a 5 backends siempre -> trafico y costo 5x sin beneficio.
- Usar `transform` para lo que `attributes` hace -> ilegibilidad gratuita.
- Config sin `otelcol validate` -> el error aparece en runtime, no en CI.
- No vigilar `otelcol_exporter_send_failed_*` -> perdida silenciosa.

Con esto cubres el 80% de lo que el Collector hace. El 20% restante (tail sampling, operator en K8s, agent+gateway, security hardening) son los modulos 09-13.
