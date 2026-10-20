# otel-01 — Lección: qué es OTel, señales y madurez

> 12 secciones. 100 % conceptual. Prerrequisito: curso `prometheus-grafana` ≥ `obs-02`.

---

## 1. Punto de partida: el problema que OTel resuelve

Antes de OTel, instrumentar una aplicación para observabilidad era un ejercicio de **tres fragmentaciones** simultáneas:

1. **Fragmentación por pilar.** Las métricas usaban un cliente (`prometheus_client`, StatsD), los traces otro (Jaeger client, Zipkin brave, X-Ray SDK), y los logs **otro mundo entero** (`logging` estándar + agentes como Fluentbit). Cada uno con su modelo de datos y su protocolo.
2. **Fragmentación por lenguaje.** Cada lenguaje tenía *su propia* librería de tracing: `opentracing-python`, `brave` (Java), `jaeger-client-go`, `zipkin-cpp`. Semánticas distintas, nombres de atributos distintos, propagators distintos.
3. **Fragmentación por vendor.** Datadog, New Relic, Dynatrace y Splunk ofrecían sus **propios** SDKs. Instrumentar con el SDK de Datadog **ataba** el código a Datadog; migrar implicaba re-instrumentar todo.

El resultado: equipos que compraban una herramienta por su UI y luego **no podían salir** sin reescribir código en N servicios en M lenguajes. **Vendor lock-in de observabilidad** a nivel de código fuente.

OTel ataca las tres fragmentaciones a la vez:

- **Un** modelo de datos (traces + metrics + logs bajo el mismo `Resource` y `Context`).
- **Una** API/SDK por lenguaje, mantenida por la CNCF y adoptada por todos los vendors.
- **Un** protocolo wire (**OTLP**) que todos los backends saben recibir.

> **Idea clave que repetiremos:** OTel es la **capa de generación + transporte + semántica**. **No es un backend.** No almacena, no consulta, no dibuja dashboards.

---

## 2. Historia: la fusión que faltaba (2016 → 2019 → hoy)

```
                  2016                   2017
                   │                      │
      OpenTracing (CNCF, API)   OpenCensus (Google, API+SDK+Collector)
                   │                      │
                   │       (overlap)      │
                   └──────────┬───────────┘
                              │
                           2019
                              │
                      ┌───────▼───────┐
                      │ OpenTelemetry │  (CNCF, fusión formal)
                      └───────┬───────┘
          ┌───────────────────┼───────────────────┐
          │                   │                   │
       2021 GA             2022 GA             2023 GA
       Tracing             Metrics             Logs
          │                   │                   │
          └────────┐          │          ┌────────┘
                   │          │          │
                   ▼          ▼          ▼
                 2024+  Profiling (incubación)
                        Semconv HTTP v1
                        OTLP ingest nativo en Prometheus
                        Auto-instrumentation + eBPF (Beyla, Pixie)
```

- **OpenTracing** (2016) definía una API neutra de **tracing**. No incluía SDK ni implementación. Varios vendors (Jaeger, Zipkin) la adoptaron como fachada.
- **OpenCensus** (2017, Google) era un stack más completo: **API + SDK + Collector** y cubría **tracing + metrics**. Más opinativo que OpenTracing.
- Ambos competían por el mismo nicho con **modelos ligeramente incompatibles**. La comunidad perdía energía.
- **2019** — la CNCF orquesta la fusión: nace **OpenTelemetry**, con la ambición de cubrir **los tres pilares** bajo el mismo modelo.
- **2021 → 2023** — los signals maduran por orden: **tracing** primero (la deuda que arrastraban), **metrics** después, **logs** al final (eran los más difíciles por tener que convivir con los sistemas de logging existentes).
- **2024+** — **profiling** entra en incubación, **semconv** se estabiliza en HTTP v1, y **Prometheus** gana OTLP ingest nativo (ya no hace falta `prometheusremotewrite` para muchos casos).

Mensaje a llevar: OTel **no inventó** las ideas (traces, métricas, context propagation ya existían). Las **unificó** bajo un mismo paraguas CNCF y resolvió la guerra OpenTracing vs OpenCensus.

---

## 3. Los tres signals (y el que viene)

OTel modela la telemetría como **signals**. Cada signal tiene su propia API, su propio SDK y su propia parte de OTLP, pero comparten `Resource` y `Context`.

### 3.1 Traces

Un **trace** es un árbol de **spans**. Cada span representa una **unidad de trabajo** (una llamada HTTP, una query SQL, una función interna) con `start_time`, `end_time`, `attributes`, `events`, `status` y una relación `parent → child`.

