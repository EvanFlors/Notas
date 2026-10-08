# Aplicaciones de Generación de Imágenes en Producción

## ¿Qué es?

Una **aplicación de generación de imágenes en producción** es un sistema que, de forma confiable, convierte peticiones de usuarios en imágenes generadas, almacenadas y servidas, gestionando:

- **Arquitectura en capas**: prompt processing, generación, moderación, almacenamiento, delivery.
- **Procesamiento asíncrono y colas**: la generación tarda 5-30 segundos; no se puede bloquear request HTTP.
- **Optimización de costos**: caching, deduplicación, elección de calidad adecuada por caso de uso.
- **Moderación de contenido**: filtros antes (prompt) y después (imagen) para cumplir políticas.
- **Observabilidad**: logging, métricas, trazas; sin esto no se puede operar un sistema que gasta USD/request.
- **Resiliencia**: retries, fallbacks, circuit breakers, degradación elegante.
- **Multi-modelo**: enrutar a DALL-E 3, GPT-Image, Flux o SD según costo/calidad.

Es la diferencia entre un notebook y un servicio con SLA.

## ¿Por qué importa?

Un error de arquitectura en generación de imágenes es más caro que en texto:

- **Costo marginal 100-1000× mayor** que un LLM call (USD 0.04-0.19 vs USD 0.001).
- **Latencia 10× mayor** (10-30s vs 1-3s), incompatible con request síncronos HTTP.
- **Impacto legal** si no moderas (deepfakes, contenido ilegal, infracción de copyright).
- **Reputación de marca** si imágenes malas llegan al usuario sin revisión.
- **Scaling cost blowups**: sin cache ni rate limiting, un bot puede quemar USD 10k en una noche.

Las empresas que generan a escala (Canva, Shopify, Adobe) invierten tanto en infraestructura como en los modelos mismos.

## ¿Cómo funciona?

### Arquitectura en capas (clean architecture)

```
┌─────────────────────────────────────────────┐
│  API Gateway (FastAPI/Express)               │
│  - Rate limiting por usuario                 │
│  - Autenticación                             │
└──────────────┬──────────────────────────────┘
               │
┌──────────────▼──────────────────────────────┐
│  Prompt Processor                            │
│  - Validación (content policy)               │
│  - Optimización (templates, enrichment)      │
│  - Deduplicación / cache lookup              │
└──────────────┬──────────────────────────────┘
               │
┌──────────────▼──────────────────────────────┐
│  Job Queue (Redis / SQS / Celery)            │
│  - Prioridad por tier (free/paid)            │
│  - Dead letter queue                         │
└──────────────┬──────────────────────────────┘
               │
┌──────────────▼──────────────────────────────┐
│  Generation Workers (async pool)             │
│  - Model router (DALL-E / Flux / SDXL)       │
│  - Retry + backoff                           │
│  - Fallback a modelo alternativo             │
└──────────────┬──────────────────────────────┘
               │
┌──────────────▼──────────────────────────────┐
│  Post-processing                             │
│  - Moderación de la imagen (Rekognition)     │
│  - Upscaling, watermark                      │
│  - Thumbnail generation                      │
└──────────────┬──────────────────────────────┘
               │
┌──────────────▼──────────────────────────────┐
│  Storage + CDN (S3 + CloudFront)             │
└──────────────┬──────────────────────────────┘
               │
┌──────────────▼──────────────────────────────┐
│  Notification (webhook / WebSocket / email) │
└─────────────────────────────────────────────┘
```

### Patrones de procesamiento

| Patrón | Cuándo usarlo | Latencia percibida |
|---|---|---|
| **Síncrono bloqueante** | Prototipos, demos | Usuario espera 15-30s |
| **Polling** | Dashboards simples | Cliente consulta cada 2s |
| **WebSocket** | SaaS con feedback en vivo | Push instantáneo |
| **Webhook** | Pipeline B2B, batch | Server-to-server |
| **Email / notificación push** | Jobs largos (upscale 4K) | Minutos a horas |

