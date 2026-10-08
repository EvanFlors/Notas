# Fundamentos de APIs y Estructura de Peticiones

## ¿Qué es?

Una **API de LLM** es un contrato HTTP (típicamente REST) que recibe mensajes estructurados y devuelve texto generado por un modelo de lenguaje. Es la capa de interfaz que separa **tu aplicación** del **modelo**: tú describes la conversación (roles, contenido, parámetros de muestreo), el proveedor ejecuta la inferencia en sus GPUs y responde con tokens.

El patrón dominante hoy es la **Chat Completion API**: representa la conversación como un array de mensajes con roles (`system`, `user`, `assistant`, y recientemente `tool`). Esto reemplazó al viejo *text completion* (prompt crudo → continuación) porque modela de forma natural el flujo conversacional, encaja con *function calling*, y permite al modelo distinguir instrucciones de contenido del usuario.

> **Definición operativa:** una API de LLM es una función `f(messages, params) → (text, usage, finish_reason)` donde `messages` es un historial estructurado, `params` controla el muestreo (temperature, top_p, max_tokens), y `usage` reporta tokens consumidos para facturación.

### Comparativa de proveedores principales

| Proveedor | Endpoint típico | System message | max_tokens | Función destacada |
|---|---|---|---|---|
| OpenAI | `/v1/chat/completions`, `/v1/responses` | Rol dentro de `messages` | Opcional (default amplio) | JSON mode, Structured Outputs, Assistants |
| Anthropic | `/v1/messages` | Parámetro `system` separado | **Obligatorio** | Prompt caching nativo, computer use, tool_use |
| Google Gemini | `/v1beta/models/*/generateContent` | `systemInstruction` | `maxOutputTokens` | Multimodal nativo, grounding con Search |
| AWS Bedrock | `/model/{id}/converse` (unificado) | Separado | Separado | Multi-proveedor, VPC privado, IAM |
| Azure OpenAI | `/openai/deployments/{id}/chat/completions` | En `messages` | Opcional | SLA empresarial, data residency |
| Mistral/Groq/Together | OpenAI-compatible | En `messages` | Opcional | Precio y latencia agresivos (Groq con LPUs) |

## ¿Por qué importa?

En producción, la elección del proveedor y la forma en que estructuras tus peticiones determinan **costo, latencia, calidad y resiliencia** de tu aplicación. Un sistema que llama al LLM 10 millones de veces al mes gasta distinto si usa `gpt-4o` (~$2.50/MTok input) vs `gpt-4o-mini` (~$0.15/MTok): la diferencia son decenas de miles de dólares.

Además:

- **Portabilidad:** si tu código habla directamente al SDK de un proveedor, migrar a otro cuesta semanas. Una capa de abstracción desde el día 1 te permite rutear por costo, hacer A/B tests y sobrevivir a caídas.
- **Reproducibilidad:** sin controlar `temperature`, `seed`, versión del modelo (`gpt-4o-2024-08-06` vs `gpt-4o-latest`) y `system prompt`, dos ejecuciones idénticas producen resultados distintos. Debuggear incidentes se vuelve imposible.
- **Seguridad y compliance:** una API key filtrada en un commit público puede costar miles antes de que la revoques. GDPR/HIPAA pueden exigir Azure OpenAI (EU residency) o Bedrock en lugar de la API pública.
- **Experiencia del usuario:** la latencia percibida depende de **TTFT** (time to first token) más que de duración total. Elegir streaming + modelo rápido para la primera respuesta y modelo potente para refinamiento es un patrón real.

### Cuándo preocuparte de esto

- Vas a servir más de **1,000 requests/día** → cost tracking importa.
- Hay **usuarios finales esperando** → latencia importa.
- Procesas **datos regulados** → routing a modelo on-prem o VPC importa.
- Vas a mantener la app **más de 6 meses** → abstracción de proveedor importa.

## ¿Cómo funciona?

### Anatomía de una petición Chat Completion

