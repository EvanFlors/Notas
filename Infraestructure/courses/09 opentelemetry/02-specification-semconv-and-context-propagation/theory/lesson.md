# Lección: Specification, Semconv and Context Propagation

> **ID:** `otel-02-specification-semconv-and-context-propagation` · **Nivel:** fundamentos · **Duración:** 3 h
> **Prerrequisitos:** `otel-01-what-and-why-signals-and-maturity`.

---

## 1. Introducción intuitiva

Imagina tres servicios: **gateway** (Node.js) → **orders** (Python) → **payments** (Go). Un usuario hace una petición. Si todo está bien instrumentado, en tu backend de tracing ves **un solo trace** con tres spans anidados, uno por servicio, con sus latencias, sus errores, sus atributos.

Ahora pregúntate: ¿cómo saben esos tres servicios, escritos en tres lenguajes distintos, que **pertenecen a la misma petición**? Ninguno importa librerías del otro. Ninguno se conoce. Y, sin embargo, sus spans se unen correctamente.

La respuesta son los **tres pilares silenciosos** de OpenTelemetry que este módulo cubre:

1. Una **especificación** común que define qué es un span, un trace, un atributo, cómo se serializa, cómo viaja.
2. Unas **convenciones semánticas** que dicen "el método HTTP se llama `http.request.method`, no `method`, no `httpMethod`, no `http_method`".
3. Un **mecanismo de propagación**: cada hop HTTP lleva un header `traceparent` con el trace-id compartido. Es un string de 55 caracteres estandarizado por **W3C** (no por OTel: OTel lo adopta).

Si entiendes estas tres piezas, entiendes **por qué OTel funciona en el mundo real** y por qué un dashboard con RED de 50 servicios no es magia, es disciplina de atributos y de propagación.

---

## 2. Fundamentos: anatomía de la especificación

La **spec** de OpenTelemetry (repositorio `open-telemetry/opentelemetry-specification`) está dividida en capas con responsabilidades distintas. Confundirlas es la fuente más común de malentendidos.

### 2.1 API

Es la **interfaz** que importa el código de aplicación. Define tipos como `Tracer`, `Span`, `Meter`, `Counter`, `Logger`, `LogRecord`, `Context`, `Baggage`. **Ningún comportamiento real**: solo contratos.

```python
from opentelemetry import trace
tracer = trace.get_tracer(__name__)      # API: devuelve un no-op si no hay SDK
with tracer.start_as_current_span("op"): # API: contract de span
    ...
```

Si una librería (por ejemplo, un cliente HTTP) quiere emitir spans, importa la **API**. No fuerza a nadie a usar un SDK concreto.

### 2.2 SDK

Es la **implementación** por defecto. Se inicializa una sola vez en `main()`. Configura:

- **Providers** (`TracerProvider`, `MeterProvider`, `LoggerProvider`).
- **Processors** (`BatchSpanProcessor`, `SimpleSpanProcessor`).
- **Exporters** (OTLP gRPC, OTLP HTTP, consola, Jaeger, …).
- **Samplers**, **Resource**, **Views** (para metrics).
- **Propagators**.

Si no hay SDK registrado, la API funciona en modo **no-op**: compila y corre, pero no emite nada. Esto es un rasgo de diseño: una librería puede estar siempre instrumentada sin coste si el consumidor no activa el SDK.

### 2.3 Data model

Define cómo se estructuran las señales *independientemente del lenguaje*:

- **Span**: `trace_id` (16 bytes), `span_id` (8 bytes), `parent_span_id`, `name`, `kind` (SERVER/CLIENT/PRODUCER/CONSUMER/INTERNAL), `start_time`, `end_time`, `status`, `attributes`, `events`, `links`, `resource`, `scope`.
- **Metric**: `name`, `description`, `unit`, `data` (sum / gauge / histogram / exponential histogram / summary), con temporalidad `cumulative` o `delta`.
- **LogRecord**: `timestamp`, `severity_number`, `severity_text`, `body`, `attributes`, `trace_id`, `span_id`, `resource`.