- Responde a: *"¿por qué este request concreto tardó 2 s?"*, *"¿qué pasó entre que entró a `POST /checkout` y salió?"*.
- Clave para **debugging** y **análisis de latencia**.
- Dato primitivo: el **trace_id** (único por request) + **span_id** (único por operación) propagados vía header `traceparent` (W3C Trace Context — módulo `otel-02`).

### 3.2 Metrics

Una **metric** es una medición numérica agregada en el tiempo. OTel soporta `Counter`, `UpDownCounter`, `Histogram`, `Gauge`, y variantes **Observable** vía callbacks.

- Responde a: *"¿cuántos 5xx hubo en la última hora?"*, *"¿cuál es la p95 de latencia de este endpoint?"*.
- Clave para **alerting**, **SLOs** y **dashboards agregados**.
- A diferencia de Prometheus client puro, OTel distingue **temporality**: `cumulative` (desde el inicio del proceso, compatible con Prometheus) vs `delta` (cambio en el intervalo, compatible con StatsD/Datadog). Esto se profundiza en `otel-05`.

### 3.3 Logs

Un **log record** OTel es un evento discreto con `timestamp`, `severity`, `body`, `attributes`, `resource`, y — crucialmente — `trace_id` + `span_id` cuando se emite dentro de un span activo.

- Responde a: *"¿qué pasó exactamente en el request con `trace_id=abc...`?"*.
- Es el signal **más joven** de OTel: GA en 2023. El patrón recomendado **no** es "reemplaza tu `logging`", sino **adjuntar** el OTel Logging Handler/Bridge para que cada log existente se convierta en un `LogRecord` OTLP enriquecido con contexto. Esto se profundiza en `otel-06`.

### 3.4 Profiling (incubación)

El cuarto signal, aún en **incubación** al momento de escribir este módulo: **continuous profiling** (CPU, heap, allocations) con el mismo modelo de `Resource` y `Context` que los otros signals.

- Responde a: *"¿en qué función se me va el 40 % del CPU?"*, *"¿este leak de memoria vive en qué stack?"*.
- Herramientas pioneras: **Parca**, **Pyroscope** (ahora en Grafana), **Pixie**.
- Como está en incubación, el estudiante debe **asumir cambios** en la API/SDK hasta que llegue a GA. **Confirmar estado actual en Fase 4** (ver `resources/links.md`).

---

## 4. "Vendor-neutral": qué significa y qué no significa

El slogan de OTel es *vendor-neutral*. En la práctica se traduce en **tres garantías concretas**:

1. **El código de aplicación no sabe de qué backend se trata.** Importa `opentelemetry.trace`, no `datadog.trace`. Si mañana la organización pasa de Datadog a Grafana Cloud, el **código no cambia**: cambia la configuración del Collector.
2. **El protocolo (OTLP)** es un estándar abierto. Todos los backends serios (Datadog, Honeycomb, New Relic, Dynatrace, Grafana Cloud, Splunk, los self-hosted como Jaeger/Tempo/Loki/Prometheus) aceptan OTLP, bien nativo, bien vía exporter en el Collector.
3. **Los nombres de atributos (semconv)** están estandarizados por la CNCF. `http.request.method = "GET"` significa lo mismo en Java que en Python que en Go que en el dashboard del vendor que los recibe.

Lo que **no** significa:

- **No** significa "todos los vendors tratan la telemetría igual". El UX de búsqueda, los precios, los límites de cardinalidad, los features avanzados (correlación cross-signal, exemplars, RUM) **varían enormemente**.
- **No** significa "migrar es trivial". Significa que la **capa de instrumentación** es portable; los **dashboards, alertas y queries** siguen siendo específicos del backend (PromQL ≠ TraceQL ≠ LogQL ≠ Datadog Query).
- **No** significa "no hay lock-in posible". Si usas atributos propietarios (`dd.*`, `nr.*`, `honeycomb.*`) en tu instrumentación, el lock-in regresa por la puerta de atrás. **Disciplina de semconv** es el precio de la neutralidad real.

---

## 5. Estado de madurez: cómo leer el status page

OTel mantiene un **status page oficial** (`opentelemetry.io/status/`) con una matriz **lenguaje × signal × componente**. Cada celda está en uno de 5 estados:

| Estado | Significado práctico |
|--------|----------------------|
| **Stable (GA)** | API/SDK versionado 1.x, breaking changes solo en 2.0. Apto para producción. |
| **Beta** | Funcional, interfaz probable que estabilice pronto, cambios menores posibles. Apto para pre-prod y adopción temprana. |
| **Alpha** | Funcional en happy path, interfaz **puede romper**. No para producción crítica. |
| **Experimental** | En diseño activo, usar solo para prototipos. |
| **Not implemented** | El signal/componente no existe aún para ese lenguaje. |