```json
{
  "model": "gpt-4o-2024-08-06",
  "messages": [
    {"role": "system", "content": "Eres un asistente financiero. Responde en JSON."},
    {"role": "user", "content": "Dame el P/E ratio de AAPL hoy."},
    {"role": "assistant", "content": "...", "tool_calls": [...]},
    {"role": "tool", "tool_call_id": "call_abc", "content": "{\"pe\": 28.3}"}
  ],
  "temperature": 0.2,
  "max_tokens": 500,
  "top_p": 1.0,
  "frequency_penalty": 0,
  "presence_penalty": 0,
  "stop": ["\n\n###"],
  "seed": 42,
  "response_format": {"type": "json_object"},
  "stream": false,
  "user": "hash_de_usuario_para_abuse_tracking"
}
```

Cada parámetro tiene un propósito concreto:

| Parámetro | Rango típico | Qué hace |
|---|---|---|
| `temperature` | 0.0 - 2.0 | Suaviza la distribución de probabilidades sobre tokens. 0 = determinista (modo *greedy*). 1 = distribución nativa. >1 = más caótico. |
| `top_p` (nucleus) | 0.0 - 1.0 | Trunca a los tokens que acumulan `p` de probabilidad. 0.9 descarta la cola de baja probabilidad. **Elige uno: temperature O top_p**. |
| `max_tokens` | 1 - límite modelo | Tope duro de tokens generados. **Hard cap de costo.** |
| `frequency_penalty` | -2.0 - 2.0 | Penaliza tokens ya usados (reduce repetición). |
| `presence_penalty` | -2.0 - 2.0 | Penaliza tokens que ya aparecieron una sola vez (empuja a nuevos temas). |
| `stop` | lista de strings | Corta la generación al ver estos tokens. |
| `seed` | int | Intenta reproducibilidad (best effort). |
| `response_format` | `json_object` / `json_schema` | Fuerza salida parseable. |

### Flujo de red real

```
Cliente (Python/Node)
     │
     ▼  HTTPS POST (TLS 1.3) + Authorization: Bearer sk-...
┌─────────────────────┐
│  API Gateway        │  autentica, rate-limita, enruta
└──────────┬──────────┘
           ▼
┌─────────────────────┐
│  Load balancer      │  elige región/pool con menor cola
└──────────┬──────────┘
           ▼
┌─────────────────────┐
│  Inference servers  │  vLLM / TGI / Triton / interno
│  (GPUs A100/H100)   │  batch dinámico, KV cache
└──────────┬──────────┘
           ▼
  Response JSON + headers (x-ratelimit-*, request-id)
```

### Arquitectura recomendada en el cliente

```
┌──────────────────────────────────────────────────────────┐
│  Tu app FastAPI/Next.js                                  │
│    ↓                                                     │
│  LLMRouter  ──┬── Cache (Redis, hash del prompt)         │
│    ↓          └── Rate limiter (token bucket por tenant) │
│  Adapter (OpenAI | Anthropic | Bedrock)                  │
│    ↓                                                     │
│  Retry + circuit breaker + fallback (Opus→Sonnet→Haiku)  │
│    ↓                                                     │
│  Observabilidad (Langfuse/Helicone/LangSmith)            │
│    ↓                                                     │
│  HTTP client (httpx con pool de conexiones)              │
└──────────────────────────────────────────────────────────┘
```

### Autenticación segura

Nunca hagas:

```python
client = OpenAI(api_key="sk-proj-abcd1234...")  # ❌ En el código
```

Hazlo así:

```python
import os
from openai import OpenAI
from anthropic import Anthropic

# Carga desde variables de entorno (12-factor app)
openai = OpenAI(api_key=os.environ["OPENAI_API_KEY"], timeout=30.0, max_retries=0)
anthropic = Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"], timeout=30.0, max_retries=0)
```

En producción, usa un **secret manager**: AWS Secrets Manager, Google Secret Manager, HashiCorp Vault, Doppler. Rota las keys cada 90 días. Configura **scoped keys** por servicio (OpenAI permite restringir por organización y proyecto).

### Estrategia de selección de modelo