El data model es **el contrato** entre SDKs y backends. Si lo cumples, tus datos cruzan cualquier combinación.

### 2.4 Protocol (OTLP)

**OpenTelemetry Protocol** es la serialización oficial sobre `gRPC` y `HTTP` (`protobuf` binario o `protobuf-JSON`). Puertos convencionales: `4317` (gRPC) y `4318` (HTTP). Todo producto que acepta OTLP es, por diseño, intercambiable con cualquier otro: ésa es la base técnica de la portabilidad vendor-neutral.

---

## 3. Contexto histórico de la spec

La spec nació fusionando dos herencias:

- **OpenTracing** (2016, CNCF): sólo tracing API, agnóstico de implementación. Falló por falta de ergonomía SDK unificada y porque metrics quedaron fuera.
- **OpenCensus** (2017, Google): tracing + metrics, con SDK propio por lenguaje. Mejor cohesión pero menor adopción comunitaria.

En **2019** se funden en OpenTelemetry y se decide, deliberadamente, **publicar la spec primero y los lenguajes después**. Resultado: en cualquier lenguaje con SDK OTel, los conceptos son los mismos y los atributos se llaman igual. Esto es exactamente lo que fallaba en el mundo pre-OTel (cada vendor con su propio esquema).

El trade-off: la spec es **densa** (cientos de páginas). Pero sólo necesitas dominar un subconjunto para operar: data model + semconv + propagación. Eso es este módulo.

---

## 4. Resource: atributos del productor

Un **Resource** es un conjunto de atributos que describe **la entidad que emite telemetría** (típicamente un proceso de servicio). Se adjunta **una vez** por proceso, no por span.

### 4.1 Atributos canónicos

| Clave | Significado | Ejemplo |
|-------|-------------|---------|
| `service.name` | **Obligatorio**. Nombre lógico del servicio. | `orders-api` |
| `service.version` | Versión del artefacto. | `1.4.2` |
| `service.instance.id` | ID único de la instancia. | `pod-abc-xyz` |
| `service.namespace` | Agrupación lógica. | `checkout` |
| `deployment.environment` | Entorno de despliegue. | `production` |
| `host.name` | Hostname. | `node-7` |
| `host.arch` | Arquitectura. | `amd64` |
| `os.type` | Sistema operativo. | `linux` |
| `process.pid` | PID. | `1234` |
| `telemetry.sdk.name` / `.language` / `.version` | **Lo pone el SDK solo**. | `opentelemetry`, `python`, `1.26.0` |

### 4.2 Resources en Kubernetes

El processor `k8sattributes` del Collector enriquece cada señal con:

- `k8s.pod.name`, `k8s.pod.uid`
- `k8s.namespace.name`
- `k8s.deployment.name`
- `k8s.node.name`
- `k8s.container.name`

Esto es **oro** operacional: ya no tienes que esperar a que el equipo de la app declare "soy el pod X del namespace Y". El Collector lo adjunta por ti a partir de la IP de origen y la API de K8s.

### 4.3 Por qué no se repite por span

En un trace de 50 spans de un mismo servicio, repetir `service.name=orders-api` cincuenta veces es desperdicio en wire format y en storage. OTLP lo envía **una vez por batch** gracias a la agrupación `ResourceSpans → ScopeSpans → Spans`. El Resource es la clave de agrupación.

Regla práctica: **Resource = quién soy** (constante por proceso). **Span attributes = qué hice en esta operación** (variable).

---

## 5. Semantic Conventions: por qué un vocabulario común

Si cada equipo decide "voy a llamar al método HTTP `method`", "yo lo llamo `httpMethod`", "yo `http.verb`", entonces un dashboard que agrega latencias por método se vuelve imposible. Las **semantic conventions** (semconv) son la solución comunitaria: un repositorio (`open-telemetry/semantic-conventions`) con *todos* los nombres estandarizados.

### 5.1 Dominios vigentes

