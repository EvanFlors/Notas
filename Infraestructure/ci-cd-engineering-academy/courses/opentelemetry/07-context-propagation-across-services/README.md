# otel-07 — Context propagation across services

## Identificación
- **ID:** `otel-07-context-propagation-across-services`
- **Nivel:** intermedio
- **Duración estimada:** 3 h
- **Prerrequisitos:** `otel-02-specification-semconv-and-context-propagation`, `otel-04-instrumenting-python-traces`

## Objetivo
Mantener el **trace vivo** a través de procesos, lenguajes, protocolos y colas: diagnosticar y arreglar traces "cortos" o rotos cuando el context no atraviesa un hop (HTTP, gRPC, mensajería, batch, async).

## Temas y subtemas
- **W3C Trace Context** como contrato cross-stack: `traceparent`, `tracestate`, `baggage`.
- **HTTP**: propagación automática por client/server instrumentations (p. ej. `httpx`, `requests`, `fastapi`, `flask`).
- **gRPC**: metadata como carrier (equivalente a headers).
- **Mensajería**: Kafka headers; SQS/SNS message attributes; RabbitMQ headers.
- **Manual propagation** con `inject` / `extract` cuando el framework no está instrumentado o es custom.
- **Procesos batch / desacoplados**: propagación "fuera de banda" (columna en DB, metadata en filename S3, variable de entorno).
- **Async y thread-local context** en Python: `ContextVars`, `contextvars.copy_context()`, por qué el context sobrevive en `asyncio` pero se pierde con `ThreadPoolExecutor` sin cuidado.
- Helpers oficiales: `opentelemetry.context.attach / detach`, `trace.use_span`, `context.copy()`.
- Errores comunes: carrier perdido en middleware, propagator global no configurado, span iniciado antes de `extract`, logs sin traceId porque el handler corre fuera del context.

## Conceptos internos (fundamentos)
- Un **context** vive dentro de un proceso como una pila implícita (`contextvars.ContextVar`). No viaja solo entre procesos.
- Para cruzar un hop, el SDK **serializa** el context en un *carrier* (dict de headers) con `propagator.inject(carrier)` y el receptor lo **reconstruye** con `propagator.extract(carrier)`.
- Si el receptor no llama a `extract` (o no tiene propagator configurado), inicia un trace nuevo: síntoma clásico de "traces cortos" en Grafana/Tempo (un servicio por trace).
- El propagator por default compuesto es `tracecontext + baggage`. Para legacy B3/Jaeger hay que configurar `OTEL_PROPAGATORS=b3,baggage` o `jaeger,baggage`.
- `ContextVars` es per-task en `asyncio`: `await` conserva el context. `ThreadPoolExecutor.submit` **no** copia el context del hilo llamador salvo que uses `contextvars.copy_context().run(...)` o el helper `opentelemetry.context.attach(ctx)` dentro del worker.

## Competencias
- **Conceptual:** explicar la diferencia entre context in-process y wire-level; leer un `traceparent` y relacionarlo con un span.
- **Operativa:** instrumentar propagación manual sobre un transporte custom; diagnosticar y arreglar un trace que se corta en el hop N.
- **Arquitectónica:** diseñar la propagación extremo-a-extremo de una request (HTTP → cola → batch job → DB) manteniendo la correlación.

## Ejemplos
- [`examples/01-fastapi-client-and-server-trace`](examples/01-fastapi-client-and-server-trace/) — dos procesos FastAPI, trace continuo con auto-instrumentation `httpx` + `fastapi`.
- [`examples/02-propagate-via-kafka-headers`](examples/02-propagate-via-kafka-headers/) — producer/consumer simulados: `inject` en headers Kafka, `extract` en el consumer (sin broker real).
- [`examples/03-executor-context-copy`](examples/03-executor-context-copy/) — el gotcha de `ThreadPoolExecutor`: contrasta la versión rota con la versión que copia el context.

## Actividades
- [`activities/01-two-services-end-to-end-trace`](activities/01-two-services-end-to-end-trace/) — guided-lab: dos servicios Python, trace continuo validado automáticamente.
- [`activities/02-fix-broken-propagation`](activities/02-fix-broken-propagation/) — independent/debug: el starter tiene propagación rota; el estudiante diagnostica (propagator no configurado, carrier no inyectado, etc.) y arregla.

## Entregables
- Dos servicios Python emitiendo spans que comparten `trace_id` cuando uno llama al otro.
- Diagnóstico escrito del fallo del Activity 02 y su fix.

## Criterios de evaluación
- **Conceptual:** explicar qué pasa cuando el servicio B inicia un trace nuevo (no se encuentra traceparent → sampler decide → nuevo root span).
- **Operativa:** fix verificable con `tests/validate.sh`.
- **Arquitectónica:** proponer propagación para un pipeline HTTP → Kafka → batch job con justificación del carrier en cada hop.

## Recursos
Ver [`resources/links.md`](resources/links.md).