Como regla gruesa al momento de escribir este módulo (confirmar en Fase 4):

- **Traces** → **Stable** en los principales lenguajes (Java, .NET, Python, Node.js, Go, Ruby, PHP, C++…). El más maduro.
- **Metrics** → **Stable** en los principales lenguajes. Maduración relativamente reciente (2022).
- **Logs** → **Stable** en los principales lenguajes, pero con **menos tiempo en producción** (GA 2023). Las instrumentation libraries y bridges todavía están alcanzando paridad con los otros signals.
- **Profiling** → **Experimental / Incubación**. **No** apto para producción.

El ejercicio `examples/02-status-page-walkthrough/` te enseña a navegar la tabla con lupa.

> **Trampa habitual:** asumir que "Python está GA" significa que **todo** en Python está GA. Un lenguaje puede tener traces Stable, logs Stable y profiling Experimental; una **instrumentation library** concreta (p. ej. `opentelemetry-instrumentation-foobar`) puede estar en Alpha aunque el SDK del lenguaje esté GA. Siempre bajar al nivel de la pieza concreta que vas a usar.

---

## 6. Por qué logs es el signal más joven

Las métricas y los traces nacieron con **modelo de datos propio** (counters, histograms; spans con parent-child). Los **logs**, en cambio, ya tenían un **ecosistema inmenso previo**: `logging` de Python, SLF4J/Logback de Java, Serilog de .NET, `log` de Go, millones de líneas de código con `log.info(...)`.

Diseñar un signal de logs implicaba:

1. **No** romper el patrón "importo mi `logging` y hago `log.info("algo")`".
2. **Añadir** correlación con el trace activo (traceId/spanId) sin que el desarrollador tenga que acordarse.
3. **Convivir** con sistemas de recolección existentes (Fluentbit, Filebeat, Vector) sin pedir que se tiren a la basura.

La solución fue el patrón **"bridge" / "appender"**: cada lenguaje tiene un **handler** OTel que se enchufa al logging nativo. Cada `log.info("algo")` genera un `LogRecord` OTLP enriquecido con `trace_id`, `span_id`, `resource` y los atributos del contexto. **No se reescribe código**; se **enchufa** el bridge en el bootstrap.

Esta complejidad explica por qué logs llegó **cuatro años** después de traces. La ventaja: hoy, cuando se adopta logs OTel, se adopta en un modelo que **ya no quiere pelearse** con `logging` existente.

---

## 7. OTel no es un backend: la pieza más mal entendida

Este es el error conceptual **número uno** cuando se descubre OTel:

> *"Entonces OTel va a reemplazar a Prometheus, ¿no?"*

**No.** OTel es la capa de **generación + transporte + semántica**. El **almacenamiento, la indexación y la consulta** siguen siendo responsabilidad de un **backend**.

Analogía rápida:

```
   OTel es a observabilidad
      lo que
   HTTP + JSON son a APIs REST
```

HTTP+JSON no son "una API"; son el **cómo** se habla. La API es el **servidor** que recibe y guarda los datos. De la misma forma, OTel es el **cómo** se emite telemetría; el **backend** (Prometheus, Tempo, Loki, Jaeger, Datadog…) es el que la almacena y la consulta.

Cuadro mental:

```
┌───────────────────────────────────────────────────────────────┐
│ ÁMBITO DE OTEL                                                │
│                                                               │
│   App code → OTel API → OTel SDK → OTLP → OTel Collector      │
│   (traces, metrics, logs)                                     │
│                                                               │
└──────────────────────────┬────────────────────────────────────┘
                           │  (exporter: Prometheus RW, OTLP,
                           │   Loki, Tempo, Jaeger, Datadog…)
                           ▼
┌───────────────────────────────────────────────────────────────┐
│ ÁMBITO DEL BACKEND (fuera de OTel)                            │
│   almacenamiento, indexación, consulta, dashboards, alerting  │
│   Prometheus / Mimir / Tempo / Loki / Jaeger / Datadog / ...  │
└───────────────────────────────────────────────────────────────┘
```

Consecuencia práctica: **cambiar de backend = cambiar un `exporter` en el Collector**. El código y los dashboards de los *vendors* son otra historia (ver §4).

---

## 8. Relación con Prometheus, Jaeger, Zipkin, Loki y vendors

Otro error habitual: creer que adoptar OTel implica **desechar** las herramientas existentes. En la mayoría de los casos **conviven**.

