# Monitoreo en Producción y Confiabilidad

## ¿Qué es?

**Monitoreo y confiabilidad** en sistemas con LLMs es el conjunto de prácticas, métricas y mecanismos defensivos que mantienen tu aplicación funcionando, barata y predecible frente a fallas únicas de este tipo de componente: proveedores que se saturan, respuestas que degradan en calidad, context windows que explotan, costos que se disparan y streams que se cortan a la mitad.

A diferencia de un backend tradicional (CPU-bound, estado conocido, errores binarios), un LLM es:

- **Dependencia externa cara** (centavos por llamada en vez de microsegundos).
- **No determinista** (misma entrada, salidas distintas).
- **Degrada en calidad** sin "caerse" (devuelve 200 OK con basura).
- **Rate-limitado por tokens**, no solo por requests.
- **Variable en latencia** (10x diferencia entre prompts cortos y largos).

### Las métricas clave

| Métrica | Qué mide | Objetivo típico |
|---|---|---|
| **TTFT** (time to first token) | UX de streaming | p95 < 1 s |
| **TPS** (tokens per second) | Throughput de generación | >30 tok/s |
| **E2E latency** | Tiempo total | p95 < 5 s |
| **Error rate por tipo** | Diagnóstico | <0.5% 5xx, <2% 429 |
| **Cost per request** | FinOps | depende; alerta >50% WoW |
| **Cache hit rate** | Eficiencia | >30% en workloads repetitivos |
| **Quality score** | Drift de modelo | ±5% de baseline |
| **Context length p95** | Riesgo de overflow | <80% de la ventana |

## ¿Por qué importa?

Los fallos de LLMs son **silenciosos y caros**. Casos reales que han llegado a postmortems públicos:

- Un asistente de código produjo respuestas correctas durante 3 meses; un cambio en el modelo (`gpt-4` → `gpt-4-turbo` como alias) bajó la aceptación de sugerencias un 18% sin que nadie se enterara durante 2 semanas.
- Una app de análisis de PDFs recibió un documento de 400 páginas: el prompt stuffing generó una factura de $12,000 en una noche.
- Un chatbot pasó de responder en 2s a 25s cuando el proveedor hizo rolling update; sin TTFT instrumentado, el equipo se enteró por el CEO.
- Un endpoint sin circuit breaker reintentó agresivamente durante una caída de OpenAI y disparó rate limits en toda la cuenta de la empresa, matando otros servicios.

Un sistema sin esta disciplina **sobrevive al día 1 pero se cae en el día 100** cuando el tráfico escala, aparecen edge cases o cambia el modelo.

### SLOs recomendados

| Nivel | Latencia p95 | Error budget | Reemplazo |
|---|---|---|---|
| Interactivo (chatbot) | 3 s | 1% / mes | Fallback a modelo pequeño |
| Streaming | TTFT 1 s | 1% / mes | Model fallback por TTFT |
| Batch (análisis) | 60 s | 5% / mes | Retry con backoff |
| Background | 10 min | 10% / mes | DLQ + reproceso diario |

## ¿Cómo funciona?

### Taxonomía de errores en LLMs

| Tipo | Código HTTP | Causa | Acción correcta |
|---|---|---|---|
| `RateLimitError` | 429 | Excediste RPM o TPM | Esperar `retry-after`, backoff si no viene |
| `ContextLengthError` | 400 | Prompt + max_tokens > ventana | Truncar/summarizar; NO reintentar |
| `OverloadedError` | 529 (Anthropic) / 503 | Proveedor saturado | Fallback a otro modelo/proveedor |
| `InvalidRequestError` | 400 | JSON malformado, params inválidos | Fix; NO reintentar |
| `AuthError` | 401/403 | Key inválida/revocada | Alertar on-call; NO reintentar |
| `TimeoutError` | - | Modelo tarda demasiado | Reintentar con `max_tokens` menor |
| `ContentFilterError` | 400 | Prompt o salida violó policy | Loggear + mostrar mensaje al usuario |
| `JSONParseError` | 200 | Modelo rompió el schema pedido | Reintentar con prompt más estricto |
| `QualityDrop` | 200 | Respuesta válida pero mala | Eval en producción + alertar |
| `StreamInterrupted` | - | Red cortó mid-stream | Reanudar o mostrar lo que llegó |