- **http** (`http.request.method`, `http.response.status_code`, `url.full`, `url.path`, `server.address`, …).
- **db** (`db.system.name`, `db.query.text`, `db.collection.name`, `db.operation.name`).
- **messaging** (`messaging.system`, `messaging.destination.name`, `messaging.operation.type`).
- **rpc** (`rpc.system`, `rpc.service`, `rpc.method`).
- **k8s** (ya cubierto en Resource).
- **faas** (`faas.name`, `faas.version`, `faas.trigger`).
- **cloud** (`cloud.provider`, `cloud.region`, `cloud.availability_zone`).
- **network** (`network.peer.address`, `network.protocol.name`, `network.transport`).

Cada dominio tiene su spec propia dentro del repo, versionada.

### 5.2 Namespaces jerárquicos con punto

Los nombres siguen `dominio.subdominio.atributo`. **No** usar `camelCase`, **no** usar guiones. Esta jerarquía permite que un backend ofrezca autocomplete / agrupaciones por prefijo (`http.*`, `db.*`).

### 5.3 Required / Recommended / Opt-In

Cada atributo tiene un **nivel de obligatoriedad** en la spec:

- **Required**: debe emitirse siempre que la operación lo tenga.
- **Conditionally required**: obligatorio bajo condiciones (p. ej. `http.response.status_code` solo si hay respuesta).
- **Recommended**: debería emitirse si no es caro.
- **Opt-In**: útil pero costoso o sensible; sólo si el usuario lo activa (p. ej. `db.query.text` con parámetros).

Esto importa para el **presupuesto de cardinalidad**: no todo atributo debe emitirse siempre.

---

## 6. La migración `http.method` → `http.request.method` como caso real

Hasta la semconv HTTP **v1.20 (2023)**, el atributo HTTP se llamaba `http.method`. En la **v1.23** se renombró a `http.request.method` (y análogamente `http.status_code` → `http.response.status_code`, `http.url` → `url.full`, `http.target` → `url.path`, `http.host` → `server.address`).

Esto es un **breaking change** en semconv, y es el patrón que te vas a encontrar siempre que la spec evolucione.

### 6.1 Por qué cambió

El renombre normaliza el prefijo: todo lo que es request va bajo `http.request.*`, todo lo que es response bajo `http.response.*`, y los campos de URL van bajo `url.*` (compartidos con otros dominios como messaging). Es una normalización deliberada, aunque dolorosa.

### 6.2 Qué rompe en la práctica

- **Dashboards** de Grafana que agrupan por `http.method` dejan de ver nada si la nueva instrumentación emite `http.request.method`.
- **Alertas** que filtran por `http.status_code >= 500` fallan.
- **Queries ad-hoc** en Tempo/Loki/Prometheus que usan los labels viejos.

### 6.3 Estrategia de migración: dual-emit transitorio

El patrón recomendado por la comunidad es:

1. **Flag** en el SDK o en el Collector (`OTEL_SEMCONV_STABILITY_OPT_IN`) para emitir **ambos** nombres durante una ventana.
2. **Dashboards**: actualizar primero a usar `coalesce(new, old)` o duplicar paneles.
3. **Cutoff**: tras N semanas con dual-emit, apagar los viejos.

Hacerlo "en caliente" sin dual-emit **rompe la observabilidad justo cuando más la necesitas** (durante una migración).

### 6.4 Lectura obligatoria

La activity `01-identify-breaking-semconv-change` te enfrenta exactamente a este escenario: tres versiones de un SDK emitiendo mezclado. Tienes que *detectar* qué está obsoleto y *proponer* el plan de migración.

---

## 7. W3C Trace Context: el header `traceparent`

**W3C Trace Context** es una recomendación W3C (no OTel) que define cómo propagar el contexto de un trace a través de HTTP. OTel la adopta como propagador por defecto.

### 7.1 Formato

```
traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
             │  │                                │                │
             │  │                                │                └─ trace flags (hex, 1 byte)
             │  │                                └─ parent span id (hex, 8 bytes = 16 chars)
             │  └─ trace id (hex, 16 bytes = 32 chars)
             └─ version (hex, 1 byte = 2 chars). Actualmente "00".
```