### Estrategias de optimización de costos

| Estrategia | Ahorro típico |
|---|---|
| **Cache por hash de prompt+params** | 30-70% en workloads repetitivos |
| **Deduplicación en batch** | 10-40% |
| **Elegir calidad adecuada** (standard vs HD) | 50% |
| **Enrutamiento a modelo barato** cuando basta | 60-90% |
| **Pre-generar top-N prompts populares** | depende |
| **Lazy generation** (solo cuando usuario pide) | evita waste |
| **Watermark + compression antes de servir** | ahorro CDN |

### Comparativa de precios de referencia (2025)

| Modelo | Precio aprox. por imagen 1024² |
|---|---|
| DALL-E 2 | $0.016 - $0.020 |
| DALL-E 3 standard | $0.040 |
| DALL-E 3 HD | $0.080 - $0.120 |
| GPT-Image-1 low | $0.011 |
| GPT-Image-1 medium | $0.042 |
| GPT-Image-1 high | $0.167 - $0.190 |
| Flux.1 schnell (Replicate) | $0.003 |
| Flux.1 pro (Replicate) | $0.055 |
| SDXL (Replicate) | $0.0023 / sec |
| Self-hosted SDXL en GPU A10G | ~$0.001 por imagen |

### Moderación de contenido

Dos capas obligatorias:

1. **Pre-generación (prompt)**: regex de términos prohibidos + llamada a `/v1/moderations` de OpenAI o modelo local.
2. **Post-generación (imagen)**: AWS Rekognition, Google Vision Safe Search, o un modelo CLIP-based clasificador NSFW.

## Ejemplo con código

### 1. Servicio base con capas separadas

```python
from dataclasses import dataclass
from typing import Protocol
import hashlib, base64, logging

logger = logging.getLogger(__name__)

@dataclass
class GenerationRequest:
    prompt: str
    user_id: str
    size: str = "1024x1024"
    quality: str = "standard"
    model: str = "dall-e-3"

@dataclass
class GenerationResult:
    image_bytes: bytes
    url: str | None
    cost_cents: float
    model_used: str
    revised_prompt: str | None = None


class PromptProcessor:
    FORBIDDEN = {"nude", "gore", "exploit"}

    def validate(self, prompt: str) -> tuple[bool, str]:
        low = prompt.lower()
        for term in self.FORBIDDEN:
            if term in low:
                return False, f"blocked term: {term}"
        if len(prompt) > 4000:
            return False, "prompt too long"
        return True, "ok"

    def enrich(self, prompt: str) -> str:
        if not any(k in prompt.lower()
                   for k in ("quality", "detail", "8k", "4k")):
            prompt += ", high detail, professional quality"
        return prompt


class ImageCache(Protocol):
    def get(self, key: str) -> bytes | None: ...
    def set(self, key: str, data: bytes) -> None: ...


class S3Storage:
    def __init__(self, client, bucket: str, cdn_base: str):
        self.s3, self.bucket, self.cdn = client, bucket, cdn_base

    def store(self, data: bytes, key: str) -> str:
        self.s3.put_object(
            Bucket=self.bucket, Key=key, Body=data,
            ContentType="image/png", CacheControl="public, max-age=31536000",
        )
        return f"{self.cdn}/{key}"


class ModelRouter:
    """Elige modelo según caso de uso y presupuesto."""
    def pick(self, req: GenerationRequest) -> str:
        if req.quality == "low":
            return "gpt-image-1-mini"
        if req.quality == "hd":
            return "gpt-image-1"
        return "dall-e-3"
```

### 2. Generación con reintentos y fallback