| Fase | Modelo recomendado | Razón |
|---|---|---|
| Prototipo rápido | `gpt-4o`, `claude-sonnet-4` | Máxima calidad, iteras rápido |
| Benchmark de calidad | Varios en paralelo contra golden set | Decides con datos, no intuición |
| Producción masiva | Más barato que pase el benchmark | Costo por request manda |
| Fallback de emergencia | Otro proveedor + modelo pequeño | Resiliencia ante caídas |

**Patrón tiered routing:**

```python
def pick_model(query: str, user_tier: str) -> str:
    if user_tier == "free" and len(query) < 500:
        return "gpt-4o-mini"       # barato, suficiente
    if contains_code(query) or user_tier == "pro":
        return "claude-sonnet-4"   # mejor en código
    if is_critical(query):
        return "gpt-5"             # calidad máxima
    return "gpt-4o"                # default equilibrado
```

## Ejemplo con código

### Endpoint FastAPI con abstracción de proveedor

```python
# llm_router.py
from __future__ import annotations
import os, time, logging, hashlib, json
from typing import Protocol, Literal
from dataclasses import dataclass
from openai import OpenAI, APIError, RateLimitError, APITimeoutError
from anthropic import Anthropic, APIError as AnthropicError
from pydantic import BaseModel, Field
from fastapi import FastAPI, HTTPException, Depends
import redis.asyncio as redis

log = logging.getLogger("llm")

# ---------- Modelos de datos ----------
class Message(BaseModel):
    role: Literal["system", "user", "assistant"]
    content: str

class ChatRequest(BaseModel):
    messages: list[Message]
    model: str = "gpt-4o-mini"
    temperature: float = Field(0.7, ge=0, le=2)
    max_tokens: int = Field(500, ge=1, le=8000)

class ChatResponse(BaseModel):
    text: str
    model: str
    prompt_tokens: int
    completion_tokens: int
    cost_usd: float
    latency_ms: int
    cached: bool = False

# ---------- Pricing (USD por 1M tokens, octubre 2026) ----------
PRICING = {
    "gpt-4o":        {"in": 2.50,  "out": 10.00},
    "gpt-4o-mini":   {"in": 0.15,  "out": 0.60},
    "gpt-5":         {"in": 5.00,  "out": 15.00},
    "claude-opus-4": {"in": 15.00, "out": 75.00},
    "claude-sonnet-4":{"in": 3.00, "out": 15.00},
    "claude-haiku-4":{"in": 0.25,  "out": 1.25},
}

def cost(model: str, pin: int, pout: int) -> float:
    p = PRICING.get(model, {"in": 0, "out": 0})
    return (pin * p["in"] + pout * p["out"]) / 1_000_000

# ---------- Adaptador por proveedor ----------
class Provider(Protocol):
    async def chat(self, req: ChatRequest) -> ChatResponse: ...

class OpenAIProvider:
    def __init__(self): self.c = OpenAI(timeout=30, max_retries=0)
    async def chat(self, req: ChatRequest) -> ChatResponse:
        t0 = time.perf_counter()
        r = self.c.chat.completions.create(
            model=req.model,
            messages=[m.model_dump() for m in req.messages],
            temperature=req.temperature,
            max_tokens=req.max_tokens,
        )
        ms = int((time.perf_counter() - t0) * 1000)
        u = r.usage
        return ChatResponse(
            text=r.choices[0].message.content,
            model=req.model,
            prompt_tokens=u.prompt_tokens,
            completion_tokens=u.completion_tokens,
            cost_usd=cost(req.model, u.prompt_tokens, u.completion_tokens),
            latency_ms=ms,
        )

class AnthropicProvider:
    def __init__(self): self.c = Anthropic(timeout=30, max_retries=0)
    async def chat(self, req: ChatRequest) -> ChatResponse:
        # Anthropic separa el system del resto
        system = next((m.content for m in req.messages if m.role == "system"), "")
        msgs = [m.model_dump() for m in req.messages if m.role != "system"]
        t0 = time.perf_counter()
        r = self.c.messages.create(
            model=req.model,
            system=system,
            messages=msgs,
            temperature=req.temperature,
            max_tokens=req.max_tokens,   # obligatorio
        )
        ms = int((time.perf_counter() - t0) * 1000)
        return ChatResponse(
            text=r.content[0].text,
            model=req.model,
            prompt_tokens=r.usage.input_tokens,
            completion_tokens=r.usage.output_tokens,
            cost_usd=cost(req.model, r.usage.input_tokens, r.usage.output_tokens),
            latency_ms=ms,
        )

def route(model: str) -> Provider:
    if model.startswith("claude"): return AnthropicProvider()
    return OpenAIProvider()

# ---------- Cache de respuestas idempotentes ----------
r = redis.from_url(os.getenv("REDIS_URL", "redis://localhost:6379"))

def cache_key(req: ChatRequest) -> str:
    payload = json.dumps(req.model_dump(), sort_keys=True).encode()
    return "llm:" + hashlib.sha256(payload).hexdigest()

async def get_cached(req: ChatRequest) -> ChatResponse | None:
    if req.temperature > 0:  # no cacheamos salidas aleatorias
        return None
    raw = await r.get(cache_key(req))
    if raw:
        d = json.loads(raw); d["cached"] = True
        return ChatResponse(**d)
    return None

async def put_cached(req: ChatRequest, resp: ChatResponse, ttl: int = 3600):
    if req.temperature == 0:
        await r.setex(cache_key(req), ttl, resp.model_dump_json())

# ---------- Endpoint ----------
app = FastAPI()

@app.post("/chat", response_model=ChatResponse)
async def chat(req: ChatRequest):
    if cached := await get_cached(req):
        log.info("cache_hit", extra={"model": req.model})
        return cached
    try:
        resp = await route(req.model).chat(req)
    except RateLimitError as e:
        raise HTTPException(429, f"rate limited: retry in {e.response.headers.get('retry-after', '?')}s")
    except APITimeoutError:
        raise HTTPException(504, "upstream timeout")
    except (APIError, AnthropicError) as e:
        raise HTTPException(502, f"provider error: {e}")
    await put_cached(req, resp)
    return resp
```

