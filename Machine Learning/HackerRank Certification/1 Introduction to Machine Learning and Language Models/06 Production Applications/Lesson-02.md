# Streaming e Implementación en Tiempo Real

## ¿Qué es?

**Streaming** en el contexto de LLMs significa recibir y mostrar la respuesta **token por token** (o chunk por chunk) a medida que el modelo la genera, en lugar de esperar a que esté completa. Técnicamente, el servidor mantiene una conexión HTTP abierta y empuja fragmentos a medida que están disponibles usando **Server-Sent Events (SSE)**, un estándar web unidireccional servidor→cliente definido en HTML5.

Un LLM genera tokens de manera **autoregresiva**: cada token depende de los anteriores, uno a la vez, a una velocidad típica de 30-150 tokens/segundo según el modelo. Sin streaming, el usuario espera `total_tokens / tok_s` segundos viendo una pantalla en blanco. Con streaming, ve el primer token en ~300-800 ms (**TTFT, time to first token**) y luego el texto fluye.

### SSE vs otras tecnologías de tiempo real

| Tecnología | Dirección | Protocolo | Overhead | Uso típico en LLMs |
|---|---|---|---|---|
| **SSE** | Server → Client | HTTP/1.1 o /2 | Bajo | ✅ Estándar de facto para respuestas de LLM |
| **WebSockets** | Bidireccional | ws:// | Medio | Chats colaborativos, voice streaming |
| **Long polling** | Cliente pregunta | HTTP | Alto | Legado, evitar |
| **gRPC streaming** | Bidireccional | HTTP/2 | Bajo | Backend-a-backend (vLLM interno) |
| **HTTP/2 push** | Server→Client | HTTP/2 | Bajo | Casi deprecado |

## ¿Por qué importa?

Es un asunto de **UX, no de performance**. El tiempo total de respuesta es el mismo (incluso ligeramente mayor por overhead de SSE), pero la **latencia percibida** se desploma:

| Métrica | Sin streaming | Con streaming |
|---|---|---|
| Tiempo hasta ver algo (TTFT) | 8-30 s | 0.3-0.8 s |
| Sensación del usuario | "¿Se colgó?" | "Está pensando conmigo" |
| Abandono (bounce rate) | 15-40% | 2-5% |
| Posibilidad de cancelar temprano | ❌ (ya pagaste) | ✅ (`AbortController`) |

Beneficios adicionales:

- **Ahorro de costo**: si el usuario ve que la respuesta va mal, cancela y no pagas los 2,000 tokens restantes.
- **Progreso en herramientas largas**: en agentes, puedes mostrar razonamiento y llamadas a tools en vivo.
- **Debugging**: ves si el modelo se atasca en un loop o genera basura antes de terminar.
- **Mejor cola de workers**: no bloqueas un worker 30 s; liberas la conexión por eventos.

### El trade-off

- **Más complejidad en frontend y backend**: hay que lidiar con reconexión, buffers parciales, cancelación, race conditions.
- **Headers y proxies**: nginx, CloudFront, Cloudflare bufferizan por defecto y rompen SSE. Hay que configurar `X-Accel-Buffering: no`, `Cache-Control: no-cache`, deshabilitar `gzip` y evitar HTTP/1.0.
- **Observabilidad distinta**: necesitas instrumentar **TTFT**, **inter-token latency (ITL)**, y **tokens/sec**, no solo `response_time`.

## ¿Cómo funciona?

### Flujo bajo el capó

```
Cliente                        Tu backend                    Proveedor LLM
   │                              │                              │
   │── GET /chat/stream ─────────▶│                              │
   │   Accept: text/event-stream  │                              │
   │                              │── POST /v1/.../stream=true ─▶│
   │                              │                              │
   │                              │◀── data: {"delta":"Hola"} ───│  (SSE)
   │◀── data: {"text":"Hola"} ────│                              │
   │                              │◀── data: {"delta":" mun"} ───│
   │◀── data: {"text":"mun"} ─────│                              │
   │                              │◀── data: {"delta":"do"} ─────│
   │◀── data: {"text":"do"} ──────│                              │
   │                              │◀── data: [DONE] ─────────────│
   │◀── data: [DONE] ─────────────│                              │
```

### Formato SSE en el cable

