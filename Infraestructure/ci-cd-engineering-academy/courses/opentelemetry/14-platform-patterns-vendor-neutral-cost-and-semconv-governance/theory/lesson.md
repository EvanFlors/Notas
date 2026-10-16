# Lección — Platform patterns: vendor-neutral, cost y semconv governance

> Prerrequisitos de lectura: `otel-11` (backends y multi-export), `otel-12` (Operator), `otel-13` (reliability y security).

Esta lección es el cierre del nivel de producción. Hasta aquí tienes todas las piezas: SDKs instrumentados, Collector endurecido, Operator en K8s, tail-sampling, TLS, auth. Lo que **no** tienes todavía es el **gobierno**: quién decide los backends, cómo se controla el gasto, cómo se mantienen las convenciones vigentes sin romper nada, y cómo se vende internamente la neutralidad vendor cuando aparece un comercial con una propuesta brillante.

## 1. Por qué la neutralidad vendor es un diseño, no un accidente

La narrativa cómoda es "usamos OTLP, por tanto somos vendor-neutral". Es falsa. OTLP es un protocolo; la neutralidad vendor es una **propiedad del sistema entero**, y se pierde en cuanto:

- Alguien pone `dd.service` o `newrelic.appname` como atributo en el código.
- Un dashboard asume que el backend es Tempo y usa `TraceQL` embebido en una app.
- Las alertas viven en una UI vendor-exclusiva (Datadog Monitors, Splunk ITSI) y no en código versionado.
- La elección de bucket histogram se hace en el SDK pensando en Prometheus `histogram_quantile`.

La neutralidad vendor exige **tres fronteras** limpias:

1. **Código de aplicación**: sólo API OTel + semconv upstream. Nada propietario.
2. **Collector**: única frontera donde se decide a qué backend se envía qué signal.
3. **Dashboards y alertas**: versionados como código, portables (Grafana JSON, Alloy rules, PromQL / LogQL / TraceQL con posibilidad de traducción). Las "experiencias" vendor-exclusivas se usan, pero no son la fuente de verdad.

Si esas tres fronteras existen y se auditan, cambiar backend es un `git diff` sobre `collector/`. Si no, el "cambio de vendor" es un refactor de 6 meses.

## 2. El contrato de plataforma — "los equipos emiten OTLP, la plataforma decide el backend"

El contrato se escribe. Es un documento corto (1-2 páginas) que vive en el repo de plataforma y es *vinculante*. Un esqueleto que funciona bien:

```
Contract: Observability v1

Scope: all production and preproduction services of Company.

Teams MUST:
  - Emit telemetry via OTLP (gRPC on 4317, HTTP on 4318) to the local Collector agent.
  - Use the SemConv package pinned by the platform (upstream version X.Y + company.* extensions).
  - Set service.name, service.namespace, service.version, deployment.environment on every Resource.
  - Propagate W3C traceparent + tracestate on every outbound call.

Teams MUST NOT:
  - Export directly to any vendor backend from the SDK.
  - Add vendor-prefixed attributes in code (dd.*, newrelic.*, splunk.*, honeycomb.*).
  - Hardcode bucket boundaries or temporality in SDK config — use the platform View preset.
  - Create >50 unique label combinations per metric (soft limit; hard-dropped at Collector).

Platform guarantees:
  - 99.9% ingest availability (Collector gateway).
  - p99 ingest-to-queryable < 60s for traces, < 30s for metrics, < 90s for logs.
  - Backend choice is a platform decision; changes are announced with 2 weeks notice; no code change required.
```

Nótese el **MUST NOT** sobre atributos vendor-prefixed. Esta prohibición es la que preserva la neutralidad. Una sola app con `dd.env` dispersa en 200 lugares es una grieta.

## 3. Cost control at the Collector — tres palancas

El Collector es el **único** lugar donde el equipo de plataforma puede recortar costo sin pedir cambios a los equipos de producto. Hay tres palancas, se combinan:

### 3.1 Tail-based sampling con quotas por servicio

El `tail_sampling` processor te permite:

- Mantener 100% de los traces con error o latencia > p95.
- Samplear el resto a un ratio por servicio (ej. `payments-api` conserva 20%, `product-catalog` 1%).

```yaml
processors:
  tail_sampling:
    decision_wait: 10s
    num_traces: 100000
    expected_new_traces_per_sec: 1000
    policies:
      - name: errors-always
        type: status_code
        status_code: {status_codes: [ERROR]}
      - name: slow-always
        type: latency
        latency: {threshold_ms: 1000}
      - name: payments-sample
        type: and
        and:
          and_sub_policy:
            - name: by-service
              type: string_attribute
              string_attribute: {key: service.name, values: [payments-api]}
            - name: ratio
              type: probabilistic
              probabilistic: {sampling_percentage: 20}
      - name: default-sample
        type: probabilistic
        probabilistic: {sampling_percentage: 2}
```