```python
import time
from openai import OpenAI, RateLimitError, APIError, BadRequestError

client = OpenAI()

def _call(model: str, prompt: str, size: str, quality: str) -> dict:
    params = {"model": model, "prompt": prompt, "size": size, "n": 1}
    if model.startswith("dall-e"):
        params["response_format"] = "url"
    if model == "dall-e-3":
        params["quality"] = quality
    return client.images.generate(**params).model_dump()

def generate_with_fallback(prompt: str, size="1024x1024",
                           quality="standard",
                           primary="dall-e-3",
                           fallback="gpt-image-1-mini",
                           max_retries=3) -> dict:
    for model in (primary, fallback):
        for attempt in range(max_retries):
            try:
                return {"ok": True, "model": model,
                        "response": _call(model, prompt, size, quality)}
            except BadRequestError as e:
                return {"ok": False, "error": f"policy: {e}"}
            except RateLimitError:
                time.sleep(2 ** attempt)
            except APIError as e:
                if e.status_code in (401, 403):
                    return {"ok": False, "error": str(e)}
                time.sleep(2 ** attempt)
        logger.warning(f"model {model} exhausted retries, trying fallback")
    return {"ok": False, "error": "all models failed"}
```

### 3. Worker asíncrono con semáforo

```python
import asyncio
from openai import AsyncOpenAI

class AsyncImageService:
    def __init__(self, max_concurrent: int = 10):
        self.client = AsyncOpenAI()
        self.sem = asyncio.Semaphore(max_concurrent)

    async def generate(self, req: GenerationRequest) -> dict:
        async with self.sem:
            params = {
                "model": req.model, "prompt": req.prompt,
                "size": req.size, "n": 1,
            }
            if req.model.startswith("dall-e"):
                params["response_format"] = "url"
                params["quality"] = req.quality
            r = await self.client.images.generate(**params)
            d = r.data[0]
            return {
                "url": getattr(d, "url", None),
                "b64": getattr(d, "b64_json", None),
                "revised": getattr(d, "revised_prompt", None),
            }

    async def generate_batch(self, reqs: list[GenerationRequest]) -> list[dict]:
        return await asyncio.gather(*(self.generate(r) for r in reqs))
```

### 4. Cache con Redis

```python
import hashlib, json, redis

class RedisImageCache:
    def __init__(self, url: str, ttl_days: int = 30):
        self.r = redis.from_url(url)
        self.ttl = ttl_days * 86400

    def _key(self, req: GenerationRequest) -> str:
        payload = json.dumps({
            "p": req.prompt, "s": req.size,
            "q": req.quality, "m": req.model,
        }, sort_keys=True)
        return "img:" + hashlib.sha256(payload.encode()).hexdigest()

    def get(self, req: GenerationRequest) -> str | None:
        return self.r.get(self._key(req))

    def set(self, req: GenerationRequest, cdn_url: str) -> None:
        self.r.setex(self._key(req), self.ttl, cdn_url)
```

### 5. Moderación con OpenAI Moderation API

```python
def moderate_prompt(prompt: str) -> dict:
    r = client.moderations.create(
        model="omni-moderation-latest",
        input=prompt,
    )
    result = r.results[0]
    return {
        "flagged": result.flagged,
        "categories": result.categories.model_dump(),
    }

check = moderate_prompt("a peaceful mountain landscape")
if check["flagged"]:
    raise ValueError(f"prompt blocked: {check['categories']}")
```

### 6. Moderación de imagen con AWS Rekognition

```python
import boto3

rek = boto3.client("rekognition", region_name="us-east-1")

def is_safe(image_bytes: bytes, max_confidence: float = 70.0) -> tuple[bool, list]:
    r = rek.detect_moderation_labels(
        Image={"Bytes": image_bytes},
        MinConfidence=max_confidence,
    )
    labels = r.get("ModerationLabels", [])
    return len(labels) == 0, labels
```

### 7. Orquestador completo