### Patrón retry: exponential backoff + jitter

```python
import random, time, logging
from typing import Callable, TypeVar

T = TypeVar("T")
log = logging.getLogger(__name__)

def retry_with_backoff(
    fn: Callable[[], T],
    *,
    max_attempts: int = 4,
    base: float = 0.5,
    cap: float = 30.0,
    retriable: tuple = (ConnectionError, TimeoutError),
) -> T:
    """Reintenta con backoff exponencial + jitter completo (AWS style).

    Delay = random(0, min(cap, base * 2**attempt))
    """
    for attempt in range(max_attempts):
        try:
            return fn()
        except retriable as e:
            if attempt == max_attempts - 1:
                raise
            sleep = random.uniform(0, min(cap, base * (2 ** attempt)))
            log.warning("retry attempt=%d sleep=%.2fs err=%s", attempt, sleep, e)
            time.sleep(sleep)
```

**No reintentes a ciegas.** La lógica correcta discrimina por tipo:

```python
from openai import RateLimitError, APIError, APITimeoutError, BadRequestError

def smart_call(request):
    try:
        return client.chat.completions.create(**request)

    except RateLimitError as e:
        # Respeta el header del proveedor (no inventes delay)
        wait = float(e.response.headers.get("retry-after", 1))
        time.sleep(wait)
        return client.chat.completions.create(**request)

    except BadRequestError as e:
        if "context_length" in str(e).lower():
            request["messages"] = truncate_messages(request["messages"], max_tokens=4000)
            return client.chat.completions.create(**request)
        raise  # otros 400 no se reintentan

    except (APITimeoutError, APIError) as e:
        # 5xx: usa fallback de modelo
        return fallback_provider.chat.completions.create(**request)
```

### Circuit breaker

Evita el *retry storm* contra un proveedor caído: si la tasa de error sube de un umbral, abre el circuito y falla rápido (sin pegarle al upstream) durante un periodo.

```python
import time, threading
from enum import Enum

class State(Enum):
    CLOSED = "closed"       # todo bien, requests pasan
    OPEN = "open"           # falla rápido, no toca upstream
    HALF_OPEN = "half_open" # prueba un request de muestra

class CircuitBreaker:
    def __init__(self, failure_threshold=5, reset_timeout=30, window=60):
        self.failure_threshold = failure_threshold
        self.reset_timeout = reset_timeout
        self.window = window
        self.failures: list[float] = []
        self.state = State.CLOSED
        self.opened_at: float | None = None
        self.lock = threading.Lock()

    def call(self, fn, *a, **kw):
        with self.lock:
            now = time.time()
            self.failures = [t for t in self.failures if now - t < self.window]
            if self.state == State.OPEN:
                if now - self.opened_at > self.reset_timeout:
                    self.state = State.HALF_OPEN
                else:
                    raise RuntimeError("circuit_open")
        try:
            r = fn(*a, **kw)
        except Exception:
            with self.lock:
                self.failures.append(time.time())
                if len(self.failures) >= self.failure_threshold:
                    self.state = State.OPEN
                    self.opened_at = time.time()
            raise
        else:
            with self.lock:
                if self.state == State.HALF_OPEN:
                    self.state = State.CLOSED
                    self.failures.clear()
            return r
```

### Model fallback cascade

```
Opus (calidad máxima) ──falla──▶ Sonnet ──falla──▶ Haiku ──falla──▶ Mensaje al usuario
```

```python
MODEL_CASCADE = ["claude-opus-4", "claude-sonnet-4", "claude-haiku-4"]

def call_with_cascade(messages, max_tokens=500):
    last_err = None
    for model in MODEL_CASCADE:
        try:
            return breaker[model].call(
                anthropic.messages.create,
                model=model, messages=messages, max_tokens=max_tokens
            )
        except Exception as e:
            log.warning("model_failed", extra={"model": model, "err": str(e)})
            last_err = e
    raise RuntimeError(f"all models failed; last={last_err}")
```