El orden de las policies **es** la política: la primera que matchea gana (con `and` para combinar). Un error en `catalog` entra por `errors-always` aunque `catalog` tenga ratio 2%.

### 3.2 Drop de métricas de alta cardinalidad

La cardinalidad explota cuando atributos *de instancia* (user id, request id, order id) terminan en labels de métricas. Pasan dos cosas: tu factura con el vendor sube linealmente con la cardinalidad, y el backend empieza a devolver timeouts en queries por series.

```yaml
processors:
  attributes/drop-high-card:
    actions:
      - key: user.id
        action: delete
      - key: request.id
        action: delete
      - key: order.id
        action: delete
      - key: http.target  # el full URL con query string
        action: delete
  transform/clean-labels:
    metric_statements:
      - context: datapoint
        statements:
          - delete_key(attributes, "k8s.pod.uid")
          - delete_key(attributes, "k8s.pod.name")  # mantener namespace/service, no pod
```

Regla operativa: **los atributos de métrica pertenecen al conjunto cerrado y pequeño que define semconv** (`http.response.status_code`, `http.request.method`, etc.). Cualquier atributo con cardinalidad > N (p. ej. 100) por métrica se dropea en el Collector.

### 3.3 Aggregation processors

Para métricas ya pre-agregadas, se puede alargar el intervalo o convertir cumulativo a delta antes del vendor (si cobra por datapoint, delta cuesta menos a largo intervalo):

```yaml
processors:
  cumulativetodelta: {}
  interval:                     # agrega datapoints en ventanas
    interval: 60s
    pass_through:
      metrics: ["^http\\.server\\.request\\.duration$"]
```

Combinado con un filtro OTTL que descarte histogramas vacíos, el ahorro puede ser 30-50% sin pérdida informacional.

## 4. Cross-signal correlation garantizada

La correlación cross-signal (de métrica a trace a log) **no la da el backend**: la da el **Resource compartido** y la propagación. Si tus tres pipelines tienen el mismo `service.name`, el mismo `deployment.environment` y, para traces y logs, el mismo `trace_id`, cualquier backend medianamente decente las unirá.

Las piezas concretas:

- **Exemplars**: la métrica (sobre todo histogramas) lleva un `trace_id` como ejemplo del datapoint. Grafana lo muestra como punto clicable que te lleva al trace. Requiere SDK con exemplars habilitados y temporalidad adecuada.
- **Logs con `trace_id`**: el logging bridge de OTel (en Python el handler que inyecta en cada record) añade `trace_id`/`span_id` cuando hay span activo. Si lo olvidas, pierdes el click-through log → trace.
- **Resource compartido**: `k8sattributes` processor en el Collector hace la mayoría del trabajo (`k8s.pod.name`, `k8s.namespace.name`), pero los teams tienen que configurar bien `service.name` y `deployment.environment`.

Un dashboard "correlación OK" se puede escribir como alerta: "fracción de métricas con exemplars no nulos", "fracción de logs con trace_id poblado". Son SLIs de la propia plataforma.

## 5. Semconv governance — mantener convenciones vivas sin romper nada

Las Semantic Conventions evolucionan. El caso canónico es `http.method` → `http.request.method` (migración HTTP semconv v1). Si los dashboards usan `http.method` y mañana el SDK empieza a emitir `http.request.method`, se rompen silenciosamente.

El patrón de governance que funciona:

1. **Seguir upstream con cadencia**: elegir una versión de SemConv por trimestre; registrarla en el repo de plataforma como "pinned version".
2. **Extensión interna bajo namespace propio**: `company.tenant.id`, `company.region`, nunca sobre-escribir keys upstream.
3. **Manejo de deprecations con dual-emit transitorio**: cuando upstream deprecia una key, el Collector hace *dual-emit* vía OTTL (copia el valor viejo al nuevo o viceversa) durante N semanas; se anuncia el cutover; se retira la copia.

Ejemplo OTTL para HTTP:

```yaml
processors:
  transform/dual-emit-http-method:
    error_mode: ignore
    trace_statements:
      - context: span
        statements:
          # Si llega la nueva, derivar la vieja para dashboards legacy.
          - set(attributes["http.method"], attributes["http.request.method"]) where attributes["http.method"] == nil
          # Si llega la vieja, derivar la nueva para dashboards nuevos.
          - set(attributes["http.request.method"], attributes["http.method"]) where attributes["http.request.method"] == nil
```

El cutover se anuncia (comms, PRs a dashboards) y después de la fecha el bloque OTTL se simplifica a sólo la dirección "vieja → se dropea".

## 6. IDP integration — Backstage y golden paths

Si la observabilidad depende de que cada equipo haga lo correcto manualmente, la plataforma pierde. La solución es **golden paths**: templates de Backstage (u otro IDP) que, al crear un servicio nuevo, scaffoldean:

- `Instrumentation` CR (OTel Operator) con el SDK para el lenguaje.
- Annotation `instrumentation.opentelemetry.io/inject-python=true` (o el idioma correspondiente) en el Deployment.
- `ServiceMonitor` / `PodMonitor` si aplica.
- Un dashboard base (RED) y 3-5 alertas base, en el repo del servicio.