```python
class ImageGenerationApp:
    def __init__(self, cache: RedisImageCache, storage: S3Storage,
                 router: ModelRouter, processor: PromptProcessor):
        self.cache = cache
        self.storage = storage
        self.router = router
        self.processor = processor
        self.service = AsyncImageService(max_concurrent=10)

    async def handle(self, req: GenerationRequest) -> GenerationResult:
        # 1. Validar
        ok, reason = self.processor.validate(req.prompt)
        if not ok:
            raise ValueError(reason)

        mod = moderate_prompt(req.prompt)
        if mod["flagged"]:
            raise ValueError("prompt violates policy")

        # 2. Enrich + enrutar
        req.prompt = self.processor.enrich(req.prompt)
        req.model = self.router.pick(req)

        # 3. Cache hit
        if (cached := self.cache.get(req)) is not None:
            logger.info("cache hit")
            return GenerationResult(
                image_bytes=b"", url=cached.decode(),
                cost_cents=0, model_used="cache",
            )

        # 4. Generar
        gen = await self.service.generate(req)

        # 5. Obtener bytes
        if gen["url"]:
            import requests
            img_bytes = requests.get(gen["url"], timeout=30).content
        else:
            img_bytes = base64.b64decode(gen["b64"])

        # 6. Moderar imagen
        safe, labels = is_safe(img_bytes)
        if not safe:
            raise ValueError(f"image blocked: {labels}")

        # 7. Guardar en S3 + CDN
        key = f"gen/{req.user_id}/{hashlib.md5(img_bytes).hexdigest()}.png"
        cdn_url = self.storage.store(img_bytes, key)

        # 8. Cachear
        self.cache.set(req, cdn_url)

        return GenerationResult(
            image_bytes=img_bytes,
            url=cdn_url,
            cost_cents=4.0 if req.model == "dall-e-3" else 1.1,
            model_used=req.model,
            revised_prompt=gen.get("revised"),
        )
```

### 8. Observabilidad: métricas Prometheus

```python
from prometheus_client import Counter, Histogram

GEN_TOTAL = Counter("image_gen_total",
                    "Total generations",
                    ["model", "status"])
GEN_LATENCY = Histogram("image_gen_latency_seconds",
                        "Generation latency",
                        ["model"])
GEN_COST = Counter("image_gen_cost_cents_total",
                   "Cumulative cost in cents",
                   ["model"])

async def generate_tracked(req: GenerationRequest) -> GenerationResult:
    with GEN_LATENCY.labels(req.model).time():
        try:
            res = await app.handle(req)
            GEN_TOTAL.labels(req.model, "success").inc()
            GEN_COST.labels(req.model).inc(res.cost_cents)
            return res
        except Exception:
            GEN_TOTAL.labels(req.model, "error").inc()
            raise
```

### 9. API FastAPI con cola Celery

```python
from fastapi import FastAPI, HTTPException
from celery import Celery

app_api = FastAPI()
celery = Celery("gen", broker="redis://localhost:6379/0")

@celery.task(bind=True, max_retries=3)
def generate_task(self, prompt: str, user_id: str, webhook: str | None):
    try:
        req = GenerationRequest(prompt=prompt, user_id=user_id)
        result = asyncio.run(app.handle(req))
        if webhook:
            import requests
            requests.post(webhook, json={
                "status": "done", "url": result.url,
                "model": result.model_used,
            }, timeout=10)
        return result.url
    except Exception as e:
        raise self.retry(exc=e, countdown=2 ** self.request.retries)

@app_api.post("/generate")
async def enqueue(payload: dict):
    task = generate_task.delay(
        payload["prompt"], payload["user_id"], payload.get("webhook"),
    )
    return {"job_id": task.id, "status": "queued"}

@app_api.get("/jobs/{job_id}")
async def status(job_id: str):
    r = generate_task.AsyncResult(job_id)
    return {"status": r.status, "result": r.result if r.ready() else None}
```

## Errores comunes