| Herramienta existente | Rol con OTel |
|-----------------------|--------------|
| **Prometheus** (storage + PromQL) | Sigue siendo backend de métricas. OTel exporta vía `prometheusremotewrite` o vía **OTLP ingest nativo** (reciente). Opcionalmente el Collector tiene **`prometheusreceiver`** para scrapear targets Prom existentes. |
| **Jaeger** (storage + UI de traces) | Puede ser **backend** de traces OTel (acepta OTLP). El Collector tiene **`jaegerreceiver`** para apps viejas con cliente Jaeger. |
| **Zipkin** (storage + UI de traces) | Idem Jaeger: el Collector tiene **`zipkinreceiver`** para apps con cliente Zipkin heredado. |
| **Loki** (storage + LogQL) | Backend de logs. El Collector tiene **`lokiexporter`** (o se envía vía OTLP si Loki lo soporta). |
| **Fluentbit / Vector / Filebeat** | Conviven como recolectores de logs; también pueden hablar OTLP para integrarse con el Collector. |
| **Datadog / New Relic / Honeycomb / Dynatrace / Splunk** | Backends vendor; aceptan OTLP (directo o vía exporter específico). El código deja de depender de su SDK propietario. |
| **Grafana** (UI/dashboards) | Fuera del scope de OTel; sigue siendo la UI de Prometheus/Tempo/Loki. Correlación cross-signal (exemplars, click-through trace↔log) se habilita cuando los IDs están propagados — tema de `otel-06` y `otel-11`. |

Dos puntos clave:

1. **Jaeger, Zipkin y Prometheus pre-OTel integran como receivers del Collector.** No hace falta tirarlos; se les enchufa el Collector delante y, poco a poco, se migran a emisión OTLP nativa.
2. **Lo que OTel sustituye** es la capa de **SDK propietario** del vendor y la **librería de tracing específica del lenguaje**, no el almacenamiento ni la UI.

---

## 9. Las piezas de OTel (vista rápida, se detallan después)

Para hablar con fluidez el resto del curso, hace falta ponerle nombre a las piezas:

```
┌─────────────────────────────────────────────────────────────┐
│ Application code                                            │
│   import opentelemetry.trace          ← API (contract)      │
│   tracer = get_tracer("my-service")                         │
│   with tracer.start_as_current_span("checkout"):            │
│       ...                                                   │
└──────────────────────────┬──────────────────────────────────┘
                           │ (API delegates to…)
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ SDK (per-language)       ← implementation + config          │
│   TracerProvider, MeterProvider, LoggerProvider             │
│   Processors (batch, simple), Exporters (OTLP, console…)    │
└──────────────────────────┬──────────────────────────────────┘
                           │ OTLP (gRPC or HTTP/protobuf)
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ OTel Collector           ← data plane, YAML-configurable    │
│   receivers → processors → exporters                        │
│   (routes traces/metrics/logs to backend(s))                │
└──────────────────────────┬──────────────────────────────────┘
                           │
                 ┌─────────┼──────────┐
                 ▼         ▼          ▼
            ┌────────┐ ┌───────┐ ┌─────────┐
            │ Prom / │ │ Tempo │ │  Loki / │
            │ Mimir  │ │ Jaeger│ │ Datadog │
            └────────┘ └───────┘ └─────────┘
```

- **API** — el contrato que **importa tu código**. Mínima, sin dependencias pesadas, pensada para que **librerías** la puedan usar sin forzar un SDK.
- **SDK** — la **implementación** por lenguaje, configurada en `main()`. Decide processors, exporters, sampling.
- **OTLP** — el protocolo *wire* (`gRPC` o `HTTP/protobuf`) entre SDK ↔ Collector ↔ backend.
- **Collector** — binario Go; recibe telemetría, la transforma (filter, redact, batch, sample) y la exporta a 1 o N backends. Es, en la práctica, la pieza más usada del ecosistema.
- **Semantic Conventions (semconv)** — nombres estándar de atributos y métricas. Se detallan en `otel-02`.

En este módulo basta con **saber que existen** y qué rol juegan; cada una tiene su módulo dedicado más adelante.

---

## 10. Alternativas y escenarios donde OTel todavía no es la respuesta

OTel es ambicioso, pero no es "siempre". Casos donde la respuesta sensata es **esperar**, **adoptar parcialmente** o **no adoptar**:

- **SDK del lenguaje en Alpha/Experimental.** Si tu stack es un lenguaje con SDK aún inmaduro (verificar status page), no vale la pena mover producción hasta que estabilice.
- **Signal que todavía no está GA en tu lenguaje.** Hoy esto afecta sobre todo a **profiling** (incubación) y, en algunos ecosistemas, a **logs** si la bridge/handler clave aún no está estable.
- **Equipo pequeño con un vendor APM contratado y pagado.** Si Datadog ya cubre al equipo y nadie planea cambiar en 2 años, **auto-instrumentation del vendor** suele dar más valor por hora de ingeniería. OTel entra cuando hay riesgo de lock-in o requerimiento de multi-backend.
- **Compliance / aire acotado estricto.** Entornos cerrados donde no se puede ejecutar binarios de terceros (como el Collector) sin review profundo; aquí la adopción puede empezar por **solo SDK** y exporter directo a un backend conocido.
- **Casos de observabilidad eBPF puros (Pixie, Hubble, Parca).** Son **complementarios** a OTel; para visibilidad inicial zero-code sin tocar binarios, pueden ir antes.
- **Proyectos predecesores (OpenTracing, OpenCensus).** Están **deprecados oficialmente**. Si existe código con ellos, OTel es la vía — pero la migración requiere plan.

El cuadro mental para la decisión: **¿tengo riesgo real de cambiar de backend en el horizonte 2–3 años?** Si sí, OTel ya. Si no, OTel sigue siendo mejor estándar que el SDK del vendor, pero no es urgente.

Esto se trabaja en la actividad `02-when-not-otel/` con 4 escenarios.

---

## 11. Ventajas y limitaciones honestas

**Ventajas:**

- **Estándar CNCF con adopción masiva.** Todos los vendors serios lo soportan — el precio de no soportar OTel hoy es perder clientes.
- **Vendor-neutral real** siempre que se respete semconv.
- **Un solo modelo** para los 3 pilares, con correlación nativa vía `trace_id` + `span_id` propagados.
- **Collector enormemente flexible**: una herramienta configurable por YAML sustituye a 3–4 agentes (`node_exporter` custom, `fluentbit`, `otel-agent`, `jaeger-agent`…).
- **Auto-instrumentation** gratuita en lenguajes maduros: lanzas con un wrapper (`opentelemetry-instrument` en Python) y obtienes RED básico sin tocar código.

**Limitaciones y riesgos a asumir:**

- **Madurez desigual** por lenguaje × signal × instrumentation library. **Siempre** verificar status page.
- **Semconv ha cambiado** (p. ej. `http.method` → `http.request.method`); los upgrades requieren disciplina. Se trabaja en `otel-02`.
- **Métricas con temporality** (cumulative vs delta) es el "gotcha" clásico que rompe la primera integración con Prometheus. Se trabaja en `otel-05`.
- **Tail-based sampling** (ver `otel-10`) requiere Collectors stateful; mal dimensionados, acumulan memoria y caen.
- **Overhead no trivial** si se instrumenta sin criterio (crear un span por cada operación interna, atributos de alta cardinalidad). La disciplina de qué instrumentar sigue siendo humana.
- **Curva de aprendizaje** del Collector no es trivial: pipelines, processors, OTTL (lenguaje de transformación), distribuciones (Core vs Contrib vs ADOT vs Grafana Alloy). Es un curso en sí mismo (lo cubren `otel-08` → `otel-13`).

---

## 12. Qué sigue (y qué llevarse)

Al terminar este módulo deberías poder:

- Explicar OTel a un compañero en **90 segundos** sin confundirla con un backend.
- Nombrar los **3 signals + profiling en incubación**.
- Leer el **status page** y bajar al nivel de "¿este signal, para este lenguaje, para esta instrumentation library concreta, está GA?".
- Decir, dado un stack conocido, qué piezas podrían ser **reemplazadas**, qué **convive** y qué queda **fuera**.
- Decidir, para un caso dado, si adoptar OTel **ya**, **parcialmente** o **esperar**.

Lo que **sigue**:

- `otel-02` — Spec formal, Resource, Semantic Conventions, W3C Trace Context, Baggage.
- `otel-03` — API vs SDK vs instrumentation libraries vs auto-instrumentation vs zero-code eBPF.
- Luego, Nivel 2: instrumentar Python en traces (`otel-04`), metrics (`otel-05`), logs (`otel-06`), context propagation cross-service (`otel-07`), y el Collector (`otel-08`).

Una síntesis final de una línea:

> **OTel es el estándar vendor-neutral de la CNCF para emitir traces, metrics y logs (y pronto profiling) desde cualquier lenguaje, transportarlos vía OTLP y entregarlos al backend que elijas sin acoplar tu código a él.**

Todo lo demás del curso es **cómo** hacer realidad esa frase, con sus matices y trade-offs.
