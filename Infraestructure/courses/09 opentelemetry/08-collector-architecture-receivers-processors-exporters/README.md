# otel-08-collector-architecture-receivers-processors-exporters

## Identificacion
- **ID:** `otel-08-collector-architecture-receivers-processors-exporters`
- **Nivel:** intermedio
- **Duracion estimada:** 5 h
- **Prerrequisitos:** `otel-01-what-and-why-signals-and-maturity`

## Objetivo
Entender el **OpenTelemetry Collector** como un *data plane* configurable: disenar, validar y operar pipelines (`receivers -> processors -> exporters`) para las tres senales (traces, metrics, logs), y justificar las decisiones de componentes (core vs contrib, batch vs memory_limiter, OTTL para transform, multi-exporter para migracion de backend).

## Temas y subtemas

1. **Instalacion y distribuciones**
   - Binario oficial vs contenedor (`otel/opentelemetry-collector`, `otel/opentelemetry-collector-contrib`).
   - `core` vs `contrib`: por que `contrib` trae receivers/exporters extra (Prometheus, Loki, Jaeger legacy, Kafka, filelog, journald, k8sobjects, Datadog, Honeycomb, etc.).
   - Verificacion de configuracion con `otelcol validate --config file.yaml`.

2. **Modelo de pipelines**
   - Una pipeline por **signal**: `traces`, `metrics`, `logs`.
   - Cada pipeline: `receivers -> processors (orden importa) -> exporters`.
   - Las pipelines no mezclan signals, aunque compartan Collector.

3. **Receivers comunes**
   - `otlp` (gRPC `:4317` + HTTP `:4318`) — el default moderno.
   - `prometheus` (scrape de `/metrics`).
   - `jaeger`, `zipkin` (legacy, cuando los apps no hablan OTLP).
   - `kafka` (consumer).
   - `filelog`, `journald` (logs del host).
   - `hostmetrics` (CPU, memoria, disco, red del host).
   - `k8sobjects` (K8s events y objetos como logs).

4. **Processors**
   - `memory_limiter` (**obligatorio en produccion**, primero en la cadena).
   - `batch` (eficiencia de red, debe ir despues de todos los que modifican).
   - `attributes`, `resource` (anadir/borrar/renombrar atributos; set `deployment.environment`).
   - `filter` (dropear por match de atributos o resource).
   - `transform` con **OTTL** (OpenTelemetry Transformation Language): mini-lenguaje para enriquecer, renombrar, filtrar con expresiones.
   - `tail_sampling` (stateful, decidir sobre trace completo).
   - `routing` (enviar a distintos exporters segun atributo).

5. **Exporters**
   - `otlp` (gRPC) y `otlphttp` (HTTP) hacia otros Collectors o backends OTel-nativos.
   - `prometheusremotewrite` y `prometheus` (expone `/metrics`).
   - `loki`, `otlphttp` a Tempo/Jaeger, `datadog`, `honeycomb`.
   - `debug` (antes `logging`): imprime en stdout, imprescindible para troubleshooting.
   - `file`: escribe en disco (util para tests y SKIP sin backend).

6. **Configuracion YAML**
   - `extensions`, `receivers`, `processors`, `exporters` como catalogos declarativos.
   - `service.pipelines.<signal>.{receivers,processors,exporters}` ensamblan.
   - `service.telemetry` para logs y metricas del propio Collector.

## Conceptos internos (fundamentos)

- Una pipeline **no** mezcla signals: tres pipelines distintas aunque todas vayan al mismo Collector.
- `memory_limiter` + `batch` son el "cinturon de seguridad" por default; sin `memory_limiter` el Collector OOMKillea bajo spike.
- **OTTL** es un mini-lenguaje para `transform` processor; poderoso para enriquecer / filtrar / renombrar sin recompilar.
- El orden de los processors **si** importa: `memory_limiter` primero, `batch` ultimo, enriquecedores en el medio.
- Multi-exporter duplica trafico — util para migraciones (dev + prod en paralelo), caro de default.

## Competencias

- **Conceptual:** explicar que un pipeline es `receivers -> processors -> exporters` por signal; distinguir core vs contrib; justificar OTTL.
- **Operativa:** escribir un `config.yaml` valido para las 3 signals; correr `otelcol validate`; depurar con `debug` exporter.
- **Arquitectonica:** disenar una configuracion multi-exporter para migrar de backend sin tocar el codigo del productor.

## Ejemplos

- [`examples/01-collector-yaml-skeleton/`](examples/01-collector-yaml-skeleton/) — esqueleto minimo con las 3 pipelines, `otlp` receiver y `debug` exporter.
- [`examples/02-ottl-transform/`](examples/02-ottl-transform/) — uso de `transform` processor con OTTL para enriquecer spans.
- [`examples/03-multi-exporter/`](examples/03-multi-exporter/) — una pipeline con dos exporters (debug + file) para demostrar fan-out.

## Actividades

- [`activities/01-collector-local-with-three-signals/`](activities/01-collector-local-with-three-signals/) — **guided-lab**: levantar un Collector local recibiendo las 3 signals via OTLP y escribiendolas a archivo.
- [`activities/02-add-attribute-processor/`](activities/02-add-attribute-processor/) — **independent**: anadir un `attributes` processor que setea `deployment.environment=prod` en spans y metricas de un receiver dado.

## Entregables

- `config.yaml` del Collector con las 3 pipelines definidas, validado por `otelcol validate`.
- Captura/log del output del `debug`/`file` exporter mostrando spans, metrics y logs recibidos.
- Un segundo `config.yaml` (actividad 02) con el processor de atributos aplicado y evidencia de que `deployment.environment=prod` aparece en la salida.

## Criterios de evaluacion

- **Conceptual:** justificar por que `memory_limiter` va primero y `batch` ultimo.
- **Operativa:** diagnosticar un pipeline que descarta datos silenciosamente (ej. exporter mal configurado, memoria limitada).
- **Arquitectonica:** proponer un multi-exporter para migrar backend sin downtime.

## Recursos

Ver [`resources/links.md`](resources/links.md).

## Teoria

Lectura completa en [`theory/lesson.md`](theory/lesson.md).
