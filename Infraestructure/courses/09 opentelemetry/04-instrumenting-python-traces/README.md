# otel-04 — Instrumenting Python Traces

## Identificación
- **ID:** `otel-04-instrumenting-python-traces`
- **Nivel:** intermedio
- **Duración estimada:** 4 h
- **Prerrequisitos:** `otel-03-api-sdk-and-instrumentation-strategies`

## Objetivo
Instrumentar una aplicación Python/FastAPI combinando **auto-instrumentation** (vía `opentelemetry-instrument` + librerías community) y **spans manuales** que capturen operaciones de dominio con atributos, eventos, status y excepciones; dejando la aplicación lista para exportar OTLP a un Collector o imprimir a consola cuando no hay backend.

## Temas y subtemas
- Paquetes: `opentelemetry-api`, `opentelemetry-sdk`, `opentelemetry-exporter-otlp`, `opentelemetry-instrumentation-{fastapi,httpx,requests,psycopg,redis,...}`.
- Setup del **TracerProvider**, **Resource** (`service.name`, `service.version`, `deployment.environment`) y pipeline `BatchSpanProcessor → OTLPSpanExporter`.
- Fallback con `ConsoleSpanExporter` cuando no hay Collector.
- CLI `opentelemetry-instrument` (zero-code wrapper) y auto-instrumentation por librería.
- Spans manuales con `tracer.start_as_current_span`; attributes (`set_attribute`), events (`add_event`), status (`set_status` + `StatusCode.ERROR/OK`), excepciones (`record_exception`).
- **Span kinds**: `SERVER`, `CLIENT`, `PRODUCER`, `CONSUMER`, `INTERNAL`.
- Nested spans y parent/child automático vía Context.
- Semántica de nombres: nombrar por **operación de negocio** (`checkout.process`), no por método HTTP (`POST /pay`).
- Costos: cardinalidad de atributos, strings largos, N spans por request.

## Conceptos internos (fundamentos)
- Cada `start_as_current_span` *empuja* el nuevo span al Context "current" del thread/async task; sin él, el span creado es huérfano en la jerarquía.
- El `BatchSpanProcessor` acumula spans en memoria y los flush-ea cada `schedule_delay_millis` o cuando alcanza `max_export_batch_size`; es la razón por la que al cerrar el proceso brutalmente *se pierden* spans — hay que llamar `provider.shutdown()`.
- La `Resource` se adjunta una sola vez al provider y viaja con *cada* span: cambia `service.name` y rediseñas tu backend.
- `record_exception` crea un **evento** `exception` con atributos semconv (`exception.type`, `exception.message`, `exception.stacktrace`); no cambia el status automáticamente — eso es `set_status(StatusCode.ERROR)` aparte.
- Context propagation entre spans del mismo proceso es automática gracias a `contextvars`; cross-service requiere `propagators` (cubierto en `otel-07`).

## Competencias
- **Conceptual:** justificar cuándo auto-instrumentation basta y cuándo hay que añadir spans manuales de dominio.
- **Operativa:** configurar provider + exporter OTLP; crear spans con atributos, eventos y status correctos; usar `opentelemetry-instrument` para FastAPI.
- **Arquitectónica:** definir el "contrato de spans" del servicio (nombres por operación, kinds, atributos semconv) sin inflar costos.

## Ejemplos
- [`examples/01-fastapi-auto-instrument`](examples/01-fastapi-auto-instrument/) — zero-code wrapper con `opentelemetry-instrument` + exporter consola.
- [`examples/02-manual-business-spans`](examples/02-manual-business-spans/) — spans anidados por operación de dominio con atributos y eventos.
- [`examples/03-record-exception-and-status`](examples/03-record-exception-and-status/) — captura de excepciones y transición de status.

## Actividades
- [`activities/01-instrument-capstone-traces`](activities/01-instrument-capstone-traces/) — guided-lab: wiring de provider + BatchSpanProcessor + spans manuales en una app del capstone.
- [`activities/02-add-domain-spans`](activities/02-add-domain-spans/) — independent: añadir `checkout.process`, `payment.charge`, `inventory.reserve` a una app con solo spans HTTP.

## Entregables
- App Python/FastAPI con `TracerProvider` + `BatchSpanProcessor` + exporter OTLP (o consola) configurados.
- Cobertura RED básica vía auto-instrumentation + **3 o más spans manuales** por operación de negocio con atributos y status.
- Nota breve de decisiones: qué se auto-instrumentó, qué se añadió manual y por qué.

## Criterios de evaluación
- **Conceptual:** explicar la diferencia entre API y SDK en el código escrito; justificar span kinds.
- **Operativa:** spans aparecen en consola/Collector con nombres de dominio, atributos y status correcto en errores.
- **Arquitectónica:** criticar un conjunto de spans "ruidosos" (duplicados, atributos de alta cardinalidad, nombres HTTP-céntricos) y proponer rediseño.

## Recursos
Ver [`resources/links.md`](resources/links.md).
