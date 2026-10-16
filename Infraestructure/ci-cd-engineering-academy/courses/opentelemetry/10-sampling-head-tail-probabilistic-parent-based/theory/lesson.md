# Lesson — Sampling en OpenTelemetry: head, tail, probabilistic y parent-based

> **Prereq**: `otel-08` (context propagation). **Nivel**: avanzado. **Duración**: ~2 h de lectura + ejercicios de los ejemplos.

## 1. Por qué samplear: la economía del tracing

El tracing distribuido tiene un problema estructural de **crecimiento no lineal**: cada request produce un *trace* con N spans (uno por servicio/operación atravesada). En un sistema de 10 microservicios con 5 operaciones promedio por request, 1000 req/s producen **50 000 spans/s**. Un span serializado en OTLP pesa ~500 B–2 KB con atributos útiles. Haz la cuenta: ~1 TB/día *antes* de compresión.

La reacción natural es "guardar todo y comprimir mucho". Pero el costo del tracing no está sólo en el disco: está en la **ingesta** del backend (Tempo/Jaeger/Datadog cobran por GB ingested, o colapsan si no están dimensionados), en el **índice** (para búsquedas por trace_id, service, operation), y en la **memoria** del Collector cuando hace tail-sampling. **Sampling** es la decisión explícita de descartar la mayoría de los traces y guardar un subconjunto *representativo* y *útil*. El arte está en que la muestra:

1. **Represente la distribución** (p95, p99 de latencia visibles).
2. **No pierda incidentes** (los errores raros son los que te interesan más).
3. **Sea consistente** (todos los servicios acuerdan guardar o descartar el *mismo* trace).

## 2. Dos lugares para decidir: head vs tail

Dos lugares posibles para tomar la decisión:

- **Head-based (SDK)**: el servicio *que crea el root span* decide, en el instante en que el request llega, si samplea o no. La decisión viaja en el flag `sampled` del `traceparent` W3C y los servicios downstream la honran.
- **Tail-based (Collector)**: nadie decide hasta que el *trace completo* ha llegado al Collector. Entonces, con todos los spans a la vista, se aplica una política basada en el **resultado** (hubo error, latencia alta, atributo específico).

**Trade-off fundamental**:

| Dimensión | Head-based | Tail-based |
|---|---|---|
| Decisión | Al iniciar el request | Tras ver el trace completo |
| Información disponible | Nada (es ciego al resultado) | Todo (status, latencia, atributos) |
| Estado | Stateless | Stateful (buffer por trace_id) |
| Costo | ~0 | Memoria + CPU en Collector |
| Topología | Libre | Todos los spans del trace al mismo Collector |
| Blind spots | **Errores raros descartados** | Sólo si el buffer se desborda |

**Regla**: en producción seria, head-based uniforme (p. ej. 10%) es **inaceptable** para errores. Pierdes el 90% de los incidentes. O haces tail-based, o combinas head-based *generoso* (p. ej. 50%) con un downsampler probabilístico más agresivo tail-based que preserva errores.

## 3. Head-based en el SDK: samplers canónicos

El SDK de OTel define `Sampler` como una interfaz con un método `should_sample(parent_context, trace_id, name, kind, attributes, links) -> SamplingResult`. Los samplers built-in:

- `AlwaysOnSampler` — todo pasa (`RECORD_AND_SAMPLE`). Útil en dev.
- `AlwaysOffSampler` — nada pasa (`DROP`). Útil para desactivar un servicio sin tocar código.
- `TraceIdRatioBased(ratio)` — determinístico sobre `trace_id`: compara los 64 bits superiores contra `ratio * 2^64`. **Determinístico y consistente**: dos servicios con el mismo `ratio` *y mismo `trace_id`* deciden lo mismo.
- `ParentBased(root_sampler, remote_parent_sampled=..., remote_parent_not_sampled=..., local_parent_sampled=..., local_parent_not_sampled=...)` — wrapper. Si hay padre (remoto o local), honra su decisión; si no (es el root), delega en `root_sampler`.

El idiomático en producción:

```python
from opentelemetry.sdk.trace.sampling import ParentBased, TraceIdRatioBased

sampler = ParentBased(root=TraceIdRatioBased(0.1))
```

Lectura: "si llega un request con `traceparent` que ya decidió, respétalo; si yo soy el root, muestreo 10% determinístico por `trace_id`". Sin `ParentBased`, un servicio downstream con otro ratio rompería la trace a mitad de camino.

## 4. La limitación central del head-based

