# otel-03-api-sdk-and-instrumentation-strategies — API, SDK e instrumentación

## Identificación
- **ID:** `otel-03-api-sdk-and-instrumentation-strategies`
- **Nivel:** fundamentos
- **Duración estimada:** 2 h
- **Prerrequisitos:** `otel-01-what-and-why-signals-and-maturity`

## Objetivo
Distinguir con criterio **API**, **SDK** e **instrumentación** (manual, instrumentation libraries, auto, zero-code/eBPF) para elegir la estrategia correcta por servicio. Al terminar, el estudiante sabe qué código escribir, qué dependencia instalar y qué proceso ejecutar para obtener telemetría con el mínimo esfuerzo útil.

## Temas y subtemas
1. **API OTel** — qué importa tu código (`opentelemetry.trace.get_tracer()`, `opentelemetry.metrics.get_meter()`). Es *solo* una interfaz: sin SDK registrado, es no-op.
2. **SDK OTel** — implementación de referencia. Se configura una sola vez en `main()`: `TracerProvider`, span processors (`BatchSpanProcessor`), exporters (OTLP, console).
3. **Instrumentation libraries** — paquetes community que envuelven frameworks/drivers conocidos: `opentelemetry-instrumentation-fastapi`, `opentelemetry-instrumentation-requests`, `opentelemetry-instrumentation-psycopg2`, etc. Cada paquete sabe dónde abrir y cerrar spans del framework correspondiente.
4. **Auto-instrumentation** — el CLI `opentelemetry-instrument` detecta los paquetes instalados, importa los instrumentors que correspondan y ejecuta tu app con todo cableado, sin tocar código.
5. **Zero-code eBPF** — Pixie, Beyla y otras soluciones que leen tráfico de red/syscalls en el kernel. No requieren ni paquetes ni variables de entorno dentro del proceso.
6. **Matriz de decisión** — cuándo basta con auto, cuándo exige manual, cuándo zero-code es la única opción (binarios cerrados, lenguajes sin SDK maduro).

## Conceptos internos (fundamentos)
- La separación **API / SDK** existe para que una **biblioteca** pueda importar la API y emitir spans sin forzar un SDK ni un backend a sus consumidores. Si el consumidor no registra SDK, los spans se descartan silenciosamente — comportamiento intencional (*no-op by default*).
- Auto-instrumentation cubre ~80% de la visibilidad gratis (RED por endpoint HTTP, llamadas a DB, HTTP outbound). El 20% restante es **lógica de negocio** (p. ej. "aplicar cupón", "reservar inventario") y requiere **spans manuales** porque ninguna library puede adivinar la frontera semántica correcta.
- `opentelemetry-instrument` funciona porque los `*Instrumentor` leen entry points en el metadata de los paquetes instalados y hacen *monkey-patching* en import time, antes de que tu código ejecute el primer `import fastapi`.
- eBPF ve lo que pasa por la red/syscalls, no el *intent* del código. No sabe qué significa "una venta" ni puede abrir spans en la frontera de una transacción lógica cross-DB.

## Competencias
- **Conceptual:** explicar la diferencia API vs SDK y por qué una library solo depende de la API.
- **Operativa:** instalar los tres paquetes básicos (api, sdk, instrumentation-fastapi), ejecutar con `opentelemetry-instrument` y añadir un span manual a una ruta.
- **Arquitectónica:** justificar manual vs auto vs eBPF para servicios dados (greenfield Python, binario Go legacy, Lambda corto, batch Spark).

## Ejemplos
- [`examples/01-manual-vs-auto/`](examples/01-manual-vs-auto/) — mismo endpoint FastAPI instrumentado de dos formas; se muestra qué spans aparecen en cada caso.
- [`examples/02-instrumentation-libraries-matrix/`](examples/02-instrumentation-libraries-matrix/) — tabla curada de instrumentation libraries Python más usadas con qué cubren.

## Actividades
- [`activities/01-start-with-auto-and-add-manual/`](activities/01-start-with-auto-and-add-manual/) — guided-lab: levantar FastAPI con `opentelemetry-instrument uvicorn ...` y luego añadir spans manuales a dos operaciones de dominio.
- [`activities/02-ebpf-vs-sdk-tradeoffs/`](activities/02-ebpf-vs-sdk-tradeoffs/) — análisis independiente: 4 escenarios, decidir SDK/auto/eBPF con criterio.

## Entregables
- **Matriz de cobertura** `MATRIX.md` con filas = servicios del capstone (API, worker, batch, legacy), columnas = `auto | manual | eBPF | none`, justificación por celda.

## Criterios de evaluación
- **Conceptual:** describir qué pasa si solo importas la API sin registrar SDK.
- **Operativa:** ejecutar `opentelemetry-instrument uvicorn app:app` y mostrar spans por consola.
- **Arquitectónica:** justificar manual vs auto para 3 servicios distintos, incluyendo uno donde eBPF es la mejor respuesta.

## Recursos
Ver [`resources/links.md`](resources/links.md).