### Observabilidad: qué, cómo y con qué

| Capa | Herramienta | Qué ves |
|---|---|---|
| Métricas | Prometheus + Grafana, Datadog | latencia, QPS, errores por tipo |
| Logs estructurados | Loki, CloudWatch, Datadog Logs | request_id, modelo, tokens |
| Tracing distribuido | OpenTelemetry → Tempo/Jaeger | spans de app → LLM → DB |
| LLM-específica | Langfuse, LangSmith, Helicone, Arize Phoenix | prompts, outputs, evals, cost |
| Alertas | PagerDuty, Opsgenie | basadas en SLO/SLI |
| Error tracking | Sentry | stack traces, grouping |

**Logging estructurado seguro**:

```python
import json, hashlib, logging
from datetime import datetime, UTC

log = logging.getLogger("llm")

def log_call(req, resp, error=None, latency_ms=None):
    log.info(json.dumps({
        "ts": datetime.now(UTC).isoformat(),
        "request_id": req.id,
        "user_hash": hashlib.sha256(req.user_id.encode()).hexdigest()[:16],
        "model": req.model,
        "prompt_tokens": resp.usage.input_tokens if resp else None,
        "completion_tokens": resp.usage.output_tokens if resp else None,
        "cost_usd": round(cost(req.model, resp), 6) if resp else None,
        "latency_ms": latency_ms,
        "ttft_ms": resp.ttft_ms if resp else None,
        "error_type": type(error).__name__ if error else None,
        "error_code": getattr(error, "code", None),
        "finish_reason": resp.finish_reason if resp else None,
        # NO loggees content; si es imprescindible, hashea o trunca a <50 chars
        "prompt_preview": req.messages[-1].content[:40] + "..." if req else None,
    }))
```

**Reglas de privacidad en logs:**

- Nunca loguees el contenido completo del prompt/respuesta en producción.
- Hashea user IDs (SHA-256 trunca a 16 chars).
- Loguea tokens y costos, no texto.
- Retención ≤ 30-90 días (GDPR Art. 5(1)(e)).
- En Europa, considera `pseudonymization` + consent explícito.

### Health checks sintéticos

```python
HEALTH_PROMPT = "Responde SOLO con 'OK'."

def check_model(model: str) -> dict:
    t0 = time.perf_counter()
    try:
        r = client.chat.completions.create(
            model=model,
            messages=[{"role": "user", "content": HEALTH_PROMPT}],
            max_tokens=5, temperature=0, timeout=5,
        )
        txt = r.choices[0].message.content.strip().upper()
        ok = txt.startswith("OK")
        return {"model": model, "healthy": ok, "latency_ms": int((time.perf_counter()-t0)*1000)}
    except Exception as e:
        return {"model": model, "healthy": False, "error": str(e)}
```

Córrelo cada 60 s desde una cronjob y expone `/health/llm` a tu sistema de alertas.

### Rate limit tracking proactivo

```python
def inspect_headers(resp_headers):
    remaining_tokens = int(resp_headers.get("x-ratelimit-remaining-tokens", 1_000_000))
    remaining_reqs   = int(resp_headers.get("x-ratelimit-remaining-requests", 10_000))
    reset = resp_headers.get("x-ratelimit-reset-tokens", "unknown")
    if remaining_tokens < 10_000:
        alert(f"token budget low: {remaining_tokens} (reset {reset})")
    return remaining_tokens, remaining_reqs
```

### FinOps: alertas de costo

- Alertas por **budget**: 50%, 80%, 95% del presupuesto mensual.
- Alertas por **spike**: costo horario > 3× media móvil 7d.
- **Cost attribution** por `user_id`, `endpoint`, `feature flag`.
- **Daily cost report** por modelo a Slack.