El resultado: un servicio nuevo nace con los tres signals, exemplars, logs correlacionados y dashboards base. **Cero código** del equipo de producto. Esta es la forma más eficiente de que la neutralidad vendor sea invisible — porque el equipo nunca ve el backend.

## 7. SLOs de la plataforma de observabilidad

La plataforma debe medirse a sí misma. SLIs mínimos:

- **Ingest availability**: fracción de requests OTLP al gateway que retornan 2xx. Target 99.9%.
- **Ingest latency**: p99 del tiempo entre que el SDK emite y el backend muestra. Target < 60s para traces, < 30s para métricas, < 90s para logs.
- **Drop rate**: fracción de spans/metrics/logs rechazados (por `memory_limiter`, por `sending_queue` full, por validación). Target < 0.1%.
- **Exemplar coverage**: fracción de datapoints de histograma con exemplar no nulo. Target > 80% (una señal operacional de que la correlación funciona).

Estos SLIs viven en el mismo Prometheus que todo lo demás, pero scrapeados de la *meta-telemetría* del Collector (expone sus propias métricas en `/metrics`).

## 8. ADR vendor neutrality — el caso del cambio real

El examen de la neutralidad es: ¿puedes cambiar de backend sin tocar código? El caso canónico que probarás en `activities/02`:

- **Antes**: Collector exporta traces a Tempo, métricas a Prometheus (remote write), logs a Loki. Self-hosted.
- **Después**: todo a Datadog (vía exporter `datadog`).

El `git diff` del cambio **sólo debe tocar** `collector/*.yaml` (y, si aplica, los Secrets con credenciales del vendor). Si tocas `src/`, hay una grieta: identifícala, documéntala, córtala.

El ADR acompaña: contexto comercial, decisión técnica (p. ej. "mover solo traces inicialmente", "mantener Prometheus + Datadog por un trimestre"), consecuencias (costo mensual, lock-in de dashboards vendor), plan de rollback.

## 9. Defensa ante presión comercial

Un vendor te ofrece 40% de descuento si usas sus features propietarios (ej. "APM Live Trail", "Watchdog"). La tentación es grande. Argumentos para defender la neutralidad:

- **Costo total**: el descuento compensa 2 años; el lock-in dura 7+.
- **Riesgo de concentración**: un incidente del vendor te deja sin observabilidad justo cuando más la necesitas.
- **Compliance / sovereignty**: si mañana regulación obliga a soberanía de datos, mover un self-hosted es más barato que renegociar con el vendor.
- **Negociación**: la neutralidad real es tu palanca comercial. El día que firmes lock-in, pierdes el "si suben precios, migro en 2 semanas".

La respuesta correcta rara vez es "sí al descuento". Suele ser "sí a usar el vendor como backend, no a usar sus APIs propietarias".

## 10. Antipatrones de plataforma

- **Dashboards en la UI del vendor como fuente de verdad**: no versionados, no portables, se pierden en el próximo cambio de billing.
- **Permitir que cada equipo elija su backend**: fragmenta la correlación, multiplica costos, imposibilita SLOs cross-service.
- **Pin de SemConv flotante** (`latest`): cada deploy puede romper un dashboard. Pin a versión semántica, actualizar con cadencia anunciada.
- **Attributes "temporales" que se vuelven permanentes**: `debug_user_id` en producción durante 2 años.
- **Olvidar la meta-telemetría del Collector**: el pipeline cae, y nadie se entera porque no está instrumentado... a sí mismo.

## 11. Checklist operativo de la plataforma (resumen)

- [ ] Contrato de telemetría publicado y versionado.
- [ ] Collector como única frontera; prohibido exporter directo del SDK.
- [ ] Tail sampling con quotas por `service.name` + políticas "always keep errors".
- [ ] Drop de atributos de alta cardinalidad antes del vendor.
- [ ] Resource `service.name`, `service.namespace`, `service.version`, `deployment.environment` presentes en los 3 signals.
- [ ] Exemplars habilitados en histogramas.
- [ ] Logs con `trace_id`/`span_id` cuando hay span activo.
- [ ] Semconv pinned a versión concreta; proceso de upgrade con dual-emit.
- [ ] Golden path IDP scaffoldea Instrumentation CR al crear servicio nuevo.
- [ ] SLOs de la plataforma definidos, instrumentados, alertados.
- [ ] ADR de neutralidad vendor firmado por el órgano de arquitectura.
- [ ] Al menos un drill de cambio de backend ejecutado (puede ser hacia un backend "de staging" multi-export).

## 12. Transición al capstone

En el capstone (final del curso) deberás presentar: ADR + Collector config que demuestra el switch de backend sin tocar `src/`. Esta lección y sus actividades son el entrenamiento previo. Si al terminarlas sientes que puedes defender el contrato en una reunión con un vendor, estás listo.
