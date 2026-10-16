# otel-10 — Sampling: head, tail, probabilistic y parent-based

## Identificación
- **ID:** `otel-10-sampling-head-tail-probabilistic-parent-based`
- **Nivel:** avanzado
- **Duración estimada:** 4 h
- **Prerrequisitos:** `otel-08` (context propagation en profundidad), `otel-09` (patrones de despliegue agent vs gateway recomendado).

## Objetivo
Diseñar una estrategia de **sampling** para un pipeline OTel que **balancee costo (volumen almacenado) y señal (visibilidad de errores y colas de latencia)**. Al terminar el estudiante puede justificar por qué una muestra de 10% uniforme oculta incidentes y cómo una política *error-first + latency + probabilistic* en el Collector resuelve esa limitación — a cambio de memoria y complejidad operativa.

## Temas y subtemas

1. **Por qué samplear**: economía del tracing, cardinalidad y storage amplification.
2. **Head-based sampling (SDK)**
   - `AlwaysOn`, `AlwaysOff`, `TraceIdRatioBased(p)`.
   - `ParentBased(root=..., remote_parent_sampled=..., ...)` como wrapper de consistencia.
   - Dónde se toma la decisión (root span) y cómo se propaga vía `traceparent` (flag `sampled`).
   - Limitación central: **ciego al resultado**; si descartas, no hay forma de rescatar un error.
3. **Tail-based sampling (Collector)**
   - `tail_sampling` processor: cómo funciona (buffer por `trace_id` + `decision_wait`).
   - Policies: `status_code`, `latency`, `string_attribute`, `numeric_attribute`, `probabilistic`, `rate_limiting`, `and`, `composite`.
   - **Error-first** pattern: 100% errores + N% éxitos.
4. **Consistent sampling y `tracestate`**
   - Problema: si cada servicio decide con su propio ratio, las decisiones divergen → traces huérfanos.
   - Solución: W3C `tracestate` + `TraceIdRatioBased` determinístico sobre `trace_id`.
   - `ConsistentProbabilitySampler` (OTEP 235) y p-value / r-value.
5. **Costo de tail-based**
   - Memoria: `num_traces × spans_promedio × bytes_por_span` durante `decision_wait`.
   - Latencia de visualización: nada aparece antes de `decision_wait`.
   - Requisito arquitectural: **todos los spans de un trace deben llegar al mismo Collector** → `loadbalancing` exporter upstream.

## Conceptos internos (fundamentos)

- **Decisión binaria por trace** (no por span): un trace se mantiene entero o se descarta entero; mezclar lleva a traces incompletos.
- **Determinismo sobre `trace_id`**: `TraceIdRatioBased` extrae los 64 bits superiores del `trace_id` y los compara con un umbral — misma entrada, misma decisión en cualquier servicio.
- **Why `ParentBased` wrapper**: si el root ya decidió `sampled=1`, los hijos deben honrarlo; si no, el servicio nuevo (sin padre remoto) aplica su root sampler. Sin esto, un servicio downstream con ratio distinto corta la trace.
- **Buffer stateful del tail-based**: viola la idea "procesadores sin estado"; de ahí la memoria, el `decision_wait` y la restricción de topología.

## Competencias

- **Conceptual**: distinguir head vs tail; explicar por qué uniform random sampling pierde incidentes raros; definir "consistent sampling".
- **Operativa**: configurar `ParentBased(TraceIdRatioBased(0.1))` en Python; escribir policies `tail_sampling` para errores + latencia + muestra probabilística; medir el ahorro.
- **Arquitectónica**: decidir dónde cae el sampling (edge agent, gateway, hybrid), estimar memoria del Collector, justificar o rechazar tail-based en función del volumen y del SLO.

## Ejemplos

- [`examples/01-head-based-parent-ratio/`](examples/01-head-based-parent-ratio/) — SDK Python con `ParentBased(TraceIdRatioBased(0.1))`; se observan trace-ids descartados vs retenidos.
- [`examples/02-tail-sampling-errors-plus-latency/`](examples/02-tail-sampling-errors-plus-latency/) — Collector con `tail_sampling` + policies `status_code` (errores 100%), `latency` (>500 ms) y `probabilistic` (10% del resto).
- [`examples/03-consistent-sampling/`](examples/03-consistent-sampling/) — Dos servicios encadenados: comparación entre `AlwaysOn` + `ParentBased` consistente vs ratios divergentes (traces huérfanos).

## Actividades

- [`activities/01-tune-sampling-for-capstone/`](activities/01-tune-sampling-for-capstone/) — Guided lab: afinar el sampling del capstone para 100% errores + 10% éxitos.
- [`activities/02-cost-estimate-head-vs-tail/`](activities/02-cost-estimate-head-vs-tail/) — Independent: cálculo escrito del costo en GB/mes y memoria para 1000 req/s bajo tres estrategias.

## Entregables

- Collector gateway corriendo con `tail_sampling` configurado (errores + latencia + probabilistic).
- SDK Python de un servicio con `ParentBased(TraceIdRatioBased(0.1))`.
- Reporte de estimación de costo (markdown o PDF) de la actividad 02 con los tres escenarios y una recomendación.

## Criterios de evaluación

- **Conceptual**: explica por qué tail-based necesita buffer y por qué debe pegarse al mismo Collector; distingue `ParentBased` de `TraceIdRatioBased`.
- **Operativa**: la configuración del Collector exporta sólo los traces esperados (100% errores + ~10% éxitos muestreados) y lo demuestra con una corrida.
- **Arquitectónica**: la recomendación de la actividad 02 cita memoria, storage y blind spots; no se queda sólo en "tail-based es mejor".

## Recursos

Ver [`resources/links.md`](resources/links.md).