- **version**: `00` hoy. Reservado para evolución.
- **trace-id**: 128 bits. Único por trace. Debe ser aleatorio no-cero.
- **parent-id** (a.k.a. `span-id` del emisor): 64 bits. Es **el span id del caller**, que será el `parent_span_id` del próximo span.
- **flags**: 1 byte. Bit 0 = `sampled` (1 = este trace está siendo sampled; respeta la decisión aguas abajo).

Longitud total: **55 caracteres**. Siempre lowercase hex. Siempre con los guiones.

### 7.2 `tracestate` (opcional, acompaña a `traceparent`)

Es un header separado con pares `key=value` separados por coma, pensado para que **vendors específicos** adjunten metadata adicional sin colisionar.

```
tracestate: congo=t61rcWkgMzE,rojo=00f067aa0ba902b7
```

OTel lo usa internamente para **consistent sampling** entre servicios (ver `otel-10`).

### 7.3 Por qué este formato y no otro

- **Fijo en tamaño** → parseable sin regex, O(1).
- **Hex lowercase** → sin ambigüedad por case-insensitive de HTTP headers.
- **Versionado** → futuro-compatible.
- **Un sólo header** para el 99% del uso → gateways y proxies lo propagan sin dolor.

Antes de W3C existían `X-B3-TraceId` + `X-B3-SpanId` + … (Zipkin) o `uber-trace-id` (Jaeger). W3C los reemplaza con interoperabilidad real.

---

## 8. Baggage: potente y peligroso

**Baggage** es un conjunto de pares `clave=valor` que viaja junto al contexto, también propagado por un header HTTP (`baggage`).

### 8.1 Formato

```
baggage: userId=u-123,tenant=acme,experiment=checkout-v2
```

- Separado por comas; cada par `key=value`; URL-encoded si contiene caracteres especiales.
- Opcionalmente puede llevar metadata: `userId=u-123;sampled=true`.

### 8.2 Casos de uso legítimos

- **Correlación de negocio** cross-service: todos los spans del request pueden leer `tenant` del Baggage y adjuntarlo como atributo si lo deciden.
- **Routing** en el Collector: una policy de sampling tail puede decidir "si `tenant=enterprise`, sampled 100%".
- **Feature flags** propagados.

### 8.3 Por qué es peligroso

- **Viaja en cada hop**: cada byte extra se paga N veces por request. Un Baggage de 2 KB con 10 hops = 20 KB solo de headers.
- **Cardinalidad explosiva** si se mete `userId` en Baggage *y* se promueve a span attribute en cada hop → métricas con N labels por usuario = colapso de Prometheus.
- **PII**: Baggage **no está cifrado**. Mandar `email` o `ssn` ahí es un pecado.
- **Confianza entre servicios**: cualquier cliente puede enviar Baggage. No lo trates como entrada confiable.

Regla práctica: **Baggage es para valores pequeños, estables, no sensibles**. Si dudas, no lo pongas.

---

## 9. Context: el objeto portable intra-proceso

Dentro de un proceso, OTel modela el contexto como un **objeto inmutable** llamado `Context`. Contiene:

- El span activo (`current span`).
- El Baggage actual.
- Otros valores que SDK/instrumentations quieran adjuntar (p. ej. correlación de framework).

### 9.1 Current context

Cada hilo (o `ContextVar` en Python async) tiene **un** context activo. `tracer.start_as_current_span(...)` hace dos cosas:

1. Crea un span nuevo con parent = span del context actual.
2. Lo "ata" al context, volviéndose el nuevo current. Al salir, se restaura el anterior.

Si olvidas la parte "as current" y haces sólo `tracer.start_span(...)`, el span existe pero **no** se vuelve current → spans hijos no lo verán como parent → trace roto.

### 9.2 Context en código async

En Python async, el context se mantiene vía `contextvars.ContextVar`. Normalmente "simplemente funciona", pero cuando lanzas tareas con `concurrent.futures.ThreadPoolExecutor` el context **no se copia solo** → hay que usar `contextvars.copy_context().run(fn)` o helpers de OTel. Esto se cubre en profundidad en `otel-07`.