Un stream SSE es texto plano UTF-8. Cada evento es un bloque separado por `\n\n`:

```
event: delta
data: {"content": "Hola"}

event: delta
data: {"content": " mundo"}

event: done
data: {"total_tokens": 2, "finish_reason": "stop"}

```

Reglas:

- Terminador de evento: **doble salto de línea** `\n\n`.
- Campos soportados: `event:`, `data:`, `id:`, `retry:`.
- `data:` puede repetirse en múltiples líneas → se concatenan con `\n`.
- Comentarios: líneas que empiezan con `:` (útil como keepalive: `: ping`).
- Content-Type: `text/event-stream`.

### Diferencias por proveedor

**OpenAI** entrega chunks tipo `ChatCompletionChunk` con `choices[0].delta.content`:

```json
{"choices": [{"delta": {"content": "Hola"}, "finish_reason": null}]}
```

**Anthropic** usa un protocolo de **eventos tipados**:

```
event: message_start      → {"id": "msg_...", "usage": {...}}
event: content_block_start→ {"index": 0, "content_block": {...}}
event: content_block_delta→ {"delta": {"type": "text_delta", "text": "Hola"}}
event: content_block_stop
event: message_delta      → {"delta": {"stop_reason": "end_turn"}}
event: message_stop
```

**Google Gemini** entrega JSON lines (no SSE puro) sobre la respuesta HTTP.

El SDK oficial de cada proveedor normaliza esto; raramente parseas SSE a mano salvo que construyas tu propio proxy.

## Ejemplo con código

### Backend: FastAPI que hace streaming de OpenAI y lo reenvía al cliente

```python
# app/stream.py
import asyncio, json, time, logging
from typing import AsyncIterator
from fastapi import FastAPI, Request
from fastapi.responses import StreamingResponse
from openai import AsyncOpenAI, APIError, APITimeoutError
from pydantic import BaseModel

log = logging.getLogger("stream")
app = FastAPI()
client = AsyncOpenAI(timeout=60)

class StreamReq(BaseModel):
    prompt: str
    model: str = "gpt-4o-mini"

async def sse(data: dict, event: str | None = None) -> bytes:
    """Formatea un evento SSE."""
    out = ""
    if event:
        out += f"event: {event}\n"
    out += f"data: {json.dumps(data, ensure_ascii=False)}\n\n"
    return out.encode()

async def generate(req: StreamReq, request: Request) -> AsyncIterator[bytes]:
    t0 = time.perf_counter()
    first_token_t: float | None = None
    total_tokens = 0

    try:
        stream = await client.chat.completions.create(
            model=req.model,
            messages=[{"role": "user", "content": req.prompt}],
            stream=True,
            stream_options={"include_usage": True},   # ← pide usage al final
            max_tokens=1000,
        )

        async for chunk in stream:
            # Cliente abortó (cerró pestaña, canceló): deja de generar y ahorra tokens
            if await request.is_disconnected():
                log.info("client_disconnect: cancelando stream")
                await stream.response.aclose()
                return

            # Keepalive cada N chunks para proxies que cierran por inactividad
            if chunk.usage is not None:
                yield await sse({
                    "usage": chunk.usage.model_dump(),
                    "latency_ms": int((time.perf_counter() - t0) * 1000),
                    "ttft_ms": int(first_token_t * 1000) if first_token_t else None,
                }, event="usage")
                continue

            delta = chunk.choices[0].delta.content or ""
            if delta:
                if first_token_t is None:
                    first_token_t = time.perf_counter() - t0
                total_tokens += 1
                yield await sse({"content": delta}, event="delta")

        yield await sse({"finish_reason": "stop"}, event="done")

    except APITimeoutError:
        yield await sse({"error": "upstream_timeout"}, event="error")
    except APIError as e:
        yield await sse({"error": str(e), "code": getattr(e, "code", None)}, event="error")
    except Exception as e:
        log.exception("stream_fatal")
        yield await sse({"error": "internal"}, event="error")

@app.post("/chat/stream")
async def chat_stream(req: StreamReq, request: Request):
    return StreamingResponse(
        generate(req, request),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache, no-transform",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",  # desactiva buffering en nginx
        },
    )
```

### Backend: streaming con Anthropic (eventos tipados)