```python
if daily_cost > budget * 0.95:
    disable_feature_flag("llm_summarize_long_pdfs")
    page_oncall("llm cost 95% of monthly budget")
```

## Ejemplo con código

### Stack completo: FastAPI + retry + circuit breaker + Langfuse + fallback

```python
# resilient_llm.py
import os, time, asyncio, logging
from typing import Literal
from openai import AsyncOpenAI, RateLimitError, APIError, BadRequestError
from anthropic import AsyncAnthropic
from pydantic import BaseModel
from fastapi import FastAPI, HTTPException
from langfuse.decorators import observe, langfuse_context
import tenacity

log = logging.getLogger("llm")
openai = AsyncOpenAI(timeout=30, max_retries=0)
anthropic = AsyncAnthropic(timeout=30, max_retries=0)

class Query(BaseModel):
    text: str
    user_id: str

# ---------- Retry policy ----------
retry_policy = tenacity.AsyncRetrying(
    stop=tenacity.stop_after_attempt(3),
    wait=tenacity.wait_exponential_jitter(initial=1, max=10),
    retry=tenacity.retry_if_exception_type((APIError, TimeoutError)),
    before_sleep=tenacity.before_sleep_log(log, logging.WARNING),
)

# ---------- Fallback cascade ----------
async def try_openai(prompt: str) -> tuple[str, dict]:
    async for attempt in retry_policy:
        with attempt:
            r = await openai.chat.completions.create(
                model="gpt-4o",
                messages=[{"role": "user", "content": prompt}],
                max_tokens=500,
            )
            return r.choices[0].message.content, {
                "model": "gpt-4o",
                "prompt_tokens": r.usage.prompt_tokens,
                "completion_tokens": r.usage.completion_tokens,
            }

async def try_anthropic(prompt: str) -> tuple[str, dict]:
    r = await anthropic.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=500,
        messages=[{"role": "user", "content": prompt}],
    )
    return r.content[0].text, {
        "model": "claude-sonnet-4",
        "prompt_tokens": r.usage.input_tokens,
        "completion_tokens": r.usage.output_tokens,
    }

@observe()
async def answer(prompt: str) -> dict:
    """Pide a OpenAI; si falla cae a Anthropic; si falla, respuesta estática."""
    langfuse_context.update_current_trace(user_id="hashed_user")
    t0 = time.perf_counter()
    try:
        txt, meta = await try_openai(prompt)
    except RateLimitError:
        log.warning("openai_rate_limited; falling back to anthropic")
        txt, meta = await try_anthropic(prompt)
    except Exception as e:
        log.exception("openai_hard_failure")
        try:
            txt, meta = await try_anthropic(prompt)
        except Exception:
            return {"text": "Estamos experimentando problemas. Intenta en unos minutos.",
                    "degraded": True}
    meta["latency_ms"] = int((time.perf_counter() - t0) * 1000)
    return {"text": txt, **meta}

# ---------- Endpoint ----------
app = FastAPI()

@app.post("/ask")
async def ask(q: Query):
    try:
        return await answer(q.text)
    except BadRequestError as e:
        raise HTTPException(400, str(e))
```

### Dashboard mínimo (Grafana queries)

```promql
# Latencia p95 por modelo
histogram_quantile(0.95, sum(rate(llm_request_duration_bucket[5m])) by (model, le))

# Costo acumulado del día
sum(increase(llm_cost_usd_total[1d])) by (model)

# Tasa de rate limits
sum(rate(llm_errors_total{type="RateLimitError"}[5m])) / sum(rate(llm_requests_total[5m]))

# TTFT p95
histogram_quantile(0.95, sum(rate(llm_ttft_seconds_bucket[5m])) by (model, le))
```

## Errores comunes