---

## 10. Propagators: inject y extract

Un **TextMapPropagator** sabe cómo:

- **`inject(context, carrier, setter)`**: escribe el context en el carrier (típicamente un dict de headers). Antes de hacer una llamada HTTP saliente.
- **`extract(carrier, getter) -> context`**: lee el carrier recibido y reconstruye un context. Al entrar un request HTTP.

### 10.1 Defaults de OTel

Por default (y por configuración `OTEL_PROPAGATORS=tracecontext,baggage`), el SDK combina **W3C Trace Context** y **W3C Baggage**. Otros propagators disponibles:

- `b3` / `b3multi` (Zipkin, por compatibilidad).
- `jaeger` (`uber-trace-id`).
- `xray` (AWS X-Ray).
- `ottrace` (OpenTracing legacy).

### 10.2 Composición

El propagator por defecto es un `CompositePropagator` que **inyecta todos** y **extrae del primero que haya**. Esto permite que un sistema reciba traces en formato Zipkin y los re-emita como W3C.

### 10.3 El error #1: no activar propagators

Si usas el SDK pero no tienes propagators configurados (o los has sobrescrito mal), tu HTTP client sale **sin** `traceparent` → el próximo servicio arranca un trace nuevo → el trace se corta.

Síntoma típico: "veo spans sueltos de 1-2 operaciones, nunca el trace completo end-to-end". Causa 90% de las veces: propagators mal configurados o instrumentation library faltante en el cliente HTTP.

---

## 11. Buenas prácticas y pitfalls

### 11.1 Resource

- Pon `service.name` desde el día uno; sin él, los backends muestran spans "unknown_service".
- Deja que `telemetry.sdk.*` lo rellene el SDK. No lo pongas manualmente.
- En K8s, deja que el processor `k8sattributes` del Collector enriquezca; no dupliques `k8s.*` en el SDK.

### 11.2 Semconv

- Usa siempre nombres de semconv estándar antes que inventar.
- Si inventas, prefija con tu organización: `acme.user.plan`, nunca `userPlan`.
- Documenta tus atributos custom; nadie los adivinará.
- Vigila migraciones (`http.method` → `http.request.method`); planifica dual-emit.

### 11.3 Baggage

- Nunca metas PII.
- Mantén el tamaño total < 256 bytes idealmente, nunca > 1 KB.
- Decide por servicio si **promover Baggage a span attribute** (coste de cardinalidad) o **sólo usarlo para decisiones** (routing/sampling).

### 11.4 Propagators

- No sobrescribas `OTEL_PROPAGATORS` salvo necesidad clara.
- Si estás en un ecosistema mixto, añade `b3multi` para compatibilidad con sistemas legacy.
- Verifica, al menos una vez por servicio nuevo, que `traceparent` sale en los headers de egress (curl -v, debugger de red).

### 11.5 Testing

- En CI, añade un check que grepea `OTEL_SERVICE_NAME` / `service.name` en los manifiestos.
- Añade un test E2E barato: lanzar request a servicio A, verificar que el span tiene `trace_id` y que servicio B recibe el mismo `trace_id`.

---

## 12. Preguntas de evaluación

Responde sin consultar el material:

1. ¿Qué partes de la spec son "contrato con el código de aplicación" y cuáles son "contrato con el backend"?
2. Dado un `traceparent: 00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01`, extrae trace-id, span-id y flag `sampled`. ¿Qué significa cada uno?
3. ¿Por qué el Resource no se repite por span? ¿Cómo lo serializa OTLP?
4. Enumera 3 casos legítimos de uso de Baggage y 3 anti-casos.
5. ¿Qué pasa si una app usa `tracer.start_span` en vez de `tracer.start_as_current_span`? Describe el síntoma visible en el backend.
6. Dado un servicio que emite `http.method=GET` y otro que emite `http.request.method=GET`, ¿cómo construyes un dashboard que funcione para ambos durante la migración?
7. ¿Qué header debe salir de un cliente HTTP instrumentado con OTel por defecto? ¿Cómo verificarías que sale efectivamente?