```python
import anthropic

aclient = anthropic.AsyncAnthropic()

async def anthropic_stream(prompt: str):
    async with aclient.messages.stream(
        model="claude-sonnet-4-20250514",
        max_tokens=1000,
        messages=[{"role": "user", "content": prompt}],
    ) as stream:
        async for text in stream.text_stream:   # abstracción conveniente
            yield text
        final = await stream.get_final_message()
        yield f"\n\n[tokens: in={final.usage.input_tokens} out={final.usage.output_tokens}]"
```

### Frontend: parsing SSE con `EventSource` vs `fetch` + ReadableStream

`EventSource` es la API nativa, pero solo soporta GET y no permite custom headers (incluido `Authorization: Bearer`). En apps reales usamos `fetch` + stream manual:

```javascript
// client.js
const abort = new AbortController();

async function streamChat(prompt) {
  const resp = await fetch("/chat/stream", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${token}`,
    },
    body: JSON.stringify({ prompt }),
    signal: abort.signal,
  });

  if (!resp.ok) throw new Error(`HTTP ${resp.status}`);

  const reader = resp.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";

  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });

    // Procesa solo eventos completos (terminan en \n\n), guarda el resto
    const events = buffer.split("\n\n");
    buffer = events.pop();   // último fragmento (posiblemente incompleto)

    for (const evt of events) {
      const lines = evt.split("\n");
      const eventName = lines.find(l => l.startsWith("event:"))?.slice(6).trim();
      const dataLine  = lines.find(l => l.startsWith("data:"))?.slice(5).trim();
      if (!dataLine) continue;

      try {
        const data = JSON.parse(dataLine);
        if (eventName === "delta") appendToUI(data.content);
        else if (eventName === "done") finalizeUI();
        else if (eventName === "error") showError(data.error);
        else if (eventName === "usage") trackCost(data.usage);
      } catch (e) {
        console.warn("bad SSE frame", dataLine);
      }
    }
  }
}

// Cancelar al navegar o escribir nueva pregunta
window.addEventListener("beforeunload", () => abort.abort());
```

### Instrumentación de métricas de streaming

```python
from prometheus_client import Histogram, Counter

TTFT       = Histogram("llm_ttft_seconds", "Time to first token", ["model"])
ITL        = Histogram("llm_inter_token_ms", "Inter-token latency", ["model"])
TOKENS_SEC = Histogram("llm_tokens_per_sec", "Throughput", ["model"])
STREAM_ERR = Counter("llm_stream_errors_total", "", ["model", "reason"])

# En el loop de generación
last_t = time.perf_counter()
for chunk in stream:
    now = time.perf_counter()
    ITL.labels(model=req.model).observe((now - last_t) * 1000)
    last_t = now