- **Request HTTP síncrono para generación de 15-30s**: timeouts, UX terrible, workers bloqueados. Siempre usa cola + polling/WebSocket/webhook.
- **No cachear**: usuarios piden lo mismo (promos, templates, placeholders). Sin cache gastas 10-100× más.
- **Cache key sin incluir `model` y `size`**: devuelves imagen incorrecta cuando el usuario cambia parámetros.
- **No descargar URLs de DALL-E inmediatamente**: expiran en ~1h; links rotos en producción.
- **No moderar prompt O imagen**: solo moderar texto no detecta ataques como "a girl in a bikini on a beach" que pasa el filtro de prompt pero genera contenido NSFW.
- **Hardcode de un solo modelo**: cuando OpenAI tiene outage, todo cae. Implementa fallback a Flux/SD.
- **Falta de rate limiting por usuario**: un bot free-tier puede quemarte USD 1,000/día.
- **No pasar `user=user_id`** a OpenAI: pierdes trazabilidad para disputas.
- **Loggear el prompt completo con PII** sin cuidado: GDPR violation.
- **No fijar límites de concurrencia** (`asyncio.Semaphore`): saturas rate limits y empeoras latencia global.
- **Guardar en S3 sin `CacheControl` ni compresión**: costos de egress inflados.
- **No implementar circuit breaker**: cuando el proveedor falla, intentas infinitamente y acumulas latencia.
- **Elegir siempre HD cuando basta standard**: 2× precio por diferencia imperceptible en thumbnails.
- **No monitorear costo diario**: enteras del gasto cuando llega la factura. Alerta en Prometheus a USD/hora.
- **Mezclar generación con delivery**: la lógica de serving (CDN, thumbnails, watermark) debe ir en una capa separada, no en el worker de generación.
- **No manejar `revised_prompt` de DALL-E 3**: usuarios ven resultado inesperado y no saben por qué.
- **Confiar en moderación perfecta**: siempre deja un botón "report" para humanos.

## Resumen

- Una app de generación en producción se estructura en capas: **API gateway → prompt processor → queue → workers → post-processing → storage/CDN → notification**.
- **Nunca generes síncronamente en el request HTTP**: usa cola (Celery/SQS) + polling/WebSocket/webhook.
- **Optimización de costos**: cache por hash (prompt+size+quality+model), deduplicación en batch, elegir calidad adecuada, enrutar a modelo barato cuando basta.
- Un **router de modelos** decide entre DALL-E 3 (calidad), GPT-Image-1 (SOTA/inpaint), Flux (barato/open), SDXL (self-hosted).
- **Moderación en dos capas**: pre (prompt via `/moderations`) y post (imagen via Rekognition / Google Vision).
- **Resiliencia**: retries con backoff exponencial, fallback a modelo alternativo, circuit breakers, dead letter queues.
- **Observabilidad obligatoria**: métricas (Prometheus), logs estructurados, trazas (OpenTelemetry), alertas de costo por hora.
- **Rate limiting por usuario** y `user=user_id` en requests a OpenAI para trazabilidad.
- **Storage**: S3 + CDN (CloudFront) con `CacheControl: public, max-age=31536000` para archivos inmutables.
- **URLs de DALL-E expiran en ~1h**: descarga inmediatamente y guarda en S3.
- Precios de referencia (2025): DALL-E 3 $0.04-$0.12, GPT-Image $0.011-$0.19, Flux $0.003-$0.055, SDXL self-host ~$0.001.
- Patrones de delivery: polling (simple), WebSocket (realtime SaaS), webhook (B2B), email (jobs largos).
- Casos de uso: e-commerce (product + lifestyle), social media (hero graphics), prototipado UI, personalización 1:1, data augmentation.
- Siempre deja un **botón "report"** para feedback humano; ninguna moderación es perfecta.
- Separa claramente **generación** (workers) de **delivery** (CDN) para escalar independiente.