### Perfiles de parámetros por caso de uso

```python
PROFILES = {
    "factual":   {"temperature": 0.1, "top_p": 0.9,  "max_tokens": 300},
    "balanced":  {"temperature": 0.5, "top_p": 1.0,  "max_tokens": 500},
    "creative":  {"temperature": 0.9, "top_p": 0.95, "max_tokens": 800},
    "code":      {"temperature": 0.0, "top_p": 1.0,  "max_tokens": 2000,
                  "stop": ["```\n\n"]},
    "extraction":{"temperature": 0.0, "response_format": {"type": "json_object"}},
}
```

### Output estructurado con Pydantic + JSON Schema

```python
from pydantic import BaseModel
from openai import OpenAI

class Ticket(BaseModel):
    severity: Literal["low", "medium", "high", "critical"]
    category: Literal["billing", "technical", "account"]
    summary: str
    needs_human: bool

client = OpenAI()
r = client.beta.chat.completions.parse(
    model="gpt-4o-2024-08-06",
    messages=[
        {"role": "system", "content": "Clasifica el ticket de soporte."},
        {"role": "user",   "content": "Mi tarjeta fue cobrada dos veces."},
    ],
    response_format=Ticket,   # genera JSON Schema internamente
)
ticket: Ticket = r.choices[0].message.parsed
assert ticket.category == "billing"
```

### Headers útiles de inspeccionar

```python
r = client.chat.completions.with_raw_response.create(...)
print(r.headers["x-request-id"])              # para abrir soporte
print(r.headers["openai-processing-ms"])      # tiempo de inferencia puro
print(r.headers["x-ratelimit-remaining-requests"])
print(r.headers["x-ratelimit-reset-tokens"])
```

## Errores comunes

- **Hardcodear la API key** en el código o commitearla al repo. GitHub escanea y los bots revocan en minutos, pero no antes de que te cobren miles. Usa `.env` + `.gitignore` + secret manager.
- **No fijar `max_tokens`** en Anthropic (es obligatorio, pero también en OpenAI es buena idea). Un prompt mal diseñado puede generar 4,000 tokens de salida y multiplicar tu factura por 10.
- **Mezclar `temperature` y `top_p`** cambiando ambos. La doc oficial recomienda tocar uno solo; combinarlos produce comportamiento difícil de razonar.
- **Meter contenido conversacional en el system prompt** (ej. "¡Hola! Hoy vas a..."). El system es para instrucciones estables y verificables, no diálogo.
- **No manejar rate limits**. OpenAI y Anthropic devuelven `429` con header `retry-after`. Ignorarlo y reintentar inmediatamente provoca *retry storms* que empeoran la saturación.
- **Hacer *context stuffing*** inyectando todo el historial sin truncar. Un chat de 2 horas puede acumular 50k tokens → cada mensaje nuevo cuesta 10x más. Implementa summarización o ventana deslizante.
- **No usar `timeout` en el cliente HTTP**. Un modelo colgado puede dejar tu worker bloqueado minutos. Fija `timeout=30s` y aborta.
- **Loguear el contenido completo del prompt/respuesta** sin considerar PII. Infracción de GDPR/HIPAA. Hashea o redacta antes de persistir.
- **No versionar los prompts**. Cambios silenciosos en el prompt rompen comportamientos sin tests. Usa un sistema de prompt management (LangSmith, Langfuse, PromptLayer) o commitea los prompts en archivos `.md` versionados.
- **Confiar en `gpt-4o` sin pin de fecha** (`gpt-4o-2024-08-06`). Los alias se actualizan sin aviso y tu golden set deja de pasar.
- **No implementar fallback de proveedor**. Cuando OpenAI tiene una caída de 2 horas (sucede), tu app muere. Un circuit breaker que caiga a Anthropic salva el SLA.
- **Enviar PII sin redacción**: nombres, emails, tarjetas, DNIs. Usa Presidio, AWS Comprehend o un paso regex antes de llamar al modelo.
- **Reintentar errores 4xx** (400 Bad Request, 401 Unauthorized, 404). Esos errores no mejoran con tiempo; solo gastas requests.

## Observabilidad mínima recomendada

| Métrica | Tool recomendada | Alerta en |
|---|---|---|
| Latencia p50/p95/p99 | Prometheus + Grafana | p95 > 3s |
| Cost per request | Langfuse / Helicone | +50% WoW |
| Tasa de error 429/5xx | Datadog / Sentry | >1% en 5min |
| Cache hit rate | Redis `INFO` | <30% (prompt no está siendo reutilizado) |
| TTFT (streaming) | Instrumentación custom | p95 > 1s |
| Drift de calidad | LangSmith evals en producción | score < baseline - 5% |

## Resumen

- Las APIs modernas de LLM usan **arrays de mensajes con roles** (`system`, `user`, `assistant`, `tool`) y devuelven texto más metadata de `usage`.
- **OpenAI y Anthropic** difieren en detalles clave: Anthropic separa `system`, exige `max_tokens`, soporta prompt caching nativo; OpenAI tiene Structured Outputs con Pydantic.
- Controla la generación con **temperature, top_p, max_tokens, stop, seed, response_format**: no toques temperature y top_p a la vez, y fija `max_tokens` siempre como cap de costo.
- Diseña tu código con una **capa de abstracción** desde el día 1 (`LLMRouter` + `Provider` adapter). Te permite A/B tests, fallbacks y migración entre proveedores sin reescribir todo.
- Protege las API keys con **variables de entorno + secret manager + rotación**. Nunca las commitees.
- Perfiles de parámetros por caso de uso (**factual, balanced, creative, code, extraction**) evitan copiar-pegar configs y producen resultados consistentes.
- Métricas que importan en producción: **latencia p95, costo por request, tasa de 429, cache hit rate, TTFT, drift de calidad**.
- Nunca reintentes errores 4xx, siempre respeta `retry-after`, y configura circuit breakers con fallback a otro proveedor para sobrevivir caídas.
- La elección de modelo es un **tradeoff cost/quality/latency**: *tiered routing* (mini para queries triviales, flagship para críticas) suele ganar sobre cualquier modelo fijo.