TOKENS_SEC.labels(model=req.model).observe(total_tokens / (now - t0))
TTFT.labels(model=req.model).observe(first_token_t)
```

### Objetivos típicos de SLO para streaming

| Métrica | Objetivo p95 | Modelo rápido | Modelo pesado |
|---|---|---|---|
| TTFT | <1 s | <400 ms | <1500 ms |
| Tokens/sec | >30 | 60-120 | 25-50 |
| Error rate | <0.5% | | |
| Reconexiones por request | <0.1 | | |

## Errores comunes

- **No reenviar `is_disconnected`** del cliente al modelo. Si el usuario cierra la pestaña, sigues pagando tokens hasta que termine la generación. Siempre cancela upstream.
- **Buffering en el proxy**. nginx, CloudFront, Cloudflare bufferizan `text/event-stream` por defecto. El usuario ve todo al final. Fix: `proxy_buffering off;` + header `X-Accel-Buffering: no`. En Cloudflare, usa el modo "Streaming" o fetch directo.
- **Asumir que cada chunk SSE contiene un JSON completo**. Un chunk de red puede traer `data: {"text":"ho`  (incompleto). Siempre bufferea y parsea solo cuando ves `\n\n`.
- **No manejar el `[DONE]`** de OpenAI vs los eventos tipados de Anthropic. Confundir ambos protocolos hace que el cliente nunca cierre la UI de "pensando...".
- **Memory leaks en frontend** por no limpiar `AbortController`, listeners o referencias a streams anteriores cuando el usuario envía una pregunta nueva. Siempre cancela el stream previo antes de iniciar uno nuevo.
- **No usar keepalive**. Proxies cortan conexiones inactivas (>30-60 s). Si el modelo tarda en empezar (prompt gigante), la conexión muere. Emite `: ping\n\n` cada 15 s.
- **Logs sincrónicos dentro del loop**. Hacer `log.info(chunk)` en cada token añade decenas de ms de latencia. Agrega al final o usa logging asíncrono.
- **No medir TTFT**. El p95 de response time es inútil para UX de streaming; TTFT y tokens/sec son los indicadores reales.
- **Race conditions con múltiples requests concurrentes**: usuario escribe rápido, aún no cancelas el anterior, los tokens se mezclan en el UI. Mantén un `requestId` y descarta deltas que no coincidan con el activo.
- **Chunked gzip rompe streaming**. Si tu proxy comprime la respuesta, buffereará para calcular el tamaño. Deshabilita gzip para `text/event-stream`.
- **Reintentar la petición completa** cuando el stream se corta a la mitad. En vez de eso, usa el header `Last-Event-ID` y haz resume si tu modelo lo soporta (raro) o simplemente avisa al usuario y pide que repita.
- **Mostrar texto crudo sin sanitizar**. Si el modelo emite HTML o markdown con `<script>`, lo renderizas y abres XSS. Usa `DOMPurify` + markdown parser seguro.
- **No incluir `stream_options={"include_usage": True}`** en OpenAI → pierdes contabilidad de tokens de requests streameados.

## Patrones avanzados

### Backpressure y worker pools

```python
# Limita cuántos streams concurrentes aguanta tu servidor
import asyncio
SEM = asyncio.Semaphore(100)  # máximo 100 streams simultáneos

async def guarded_stream(req, request):
    async with SEM:
        async for ev in generate(req, request):
            yield ev
```

### Fallback de modelo en vivo

Si TTFT excede un umbral, cancela y reintenta con un modelo más rápido:

```python
async def with_fallback(prompt):
    try:
        async with asyncio.timeout(2.0):
            async for t in stream("gpt-5", prompt):
                yield t
            return
    except asyncio.TimeoutError:
        yield "[switching to faster model...]\n"
        async for t in stream("gpt-4o-mini", prompt):
            yield t
```

### Streaming de function calls

Los tool calls también se streamean en deltas (`tool_calls[0].function.arguments`). Debes concatenar los deltas de `arguments` y parsear el JSON solo al cerrar el bloque:

```python
args_buf = ""
async for chunk in stream:
    tc = chunk.choices[0].delta.tool_calls
    if tc and tc[0].function.arguments:
        args_buf += tc[0].function.arguments
# al terminar
import json
args = json.loads(args_buf)
```

## Resumen

- **Streaming** cambia la UX: la respuesta aparece token a token con **TTFT ~500 ms** en vez de bloquear hasta tener todo. El tiempo total no mejora, pero la percepción sí.
- Usa **SSE** (`text/event-stream`) para servir chunks: unidireccional, HTTP estándar, encaja con infra existente. WebSockets solo si necesitas bidireccionalidad.
- **OpenAI** manda `delta.content` + `[DONE]`; **Anthropic** manda eventos tipados (`content_block_delta`, `message_delta`). Los SDKs oficiales abstraen esto.
- En backend, **cancela upstream** cuando el cliente desconecta (`request.is_disconnected()`) para no pagar tokens que nadie verá.
- Configura proxies: **`X-Accel-Buffering: no`**, `Cache-Control: no-cache`, sin gzip, keepalive activo. Si no, los eventos llegan en bloque y el streaming no sirve.
- En frontend, parsea con `fetch` + `ReadableStream` + buffer de líneas, maneja cancelación con `AbortController`, y limpia listeners al desmontar.
- Instrumenta métricas específicas: **TTFT, inter-token latency, tokens/sec, stream_errors**. El `response_time` tradicional no basta.
- Patrones avanzados valiosos: **fallback de modelo** por TTFT, **backpressure** con semáforo, streaming de **tool calls**, **keepalive** para proxies.
- Pitfalls más caros: chunks incompletos parseados mal, no cancelar upstream, buffering de proxy, memory leaks, no instrumentar TTFT.