**No sabes qué pasa después**. Si descartas en el root y hay un error cinco servicios más abajo, perdiste el trace. Como los errores suelen ser **raros** (0.1% de los requests), un sampling uniforme al 10% guarda sólo 0.01% de los errores — estadísticamente irrelevante para diagnóstico.

Workarounds parciales con head-based:

- **Rate limiting por operación**: muestrear 100% del tráfico de `POST /checkout` y 1% de `GET /health`. Requiere lógica custom en el `Sampler`.
- **Error promotion**: imposible en head puro — el error aún no ocurrió al decidir.
- **Sampling adaptativo**: ajustar `ratio` según carga. Reduce costo, no resuelve el blind spot de errores raros.

La única solución estructural a "quiero 100% de los errores" es **tail-based**.

## 5. Tail-based en el Collector: cómo funciona

El `tail_sampling` processor del `otelcol-contrib` buffer-ea todos los spans de cada `trace_id` por un tiempo configurable (`decision_wait`, típicamente 10–30 s). Al vencer el timer, aplica las policies configuradas al **conjunto completo de spans** del trace y decide `SAMPLED` o `NOT_SAMPLED`. Si pasa, los spans se emiten al siguiente exporter; si no, se descartan.

```yaml
processors:
  tail_sampling:
    decision_wait: 10s
    num_traces: 50000           # buffer máximo (traces concurrentes)
    expected_new_traces_per_sec: 1000
    policies:
      - name: errors
        type: status_code
        status_code: { status_codes: [ERROR] }
      - name: slow
        type: latency
        latency: { threshold_ms: 500 }
      - name: random-10
        type: probabilistic
        probabilistic: { sampling_percentage: 10 }
```

Semánticamente las policies son **OR**: si *cualquiera* dice SAMPLED, el trace se mantiene. Para AND existe la policy `and`; para combinaciones más ricas, `composite`.

## 6. Policies útiles del `tail_sampling`

- `status_code` — por `ERROR`, `OK`, `UNSET`. **Error-first** se construye con esta policy sola, con `status_codes: [ERROR]`.
- `latency` — spans cuya duración (del root o cualquiera, según config) excede `threshold_ms`. Perfecto para colas p95/p99.
- `string_attribute` — matchea atributos por valor (p. ej. `http.route == /checkout`).
- `numeric_attribute` — rango numérico.
- `probabilistic` — baseline aleatorio determinístico (sobre `trace_id`).
- `rate_limiting` — máximo N spans/s.
- `and` — todas sus sub-policies deben decir SAMPLED.
- `composite` — pondera varias policies con pesos (rate budget).

**Pattern recomendado para capstone**:

```
status_code=ERROR        → 100%
latency > 500ms          → 100%
string_attribute (debug) → 100%
probabilistic 10%        → baseline representativo
rate_limiting 1000/s     → protección contra tormentas
```

## 7. Consistent sampling y `tracestate`

Problema real: supón que el servicio A decide SAMPLED, propaga `traceparent` con flag `1`. El servicio B lo honra (bien, gracias a `ParentBased`). Pero si en algún punto un servicio **no honra** el flag — o lo arranca sin padre porque es un worker async desencadenado por una cola — tomará su propia decisión, que puede divergir. Resultado: traces incompletos sistemáticos.

**W3C `tracestate`** es un campo adicional en el context propagation donde los vendors y specs pueden guardar metadata vendor-specific. OTel usa `tracestate` para transportar el **p-value** y **r-value** de *consistent probability sampling* (OTEP 235): un marcador que dice "este trace fue muestreado al ratio p; cualquiera que vuelva a decidir debe honrar p o samplear más agresivo, nunca menos".

Idea: la decisión binaria no se recalcula; se refina. Un servicio que recibe `tracestate: ot=p:3` (muestreado al 1/8) y quisiera muestrear al 1/4 (más agresivo) puede descartar; al revés (quiere mantener más), ya es tarde — el servicio anterior ya descartó. Por eso **se decide al menos ratio en el edge y, si acaso, se baja (más estricto) downstream**, nunca al revés.

`ConsistentProbabilitySampler` está disponible en los contrib SDKs. Para el curso basta con `ParentBased(TraceIdRatioBased(p))` + usar el *mismo* `p` en todos los servicios edge: ya es consistente, porque la función es determinística sobre `trace_id`.

## 8. Error-first pattern: 100% de errores + N% de éxitos

El pattern más usado en producción. Garantiza:

- **100% visibilidad de errores**: cualquier trace con un span `ERROR` sobrevive.
- **Baseline estadístico**: N% (típicamente 10%) de los éxitos sobrevive, dando distribución de latencia y topología.
- **Overhead manejable**: si errores son 1% del tráfico, retienes 10.9% total — ahorro del 89% vs AlwaysOn.

Es **imposible de implementar en head-based puro**. Variantes:

- "100% errores + 100% slow + 10% éxitos" — el que usamos en el ejemplo 02.
- "100% errores + budget de 100 traces/s" (rate_limiting) — control duro de volumen.
- "100% errores + 100% de rutas críticas (`/checkout`, `/pay`) + 5% del resto".

## 9. El costo del tail-based: memoria y topología

**Memoria**: el Collector mantiene en RAM todos los spans de todos los traces vivos (los que están dentro de `decision_wait`). Fórmula aproximada:

```
mem = traces_concurrentes × spans_por_trace × bytes_por_span × overhead
    ≈ (req_s × decision_wait) × avg_spans × 1500 B × 1.5
```

Para 1000 req/s, `decision_wait=10s`, 10 spans/trace: `10 000 × 10 × 1500 × 1.5 ≈ 225 MB`. No es trivial.

**Latencia**: nada aparece en el backend hasta `decision_wait` segundos después del root span. UI de Jaeger/Tempo lo muestra con delay.

**Topología crítica**: **todos los spans de un trace deben llegar al mismo Collector**. Si usas una flota de Collectors detrás de un load balancer round-robin, los spans de un trace se dispersan → el buffer de ningún Collector ve el trace completo → se descartan spans huérfanos o se decide con información parcial. Solución: `loadbalancing` exporter upstream, que ruta por `trace_id` (consistent hashing). Esto define la **arquitectura de dos capas**: agents (edge) → gateway (tail-sampling, replicada con loadbalancing exporter en frente).

## 10. Dónde cae el sampling: agent, gateway, híbrido

Combinaciones típicas:

| Topología | Head en SDK | Head en Agent | Tail en Gateway | Caso |
|---|---|---|---|---|
| Dev | AlwaysOn | — | — | Todo visible |
| Simple | 10% ratio | — | — | Barato, pierde errores |
| Pro | AlwaysOn | — | errors+latency+10% | Costo controlado, errores completos |
| Alto volumen | 50% ratio | — | errors+latency+5% | Dos niveles |
| Multi-tenant | AlwaysOn | tenant tagging | tenant-aware policies | Billing por tenant |

**Regla pragmática**: para capstone y la mayoría de empresas < 10k req/s, "AlwaysOn en SDK + tail-sampling (errors + latency + 10%) en gateway" es la referencia.

## 11. Blind spots y anti-patterns

- **Uniform ratio < 10% en head**: destruye observabilidad de errores raros.
- **Tail sin `loadbalancing` upstream**: traces fragmentados silenciosamente.
- **`decision_wait` muy bajo (< 5s)**: traces largos (batch, async) deciden sin ver spans tardíos → se descartan como "exitosos" aunque fallaron después.
- **`decision_wait` muy alto (> 60s)**: memoria explota.
- **Policies sin probabilistic baseline**: pierdes la referencia estadística; sólo ves outliers.
- **Policies demasiado específicas**: terminas sampling el 100% y perdiendo el ahorro.
- **Mezclar ratios distintos sin `ParentBased`**: traces huérfanos sistemáticos.
- **Tail-sampling sin `batch` processor downstream**: emites spans en burst al vencer el `decision_wait`, saturando el exporter.

## 12. Checklist operativo

- [ ] En el SDK: `ParentBased(TraceIdRatioBased(0.1))` o `AlwaysOn` si el gateway hace tail.
- [ ] Todos los servicios edge usan el **mismo** ratio (consistencia).
- [ ] Gateway Collector corriendo `otelcol-contrib` (el contrib incluye `tail_sampling`).
- [ ] `decision_wait` entre 10–30 s; `num_traces` dimensionado para pico de carga.
- [ ] Policies ordenadas: errores → latency → atributos → probabilistic → rate_limiting.
- [ ] `batch` processor **después** de `tail_sampling`.
- [ ] `loadbalancing` exporter si hay varias instancias de gateway.
- [ ] Dashboards del Collector monitoreando `otelcol_processor_tail_sampling_count_traces_sampled` y memoria.
- [ ] Alertas sobre tasa de descartes por saturación de buffer.
- [ ] Documentación: cuántos errores por minuto se esperan y cómo se traducen a GB/día en el backend.
