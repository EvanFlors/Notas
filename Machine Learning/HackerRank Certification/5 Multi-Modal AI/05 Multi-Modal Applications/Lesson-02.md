# Despliegue a producción de aplicaciones multimodales

## ¿Qué es?

Desplegar una aplicación multimodal es llevar un prototipo que funciona en un notebook a un sistema que atiende tráfico real **de forma confiable, escalable, observable y rentable**. Implica decisiones de infraestructura muy distintas a una API tradicional, porque:

- Las cargas son **heterogéneas**: una request puede ser 2 KB de texto, otra 10 MB de video.
- Las latencias varían de 50 ms (texto corto) a 30 s (análisis de video completo).
- Los costos por request son 10-1000x más altos que una API clásica.
- Muchos componentes son servicios externos (OpenAI, Anthropic, ElevenLabs) con SLA independientes y rate limits.

La arquitectura típica combina un **API gateway**, un **orquestador**, **microservicios por modalidad**, **colas** para carga asíncrona, **caché** para resultados repetidos, **almacenamiento** para media y una capa de **observabilidad** completa.

![Patrón de despliegue en producción: gateway + orquestador + servicios por modalidad, con caché, colas y observabilidad](https://hrcdn.net/ai-engineering/module-5/light/multimodal-lesson02-production-architecture.svg)

## ¿Por qué importa?

Un modelo que funciona offline no es un producto. El 70% del esfuerzo de un proyecto multimodal en producción se va en infraestructura, observabilidad y manejo de fallos. Casos reales que ilustran por qué importa:

- **Air Canada chatbot (2024):** un agente conversacional dio información falsa sobre reembolsos; el tribunal falló contra la aerolínea. Lección: necesitas **monitoreo semántico** y guardrails, no solo latencia.
- **ChatGPT voice mode (2024-2025):** OpenAI tuvo que diseñar un pipeline de voz-a-voz con latencia <500 ms a escala global; su arquitectura usa realtime API con WebRTC + edge regions.
- **Document AI de Stripe:** procesa decenas de miles de facturas al día; usan colas (SQS) + workers con autoscaling + caché por hash de archivo para no re-procesar duplicados.
- **Be My Eyes + GPT-4o:** millones de descripciones de imágenes para personas ciegas; el fallback cuando GPT-4o cae es derivar a un voluntario humano.

## ¿Cómo funciona?

### Arquitectura de microservicios por modalidad

Separar cada modalidad en su propio servicio tiene ventajas claras:

- **Escalado independiente:** si vision domina el tráfico, escalas solo ese pod.
- **Despliegue aislado:** actualizas el modelo de visión sin tocar el de audio.
- **Blast radius pequeño:** una caída de TTS no derriba todo.
- **Modelos distintos por servicio:** vision en GPU, STT en instancia optimizada para audio, LLM delegado a un proveedor externo.

```
         ┌─────────────┐
         │ API Gateway │ (auth, rate limit, routing)
         └──────┬──────┘
                │
         ┌──────▼──────┐
         │ Orchestrator│ (lógica de negocio, tool-use)
         └─┬────┬────┬─┘
     ┌─────┘    │    └─────┐
     ▼          ▼          ▼
 ┌───────┐ ┌───────┐ ┌───────┐
 │Vision │ │ Audio │ │ Text  │  servicios por modalidad
 │Service│ │Service│ │Service│
 └───┬───┘ └───┬───┘ └───┬───┘
     └─────┬───┴────┬────┘
           ▼        ▼
      ┌─────────┐ ┌─────────┐
      │  Cache  │ │ Vector  │
      │ (Redis) │ │   DB    │
      └─────────┘ └─────────┘
```

### API Gateway

Un gateway (Kong, Envoy, AWS API Gateway, Cloudflare) centraliza:

- **Autenticación** (API keys, OAuth, JWT).
- **Rate limiting por usuario y por modalidad** (vision es más caro, limita más agresivo).
- **Routing** por tipo de contenido.
- **Validación de tamaño** (rechaza imágenes >10 MB antes de llegar al modelo).
- **Request/response logging** redactado.

### Procesamiento síncrono vs. asíncrono

| Caso | Patrón | Timeout objetivo |
|---|---|---|
| Chat con texto | Síncrono con streaming SSE | 30 s |
| Voice agent | Streaming bidireccional (WebRTC/WebSocket) | 500 ms end-to-end |
| Análisis de factura | Síncrono, con retry | 10 s |
| Análisis de video largo | Asíncrono (cola + webhook) | sin límite |
| Generación de imagen batch | Asíncrono + progreso polling | sin límite |

**Regla práctica**: si la operación tarda >5 s, hazla asíncrona con cola.

### Colas y workers

Patrón clásico para tareas pesadas (análisis de video, generación de imagen en batch, OCR masivo):

```python
# Pipeline con Redis Queue (rq) para procesamiento asíncrono
import redis, uuid, os
from rq import Queue
from fastapi import FastAPI, UploadFile, HTTPException

r = redis.Redis(host="redis", port=6379)
q = Queue("vision", connection=r, default_timeout=600)
app = FastAPI()

def analizar_video_job(video_path: str) -> dict:
    """Job de worker: extrae frames, los analiza, resume."""
    from procesadores import extraer_frames, analizar_frames, resumir
    frames = extraer_frames(video_path, fps=1)
    analisis = analizar_frames(frames)
    return {"resumen": resumir(analisis), "n_frames": len(frames)}

@app.post("/videos")
async def encolar_video(file: UploadFile):
    if file.size > 500 * 1024 * 1024:
        raise HTTPException(413, "Video >500MB")
    path = f"/data/videos/{uuid.uuid4()}.mp4"
    with open(path, "wb") as f:
        f.write(await file.read())
    job = q.enqueue(analizar_video_job, path)
    return {"job_id": job.id, "status_url": f"/jobs/{job.id}"}

@app.get("/jobs/{job_id}")
def status(job_id: str):
    job = q.fetch_job(job_id)
    if job is None:
        raise HTTPException(404)
    return {"status": job.get_status(), "result": job.result}
```

### Caché a múltiples niveles

Las imágenes y audios son candidatos ideales a caché porque son **contenido idempotente** (misma entrada → misma salida):

- **L1 (en memoria del proceso):** `functools.lru_cache` para resultados de la última hora.
- **L2 (Redis):** caché compartido entre workers, TTL de horas-días, key = `hash(sha256(bytes))`.
- **L3 (object storage):** resultados persistentes de operaciones caras (descripciones de imagen).

```python
import hashlib, json
from redis import Redis

cache = Redis()

def analizar_imagen_cacheado(image_bytes: bytes) -> dict:
    key = f"vision:v1:{hashlib.sha256(image_bytes).hexdigest()}"
    hit = cache.get(key)
    if hit:
        return json.loads(hit)
    # miss → llamar al modelo
    resultado = llamar_claude_vision(image_bytes)
    cache.setex(key, 7 * 24 * 3600, json.dumps(resultado))  # 7 días
    return resultado
```

Impacto típico en producción: 20-40% cache hit en vision para apps de e-commerce (usuarios revisan los mismos productos). Puede recortar 30% del gasto en API.

### Observabilidad: métricas, logs, traces

Las **métricas RED** (Rate, Errors, Duration) por modalidad son el mínimo. Añade métricas específicas:

| Métrica | Por qué | Herramienta |
|---|---|---|
| `requests_total{modality}` | Volumen por modalidad | Prometheus |
| `latency_ms{modality,p50,p95,p99}` | SLO por modalidad | Prometheus + Grafana |
| `cost_usd{modality,model}` | Spend tracking en vivo | Langfuse, Helicone |
| `cache_hit_ratio{modality}` | Efectividad del caché | Prometheus |
| `tokens_in / tokens_out` | Rendimiento del LLM | OpenTelemetry + Langfuse |
| `tool_calls{tool_name}` | Patrones del agente | Arize Phoenix |
| `safety_blocks{reason}` | Guardrails activados | DataDog |

**Tracing distribuido** con OpenTelemetry: una request de voice agent toca STT, LLM, tool, TTS. Sin trace unificado es imposible encontrar dónde se gastaron 200 ms extra.

### Estrategias de escalado

- **Vertical:** GPU más grande (A100 → H100) para modelos propios. Simple, caro.
- **Horizontal:** más réplicas con autoscaler (HPA en Kubernetes, Fargate, Cloud Run). Default para servicios stateless.
- **Scale-to-zero:** servicios que ven tráfico esporádico (Cloud Run, Modal, Replicate). Cold start de 3-10 s para modelos grandes.
- **Serverless GPU:** Modal, Replicate, RunPod, Baseten. Pagas por segundo de GPU, útil para batch.
- **Edge:** Cloudflare Workers AI, Fastly Compute. Latencia baja para modelos pequeños.

Para **voice agents** la regla es: **mantén los workers calientes** (no scale-to-zero) y haz **region pinning** (usuario en EU → bot en EU) para evitar RTT transatlántico.

### Patrones de resiliencia

**Circuit breaker** para evitar cascadas cuando un proveedor cae:

```python
import time, asyncio
from enum import Enum

class EstadoCB(Enum):
    CERRADO = "cerrado"       # funcionando normal
    ABIERTO = "abierto"       # bloqueando llamadas
    SEMI = "semi_abierto"     # probando recuperación

class CircuitBreaker:
    def __init__(self, umbral_fallos=5, timeout_s=60):
        self.umbral = umbral_fallos
        self.timeout = timeout_s
        self.fallos = 0
        self.estado = EstadoCB.CERRADO
        self.ultimo_fallo = 0

    async def call(self, func, *args, **kwargs):
        if self.estado == EstadoCB.ABIERTO:
            if time.time() - self.ultimo_fallo > self.timeout:
                self.estado = EstadoCB.SEMI
            else:
                raise RuntimeError("Circuit breaker abierto")
        try:
            r = await func(*args, **kwargs)
            if self.estado == EstadoCB.SEMI:
                self.estado = EstadoCB.CERRADO
                self.fallos = 0
            return r
        except Exception:
            self.fallos += 1
            self.ultimo_fallo = time.time()
            if self.fallos >= self.umbral:
                self.estado = EstadoCB.ABIERTO
            raise
```

**Retry con backoff exponencial + jitter** (nunca sin jitter; evita thundering herd):

```python
import random, asyncio

async def retry(func, max_intentos=4, base=1.0):
    for intento in range(max_intentos):
        try:
            return await func()
        except Exception:
            if intento == max_intentos - 1:
                raise
            delay = base * (2 ** intento) + random.uniform(0, 0.5)
            await asyncio.sleep(delay)
```

**Degradación graciosa**: si vision falla, pide al usuario que describa el problema por texto. Si TTS falla, devuelve solo texto. Nunca 500.

### Gestión de costos

| Modelo | Precio aprox (ene 2025) | Caso |
|---|---|---|
| Claude Sonnet 4 (text+vision) | $3 / $15 por 1M tokens | VLM de alta calidad |
| Claude Haiku 3.5 | $0.80 / $4 | Pre-filtro, routing |
| GPT-4o | $2.50 / $10 | Vision + razonamiento |
| GPT-4o-mini | $0.15 / $0.60 | Voice agents económicos |
| Whisper API | $0.006 / minuto | Transcripción |
| ElevenLabs TTS | $0.18 / 1k chars (Turbo) | Voz humana |
| gpt-image-1 | $0.02-0.19 / imagen | Generación |

**Tácticas** para controlar spend:

1. **Model cascading**: Haiku filtra; solo casos ambiguos van a Sonnet.
2. **Image downsizing**: Claude cobra por tiles; cada imagen >1568px se escala; haz tú el resize a 1024px.
3. **Caché agresivo** por hash.
4. **Budget caps por tenant** con shutoff automático.
5. **Daily spend alerts** vía Langfuse / Helicone.

## Ejemplo con código

Orquestador multimodal con FastAPI, caché, circuit breaker, métricas y presupuesto:

```python
import os, hashlib, time, logging, asyncio, json
from fastapi import FastAPI, UploadFile, HTTPException, Depends
from prometheus_client import Counter, Histogram, make_asgi_app
import redis.asyncio as aioredis
import httpx

log = logging.getLogger("orchestrator")
app = FastAPI()
app.mount("/metrics", make_asgi_app())

# Métricas RED
REQS = Counter("mm_requests_total", "requests", ["modality", "status"])
LAT = Histogram("mm_latency_seconds", "latencia", ["modality"])
COST = Counter("mm_cost_usd_total", "spend", ["modality", "model"])

cache = aioredis.from_url("redis://redis:6379")

class Presupuesto:
    def __init__(self, diario=100.0):
        self.diario = diario
        self.gasto = 0.0
        self.fecha = time.strftime("%Y-%m-%d")
    def permite(self, costo):
        hoy = time.strftime("%Y-%m-%d")
        if hoy != self.fecha:
            self.gasto, self.fecha = 0.0, hoy
        return self.gasto + costo <= self.diario
    def registrar(self, costo):
        self.gasto += costo

presup = Presupuesto(diario=float(os.getenv("DAILY_BUDGET", "100")))

async def vision_service(image_bytes: bytes) -> dict:
    key = f"v:{hashlib.sha256(image_bytes).hexdigest()}"
    if (hit := await cache.get(key)):
        REQS.labels("vision", "cache_hit").inc()
        return json.loads(hit)

    costo_est = 0.002
    if not presup.permite(costo_est):
        raise HTTPException(429, "Presupuesto diario agotado")

    t0 = time.time()
    async with httpx.AsyncClient(timeout=30) as cli:
        resp = await cli.post(
            "https://api.anthropic.com/v1/messages",
            headers={"x-api-key": os.environ["ANTHROPIC_KEY"],
                     "anthropic-version": "2023-06-01"},
            json={
                "model": "claude-3-5-sonnet-20241022",
                "max_tokens": 500,
                "messages": [{"role": "user", "content": [
                    {"type": "image", "source": {
                        "type": "base64", "media_type": "image/jpeg",
                        "data": __import__("base64").b64encode(image_bytes).decode()
                    }},
                    {"type": "text", "text": "Describe la imagen en 2 frases."}
                ]}]
            }
        )
    resp.raise_for_status()
    data = resp.json()
    out = {"text": data["content"][0]["text"]}
    LAT.labels("vision").observe(time.time() - t0)
    COST.labels("vision", "claude-sonnet").inc(costo_est)
    REQS.labels("vision", "ok").inc()
    presup.registrar(costo_est)
    await cache.setex(key, 7 * 24 * 3600, json.dumps(out))
    return out

@app.post("/analyze")
async def analyze(file: UploadFile):
    if file.content_type not in ("image/jpeg", "image/png"):
        raise HTTPException(415, "Solo JPG/PNG")
    data = await file.read()
    if len(data) > 10 * 1024 * 1024:
        raise HTTPException(413, "Imagen >10MB")
    try:
        return await vision_service(data)
    except httpx.HTTPError as e:
        REQS.labels("vision", "upstream_error").inc()
        log.exception("upstream fail")
        # degradación: respuesta genérica
        return {"text": "No pude analizar la imagen. Describe tu problema."}

@app.get("/health")
async def health():
    try:
        await cache.ping()
        return {"ok": True, "cache": "ok", "spend_today": presup.gasto}
    except Exception as e:
        raise HTTPException(503, str(e))
```

**Dockerfile mínimo** y healthcheck para Kubernetes:

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]
```

## Errores comunes

- **Timeouts por defecto demasiado largos.** `httpx.AsyncClient()` sin timeout mantiene conexiones colgadas eternamente, agota file descriptors. Siempre fija `timeout=`.
- **No separar colas por prioridad.** Si videos de 30 min comparten cola con análisis de 1 s, los cortos quedan bloqueados. Usa `high`, `medium`, `low` queues.
- **Logs con PII.** Guardar prompts y screenshots en logs es un incumplimiento GDPR/HIPAA común. Redacta antes de loggear (Presidio, redactor propio).
- **Sin rate limit por usuario.** Un cliente abusivo puede quemarte el presupuesto en minutos. Rate limit en gateway por API key.
- **Deploy sin canary.** Un nuevo modelo que devuelve respuestas 10x más largas duplica tu factura. Despliega al 5% primero y mide spend + latencia + calidad.
- **Scale-to-zero en voice agents.** Cold start de 3-8 s mata la UX. Mantén un pool caliente.
- **Ignorar tail latency.** El P99 es lo que percibe el usuario frustrado. SLO sobre P95 y P99, no solo media.
- **No versionar modelos externos.** OpenAI deprecia `gpt-4o-2024-05-13` y tu app rompe silenciosamente. Fija el `model=` exacto y versiona.
- **Monitorear solo infraestructura, no calidad semántica.** La API responde 200 pero el modelo alucina. Añade evaluación continua con dataset golden y LLM-as-judge (Langfuse, Arize).
- **No tener plan de rollback.** Si el modelo nuevo da peores respuestas, debes poder revertir en minutos. Blue-green o feature flags por tenant.

## Resumen

- Producción multimodal = **microservicios por modalidad** + **API gateway** + **colas** + **caché** + **observabilidad** + **gestión de costos**.
- Patrones de resiliencia **obligatorios**: circuit breaker, retry con jitter, degradación graciosa, health checks.
- Observa **RED por modalidad** (Rate/Errors/Duration) más **tokens**, **cost**, **cache hit** y **safety blocks**; usa OpenTelemetry para traces end-to-end.
- Decide sync vs async con la regla **>5 s → async con cola**; en voice usa WebRTC con workers calientes y region pinning.
- **Caché por hash** de contenido recorta 20-40% de spend en apps con tráfico repetido.
- **Costos** se controlan con model cascading, image downsizing, caché, budget caps y alertas.
- Despliega con **canary / blue-green** y feature flags; versiona modelos y mantén rollback <5 min.
- La parte más subestimada: **evaluación continua de calidad semántica**, no basta con uptime.
