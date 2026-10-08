# Los Tres Pilares de la Observabilidad

![Tres pilares de observabilidad](https://hrcdn.net/ai-engineering/module-7/light/aiops-lesson02-three-pillars-observability.svg)

## ¿Qué es?

La **observabilidad** es la capacidad de entender el estado interno de un sistema a partir de las señales que emite. No es lo mismo que monitoreo: el monitoreo responde a preguntas que **ya sabías que ibas a hacer** (dashboards, alertas); la observabilidad responde a preguntas que **surgen durante un incidente** y que no habías anticipado.

La observabilidad se construye sobre tres pilares que se complementan:

1. **Logs**: eventos discretos con contexto (qué pasó y cuándo).
2. **Métricas**: agregaciones numéricas en el tiempo (cuánto y cuántas veces).
3. **Traces (trazas)**: la ruta completa de un request a través de múltiples servicios (dónde se gastó el tiempo).

Para sistemas de IA, especialmente con LLMs y pipelines RAG, las trazas son el pilar más subestimado y el que marca la diferencia entre poder depurar un fallo y adivinar en la oscuridad.

## ¿Por qué importa?

### Un pilar solo no basta

- Solo **métricas**: ves que la latencia subió, pero no sabes por qué ni para quién.
- Solo **logs**: ves millones de líneas sin forma de agregar ni correlacionar.
- Solo **traces**: ves una ruta lenta, pero no sabes si es sistemática o anómala.

Los tres pilares bien correlacionados permiten pasar de "algo anda mal" a "el 12% de los requests del tenant X están tardando 8s porque el reranker está haciendo cold start cada 30 segundos".

### El caso específico de LLMs

Un pipeline RAG moderno típicamente involucra:

```
usuario -> API gateway -> auth -> cache -> embedder -> vector DB
       -> reranker -> prompt builder -> LLM provider -> guardrails -> respuesta
```

Un fallo puede originarse en cualquiera de estos saltos. Sin tracing distribuido es imposible saber en qué paso se rompió o se degradó la latencia.

## ¿Cómo funciona?

### Pilar 1: Logs estructurados

Los logs de texto plano (`print("error occurred")`) son inservibles a escala. Los **logs estructurados** emiten JSON con campos tipados: `request_id`, `user_id`, `model`, `duration_ms`, `tokens`, etc. Esto permite buscar, filtrar y agregar en herramientas como Loki, Elasticsearch o Datadog.

El campo más importante es el **`request_id`** (también llamado `trace_id` o `correlation_id`): un identificador único por request que se propaga a través de todos los servicios y aparece en cada línea de log relacionada. Sin él, correlacionar eventos entre servicios es imposible.

### Pilar 2: Métricas

Las métricas son **time series** agregadas en ventanas de tiempo. Permiten responder preguntas como "¿cuántos requests por segundo?" o "¿cuál es el p95 de latencia?". Son baratas de almacenar y rápidas de consultar, pero pierden detalle individual.

Tipos principales (según OpenTelemetry):

- **Counter**: solo sube (requests totales, tokens consumidos).
- **Gauge**: sube y baja (uso de memoria, tamaño de cola).
- **Histogram**: distribución de valores (latencias, tamaño de respuestas).

### Pilar 3: Traces distribuidos

Una **trace** es un árbol de **spans**, donde cada span representa una unidad de trabajo (una llamada HTTP, una query a base de datos, una invocación al LLM). Cada span tiene: nombre, timestamp de inicio, duración, atributos (metadatos clave-valor) y una referencia al span padre.

![Trace distribuido](https://hrcdn.net/ai-engineering/module-7/light/aiops-lesson02-distributed-trace.svg)

### OpenTelemetry: el estándar

**OpenTelemetry (OTel)** es el estándar de facto para instrumentación de observabilidad. Define APIs, SDKs y un protocolo (OTLP) que son agnósticos del backend: se puede enviar la misma telemetría a Datadog, New Relic, Grafana Tempo, Honeycomb o Jaeger sin cambiar el código de la aplicación.

Ventajas:

- Un solo SDK para logs, métricas y traces.
- Context propagation automático entre servicios.
- Instrumentaciones automáticas para FastAPI, requests, httpx, SQLAlchemy, etc.
- Portabilidad total entre proveedores.

### Plataformas de observabilidad para LLMs

Las herramientas tradicionales (Datadog, New Relic) no entienden conceptos específicos de LLMs como "token", "prompt template" o "evaluación de respuesta". Han surgido plataformas especializadas:

| Plataforma | Fortalezas | Débil en | Open source | Mejor para |
|---|---|---|---|---|
| **LangSmith** | Integración nativa con LangChain, evals, datasets | Vendor lock-in, caro a escala | No | Equipos que ya usan LangChain |
| **Langfuse** | Open source, self-host, tracing + evals + prompts | UI menos pulida | Sí (MIT) | Startups que quieren control |
| **Helicone** | Proxy drop-in, cero código, caching, rate limiting | Menos features de evals | Sí | Equipos pequeños, rápido setup |
| **Arize Phoenix** | Open source, excelente para RAG, embeddings viz | Setup inicial | Sí | Análisis exploratorio y debugging |
| **W&B Weave** | Integrado con W&B, buenos experiment tracking | Pensado más para research | Parcial | Equipos de ML research |
| **Datadog LLM Obs** | Unificado con APM, infra, logs | Caro, propietario | No | Enterprises ya en Datadog |

### Correlación: el superpoder

Lo que convierte observabilidad en magia es poder saltar de un pilar a otro. Al ver un alerta de latencia alta (métrica), hacer click para ver traces de ese percentil, abrir una trace lenta y ver todos los logs asociados a su `trace_id`. Herramientas modernas como Grafana con el stack "LGTM" (Loki + Grafana + Tempo + Mimir) permiten esta navegación nativamente.

## Ejemplo con código

### Logging estructurado con `request_id` propagado

```python
import logging
import json
import uuid
from contextvars import ContextVar

request_id_ctx: ContextVar[str] = ContextVar("request_id", default="-")

class JSONFormatter(logging.Formatter):
    def format(self, record):
        payload = {
            "timestamp": self.formatTime(record, "%Y-%m-%dT%H:%M:%S%z"),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "request_id": request_id_ctx.get(),
        }
        if hasattr(record, "extra_fields"):
            payload.update(record.extra_fields)
        return json.dumps(payload)

handler = logging.StreamHandler()
handler.setFormatter(JSONFormatter())
log = logging.getLogger("llm-service")
log.addHandler(handler)
log.setLevel(logging.INFO)

def log_with(msg: str, **fields):
    rec = log.makeRecord(log.name, logging.INFO, "", 0, msg, (), None)
    rec.extra_fields = fields
    log.handle(rec)

# Middleware FastAPI que inyecta y propaga request_id
from fastapi import FastAPI, Request
app = FastAPI()

@app.middleware("http")
async def add_request_id(request: Request, call_next):
    rid = request.headers.get("x-request-id") or str(uuid.uuid4())
    token = request_id_ctx.set(rid)
    try:
        response = await call_next(request)
        response.headers["x-request-id"] = rid
        return response
    finally:
        request_id_ctx.reset(token)
```

### Trazas distribuidas con OpenTelemetry en un pipeline RAG

```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource

resource = Resource.create({"service.name": "rag-chatbot", "service.version": "1.4.2"})
provider = TracerProvider(resource=resource)
provider.add_span_processor(
    BatchSpanProcessor(OTLPSpanExporter(endpoint="http://otel-collector:4317"))
)
trace.set_tracer_provider(provider)
tracer = trace.get_tracer(__name__)

def answer_question(question: str, user_id: str) -> str:
    with tracer.start_as_current_span("rag.answer") as root:
        root.set_attribute("user.id", user_id)
        root.set_attribute("question.length", len(question))

        with tracer.start_as_current_span("rag.embed") as span:
            embedding = embedder.embed(question)
            span.set_attribute("embedding.dim", len(embedding))

        with tracer.start_as_current_span("rag.retrieve") as span:
            docs = vector_db.search(embedding, k=10)
            span.set_attribute("retrieve.top_k", 10)
            span.set_attribute("retrieve.hits", len(docs))

        with tracer.start_as_current_span("rag.rerank") as span:
            docs = reranker.rerank(question, docs)[:3]
            span.set_attribute("rerank.kept", len(docs))

        with tracer.start_as_current_span("rag.llm_call") as span:
            prompt = build_prompt(question, docs)
            span.set_attribute("llm.model", "gpt-4o-mini")
            span.set_attribute("llm.prompt_tokens_estimate", len(prompt) // 4)
            response = openai_client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
            )
            span.set_attribute("llm.completion_tokens", response.usage.completion_tokens)
            span.set_attribute("llm.cost_usd",
                               response.usage.total_tokens * 0.6 / 1_000_000)
            return response.choices[0].message.content
```

### Instrumentación con Langfuse (nativa para LLMs)

```python
from langfuse import Langfuse
from langfuse.openai import openai  # drop-in wrapper
import os

lf = Langfuse(
    public_key=os.environ["LANGFUSE_PUBLIC_KEY"],
    secret_key=os.environ["LANGFUSE_SECRET_KEY"],
    host="https://cloud.langfuse.com",
)

def ask(question: str, user_id: str, session_id: str) -> str:
    trace = lf.trace(
        name="rag-chat",
        user_id=user_id,
        session_id=session_id,
        input={"question": question},
        tags=["prod", "v1.4"],
    )

    retrieval = trace.span(name="retrieve", input={"q": question})
    docs = vector_db.search(embedder.embed(question), k=5)
    retrieval.end(output={"docs": [d.id for d in docs]})

    gen = trace.generation(
        name="llm",
        model="gpt-4o-mini",
        input=[{"role": "user", "content": question}],
    )
    resp = openai.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{"role": "user", "content": build_prompt(question, docs)}],
    )
    answer = resp.choices[0].message.content
    gen.end(
        output=answer,
        usage={
            "input": resp.usage.prompt_tokens,
            "output": resp.usage.completion_tokens,
        },
    )
    trace.update(output={"answer": answer})
    return answer
```

Langfuse captura automáticamente latencia, tokens, costo y permite adjuntar scores de evaluación posteriores (user feedback, LLM-as-judge, etc.) a cada trace.

## Errores comunes

- **Logs sin `request_id`**: imposible correlacionar eventos entre servicios. Cada log debe llevar el identificador propagado.
- **Logs como texto plano**: inservibles a escala. Usar JSON estructurado desde el día uno.
- **Loguear prompts/respuestas crudos sin anonimizar**: viola PII y puede llenar logs con secretos del usuario.
- **No usar sampling en traces de alto volumen**: enviar el 100% de las trazas puede costar más que el propio servicio; usar head-based o tail-based sampling.
- **Spans demasiado gruesos** (solo uno por request): se pierde la descomposición. Spans demasiado finos: ruido y overhead.
- **Instrumentar sin estándar**: cada equipo con su propio formato. Adoptar OpenTelemetry desde el inicio.
- **Métricas con alta cardinalidad** (`user_id` como label): explotan el storage de Prometheus. Usar logs/traces para dimensiones de alta cardinalidad.
- **No propagar contexto entre async tasks**: el `trace_id` se pierde al cambiar de thread o enviar a una cola. Usar los wrappers oficiales de OTel.
- **Confundir monitoreo con observabilidad**: tener dashboards no es suficiente si no puedes investigar lo inesperado.
- **Vendor lock-in**: instrumentar con el SDK propietario de un vendor en lugar de OTel; migrar luego cuesta carísimo.

## Resumen

- La observabilidad se asienta en **tres pilares complementarios**: logs, métricas y traces; cada uno responde preguntas distintas.
- Los **logs estructurados** con `request_id` son la base no negociable de cualquier sistema distribuido.
- Las **métricas** son baratas y rápidas, pero pierden detalle individual; usar histogramas para latencias.
- Las **traces distribuidas** son el pilar más valioso en pipelines LLM/RAG multi-servicio.
- **OpenTelemetry** es el estándar portable que evita lock-in; una sola instrumentación, muchos backends.
- Para LLMs, plataformas especializadas (**Langfuse, LangSmith, Helicone, Arize Phoenix**) añaden contexto que las herramientas APM tradicionales ignoran.
- La **correlación entre pilares** —saltar de métrica a trace a log— convierte observabilidad en superpoder de debugging.
- Instrumentar es trabajo que paga intereses compuestos: la primera vez cuesta, los incidentes futuros se resuelven en minutos en lugar de horas.