- **Reintentos ciegos en loop infinito** → amplifican la caída del proveedor y queman tu cuota de tokens. Usa `max_attempts` + backoff exponencial + jitter.
- **Ignorar el header `retry-after`** en 429. Inventas tu propio delay y lo haces mucho más corto; el proveedor te bloquea más duro.
- **No distinguir tipo de error.** Reintentar un 400 (contexto demasiado largo) no mejora nunca; solo gasta llamadas.
- **No tener circuit breaker.** Un modelo caído tumba toda tu app porque cada worker se queda bloqueado esperando timeout.
- **Logs con PII**. Nombres, emails, DNIs, direcciones en los logs es violación de GDPR. Hashea user IDs y nunca persistas el content crudo.
- **Alertas por valores absolutos** ("latencia > 2s") en vez de **percentiles o budgets** → fatiga de alertas, el equipo las silencia y pierdes señales reales.
- **No instrumentar TTFT**. Mides `response_time` total y el UX se degrada sin que te enteres (el p95 baja porque las respuestas son más cortas, pero el usuario sigue esperando).
- **Context explosion**. No monitorear la longitud del contexto y de pronto todos los chats largos empiezan a fallar con 400. Añade métrica `context_length` y trim cuando excedas 70% de la ventana.
- **Health checks que no usan el modelo real**. Pings al endpoint `/health` del proveedor no detectan degradación de calidad. Usa prompts canary con output esperado.
- **Fallbacks que no se prueban**. El fallback a Anthropic lleva 3 meses sin ejecutarse; el día que lo necesitas, la API key está vencida. Córrelo en producción con sombra (1% del tráfico) regularmente.
- **No versionar prompts**. Un cambio en un f-string "pequeño" baja la calidad un 20% y no sabes qué commit lo introdujo. Guarda prompts en archivos versionados y correlaciona con métricas de calidad.
- **Cost surprises** por no monitorear en tiempo real. Un bug de infinite loop puede quemar $10k en una noche. Alertas de budget al 50/80/95%.
- **No simular caídas**. Chaos engineering con `toxiproxy` o `litmus`: tira el proveedor y verifica que tu fallback funcione.
- **Guardar tokens de contexto crudos** en Redis/DB sin TTL ni encriptación → compliance + bloat.

## Resiliencia avanzada: shadow traffic y canary

- **Shadow deployment**: envía el request también al modelo nuevo pero descarta la respuesta; compara calidad y latencia offline. Cero riesgo.
- **Canary**: enruta el 1% del tráfico al nuevo modelo, mide SLIs, incrementa gradualmente (1% → 5% → 25% → 50% → 100%).
- **Feature flags** (LaunchDarkly, Flagsmith, Unleash) para activar/desactivar cambios en segundos sin deploy.
- **Game days**: ejercicios programados donde el equipo simula caídas y practica la respuesta.

## Resumen

- Los sistemas con LLM fallan de maneras **nuevas y silenciosas**: overload, degradación de calidad, context overflow, cost spikes, streams cortados. No bastan monitores de "server down".
- **Métricas que importan**: TTFT, tokens/sec, latencia p95/p99, error rate por tipo, cost per request, cache hit rate, quality score, context length.
- **Retry inteligente**: respeta `retry-after`, backoff exponencial con jitter, max_attempts, discrimina por tipo de error. Nunca reintentes 4xx (excepto 429).
- **Circuit breaker** evita retry storms y protege proveedores saturados.
- **Model fallback cascade** (Opus → Sonnet → Haiku, o OpenAI → Anthropic) convierte caídas de proveedor en degradación amable.
- **Observabilidad en 4 capas**: métricas (Prometheus), logs estructurados (sin PII), tracing (OpenTelemetry), LLM-específica (Langfuse/Helicone/LangSmith).
- **FinOps**: alertas por budget 50/80/95%, cost attribution por feature, kill switches por feature flag ante spikes.
- **Health checks sintéticos** con prompts canary cada 60 s; prueban calidad, no solo disponibilidad.
- **Privacidad**: hashea user IDs, nunca persistas content crudo, retención ≤ 90 días.
- **Resiliencia avanzada**: shadow traffic, canary deploys, feature flags, chaos engineering, game days.
- Lo que no se mide no se mejora; lo que no se prueba no funciona el día que lo necesitas.
