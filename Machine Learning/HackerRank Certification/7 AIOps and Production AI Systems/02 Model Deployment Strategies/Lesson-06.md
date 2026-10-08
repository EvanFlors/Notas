# Real-World Scenario: Multi-Model API Gateway

## ¿Qué es?

Un **API gateway multi-modelo** es un servicio que sienta frente a múltiples servicios de ML y expone una **superficie unificada**: una sola URL, un solo esquema de autenticación, un solo sistema de rate limiting, un solo lugar de métricas y logs. Internamente enruta cada request al microservicio de modelo correcto.

### Arquitectura por capas

```
                 ┌──────────────────────────────────┐
Clientes  ──────▶│   1. TLS termination (ingress)   │
                 ├──────────────────────────────────┤
                 │   2. AuthN (API key / JWT / mTLS)│
                 ├──────────────────────────────────┤
                 │   3. Rate limiting (Redis)       │
                 ├──────────────────────────────────┤
                 │   4. Request validation          │
                 ├──────────────────────────────────┤
                 │   5. Routing + versioning        │
                 ├──────────────────────────────────┤
                 │   6. Circuit breaker + retries   │
                 ├──────────────────────────────────┤
                 │   7. Observabilidad (metrics,    │
                 │      logs, traces)               │
                 └──────────────┬───────────────────┘
                                │
          ┌─────────────────────┼─────────────────────┐
          ▼                     ▼                     ▼
   sentiment-v1.3        classify-v2.0         summarize-v1.1
   sentiment-v1.4 (canary)                     summarize-v1.2 (canary)
```

Cada capa es una **cross-cutting concern** que no debe duplicarse en cada equipo de modelo. El gateway las resuelve una sola vez.

## ¿Por qué importa?

Sin gateway, cada equipo construye su propio stack:

- 5 equipos → 5 esquemas de auth → clientes sufren.
- 5 implementaciones de rate limiting → inconsistentes, imposibles de auditar.
- 5 dashboards de métricas → ninguna visión unificada.
- 5 formatos de error → clientes necesitan 5 integraciones.
- Rollouts descoordinados → un equipo tumba un servicio que otro depende de.

Con gateway:

- **Clientes integran una vez** y acceden a todos los modelos.
- **Operaciones centralizadas:** una política de rate limit se aplica globalmente.
- **Observabilidad total:** cada request logeado y trazado uniformemente.
- **Progressive rollouts controlados:** gateway enruta a canary via feature flags/weights sin coordinación con equipos de modelo.
- **Security hardening único:** HTTPS, WAF, mTLS a backends, rotación de keys.
- **Multi-tenancy real:** quotas, SLAs y aislamiento por cliente.

OpenAI, Anthropic, Google AI, Replicate y Hugging Face operan arquitecturas análogas: la API pública es un gateway sobre decenas o cientos de modelos backend.

## ¿Cómo funciona?

### Diseño de endpoints

Convención REST versionada:

```
POST /v1/sentiment      {"text": "..."}
POST /v1/classify       {"text": "...", "labels": ["a","b","c"]}
POST /v1/extract        {"text": "..."}
POST /v1/summarize      {"text": "...", "max_tokens": 128}

Headers opcionales:
  Authorization: Bearer <api_key>
  X-Model-Version: 1.3.0           # fija versión
  X-Request-Id: <uuid>             # idempotencia + tracing
  X-Tenant-Id: acme-corp           # multi-tenancy
```

### Autenticación con API keys

```python
# Validación con cache en memoria + fallback a BD
import time, hashlib
from fastapi import Request, HTTPException

_cache: dict[str, dict] = {}
TTL = 300

async def get_client(api_key: str) -> dict:
    hashed = hashlib.sha256(api_key.encode()).hexdigest()
    now = time.time()
    if hashed in _cache and _cache[hashed]["exp"] > now:
        return _cache[hashed]["data"]
    row = await db.fetch_one("SELECT * FROM api_keys WHERE hash=:h AND active", h=hashed)
    if not row:
        raise HTTPException(401, "Invalid API key")
    _cache[hashed] = {"data": dict(row), "exp": now + TTL}
    return dict(row)

async def authenticate(request: Request) -> dict:
    auth = request.headers.get("authorization", "")
    if not auth.startswith("Bearer "):
        raise HTTPException(401, "Missing bearer token")
    return await get_client(auth.removeprefix("Bearer ").strip())
```

### Rate limiting con sliding window + Redis

**Fórmula sliding window log-based:**

```
allowed  ⟺  count_of_requests_in(now - window, now) < limit
```

Implementación con sorted sets en Redis:

```python
import redis.asyncio as redis, time, uuid

rds = redis.Redis(host="redis", decode_responses=True)

async def rate_limit(client_id: str, limit: int = 1000, window_s: int = 60):
    key = f"rl:{client_id}"
    now = time.time()
    cutoff = now - window_s
    pipe = rds.pipeline()
    pipe.zremrangebyscore(key, 0, cutoff)         # purga viejos
    pipe.zcard(key)                                # cuenta actuales
    pipe.zadd(key, {str(uuid.uuid4()): now})       # agrega este request
    pipe.expire(key, window_s + 1)
    _, count, _, _ = await pipe.execute()
    if count >= limit:
        retry = window_s - (now - float(await rds.zrange(key, 0, 0, withscores=True)[0][1]))
        raise HTTPException(429, "Rate limit exceeded",
                            headers={"Retry-After": str(int(retry))})
```

### Routing table + versioning

```python
# routing.py
from dataclasses import dataclass

@dataclass
class Backend:
    url: str
    timeout_s: float = 2.0

ROUTES = {
    "/v1/sentiment": {
        "default": "1.3.0",
        "versions": {
            "1.3.0": Backend("http://sentiment-v130.ml-prod:80"),
            "1.4.0": Backend("http://sentiment-v140.ml-prod:80"),   # canary
        },
        "canary": {"version": "1.4.0", "weight": 0.1},
    },
    "/v1/classify": {
        "default": "2.0.0",
        "versions": {"2.0.0": Backend("http://classify-v200.ml-prod:80")},
    },
    # ...
}

import random
def pick_backend(path: str, header_version: str | None) -> Backend:
    route = ROUTES[path]
    if header_version and header_version in route["versions"]:
        return route["versions"][header_version]
    canary = route.get("canary")
    if canary and random.random() < canary["weight"]:
        return route["versions"][canary["version"]]
    return route["versions"][route["default"]]
```

### Circuit breaker

**Lógica:**

```
state = CLOSED (normal) | OPEN (rechaza todo) | HALF_OPEN (prueba)

CLOSED → OPEN  si  (error_rate > threshold)  AND  (requests_in_window > min_requests)
OPEN   → HALF_OPEN  tras  reset_timeout
HALF_OPEN → CLOSED  si siguiente request OK
HALF_OPEN → OPEN    si siguiente request falla
```

```python
import pybreaker

sentiment_breaker = pybreaker.CircuitBreaker(
    fail_max=10, reset_timeout=30, exclude=[httpx.HTTPStatusError]
)

@sentiment_breaker
async def call_sentiment(client: httpx.AsyncClient, backend: Backend, payload: dict):
    r = await client.post(f"{backend.url}/predict", json=payload, timeout=backend.timeout_s)
    r.raise_for_status()
    return r.json()
```

### Health checks y load balancing

Para múltiples replicas del mismo servicio, el gateway puede:

- **Delegar a Kubernetes Service** (round-robin L4).
- **Hacer client-side LB** con descubrimiento vía DNS SRV o headless Service + lista actualizada.
- **Health probes** cada 10 s a `/health` de cada backend; descartar unhealthy.

```python
# health_checker.py
import httpx, asyncio
healthy: dict[str, set[str]] = {}  # backend_name -> {ip1, ip2}

async def probe(backend_name: str, ips: list[str]):
    async with httpx.AsyncClient(timeout=2) as c:
        results = await asyncio.gather(
            *[c.get(f"http://{ip}:8000/health") for ip in ips],
            return_exceptions=True,
        )
    healthy[backend_name] = {
        ip for ip, r in zip(ips, results)
        if not isinstance(r, Exception) and r.status_code == 200
    }

async def health_loop():
    while True:
        for name, ips in resolve_dns_all().items():
            await probe(name, ips)
        await asyncio.sleep(10)
```

### Observabilidad: Prometheus, structlog, OpenTelemetry

```python
from prometheus_client import Counter, Histogram, make_asgi_app
import structlog, uuid

REQS = Counter("gateway_requests_total", "", ["path", "status", "version", "client"])
LAT = Histogram("gateway_latency_seconds", "", ["path", "version"],
                buckets=[0.01, 0.05, 0.1, 0.25, 0.5, 1, 2, 5])
RL_REJECT = Counter("gateway_rate_limit_rejects_total", "", ["client"])
CB_OPEN = Counter("gateway_circuit_breaker_opens_total", "", ["backend"])

log = structlog.get_logger()
# log.info("request_served", path=..., status=..., latency_ms=..., trace_id=...)
```

Para distributed tracing, propaga W3C trace context:

```python
from opentelemetry import trace
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor

FastAPIInstrumentor.instrument_app(app)
HTTPXClientInstrumentor().instrument()
# Jaeger/Tempo recibe spans con parent-child automáticamente
```

### Tabla comparativa de API gateways

| Gateway | Lenguaje | Mejor para | Rate limit | Circuit breaker | Observabilidad | Hot-reload config |
|---|---|---|---|---|---|---|
| **Kong** | OpenResty (Lua) | Enterprise, plugin-rich | Sí | Sí | Prometheus + logs | Sí |
| **Envoy** | C++ | Service mesh (Istio base) | Sí | Sí | Nativo gRPC | Sí (xDS) |
| **NGINX / NGINX Plus** | C | Simplicidad, performance | Básico (OSS), full (Plus) | Básico | Logs | Reload soft |
| **AWS API Gateway** | Managed | AWS-centric, serverless | Sí | No (via Lambda) | CloudWatch | API calls |
| **Google Apigee** | Managed | Enterprise mgmt, monetización | Sí | Sí | Dashboards | Sí |
| **Kubernetes Gateway API** | Spec sobre impls (Istio, Contour, Kong) | Nativo K8s | Depende impl | Depende impl | Depende impl | Sí |
| **Custom FastAPI** | Python | Lógica ML-específica | Custom | Via pybreaker | Prometheus/OTel | Config reload |
| **Traefik** | Go | Dev-friendly, auto-TLS | Básico | Sí | Prometheus | Sí |

### Fórmulas y umbrales

**Sliding window strict:**

```
allowed  ⟺  len({t : request_at(t) ∧ t ∈ (now - window, now]}) < limit
```

**Circuit breaker:**

```
open  ⟺  (errors_in_window / requests_in_window > threshold) ∧ (requests_in_window > min_requests)
# Típicos: threshold=0.5, min_requests=20, window=10s, reset_timeout=30s
```

**Retry con exponential backoff + jitter:**

```
delay_n = min(cap, base × 2ⁿ) × random(0.5, 1.5)
# base=100ms, cap=5s, n=0..3 (máx 4 intentos)
```

## Ejemplo con código

Gateway completo funcional en FastAPI:

```python
# gateway.py
import asyncio, time, uuid, hashlib
import httpx, pybreaker, redis.asyncio as redis, structlog
from fastapi import FastAPI, Request, HTTPException
from prometheus_client import Counter, Histogram, make_asgi_app
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor

# -------------------- app --------------------
app = FastAPI(title="ML API Gateway", version="1.0.0")
app.mount("/metrics", make_asgi_app())
log = structlog.get_logger()
rds = redis.Redis(host="redis", decode_responses=True)
http = httpx.AsyncClient(timeout=5.0, limits=httpx.Limits(max_connections=500,
                                                           max_keepalive_connections=200))
FastAPIInstrumentor.instrument_app(app)
HTTPXClientInstrumentor().instrument()

# -------------------- metrics --------------------
REQS = Counter("gw_requests_total", "", ["path", "status", "version", "client"])
LAT  = Histogram("gw_latency_seconds", "", ["path", "version"],
                 buckets=[0.01, 0.05, 0.1, 0.25, 0.5, 1, 2, 5])
RL   = Counter("gw_rate_limit_rejects_total", "", ["client"])
CB   = Counter("gw_cb_opens_total", "", ["backend"])

# -------------------- routing --------------------
BACKENDS = {
    "/v1/sentiment": {
        "1.3.0": "http://sentiment-v130.ml-prod",
        "1.4.0": "http://sentiment-v140.ml-prod",
    },
    "/v1/classify":  {"2.0.0": "http://classify-v200.ml-prod"},
    "/v1/extract":   {"1.0.0": "http://extract-v100.ml-prod"},
    "/v1/summarize": {"1.1.0": "http://summarize-v110.ml-prod",
                      "1.2.0": "http://summarize-v120.ml-prod"},
}
DEFAULT_VERSION = {"/v1/sentiment": "1.3.0", "/v1/classify": "2.0.0",
                   "/v1/extract": "1.0.0", "/v1/summarize": "1.1.0"}
CANARY = {"/v1/sentiment": ("1.4.0", 0.10), "/v1/summarize": ("1.2.0", 0.05)}

breakers: dict[str, pybreaker.CircuitBreaker] = {}
def get_breaker(url: str) -> pybreaker.CircuitBreaker:
    if url not in breakers:
        breakers[url] = pybreaker.CircuitBreaker(fail_max=10, reset_timeout=30)
    return breakers[url]

# -------------------- auth --------------------
_key_cache: dict = {}
async def authenticate(request: Request) -> dict:
    auth = request.headers.get("authorization", "")
    if not auth.startswith("Bearer "):
        raise HTTPException(401, "Missing bearer token")
    api_key = auth.removeprefix("Bearer ").strip()
    h = hashlib.sha256(api_key.encode()).hexdigest()
    cached = _key_cache.get(h)
    if cached and cached["exp"] > time.time():
        return cached["data"]
    # Fallback: BD (simulado aquí)
    client = {"id": h[:8], "limit_per_min": 1000, "tenant": "acme"}
    _key_cache[h] = {"data": client, "exp": time.time() + 300}
    return client

# -------------------- rate limit --------------------
async def rate_limit(client_id: str, limit: int, window_s: int = 60):
    key = f"rl:{client_id}"
    now = time.time()
    pipe = rds.pipeline()
    pipe.zremrangebyscore(key, 0, now - window_s)
    pipe.zcard(key)
    pipe.zadd(key, {str(uuid.uuid4()): now})
    pipe.expire(key, window_s + 1)
    _, count, _, _ = await pipe.execute()
    if count >= limit:
        RL.labels(client_id).inc()
        raise HTTPException(429, "Rate limit exceeded")

# -------------------- routing logic --------------------
import random
def choose_version(path: str, header_version: str | None) -> str:
    versions = BACKENDS[path]
    if header_version and header_version in versions:
        return header_version
    canary = CANARY.get(path)
    if canary and random.random() < canary[1]:
        return canary[0]
    return DEFAULT_VERSION[path]

# -------------------- proxy --------------------
async def proxy(backend_url: str, path: str, body: dict, trace_id: str) -> dict:
    breaker = get_breaker(backend_url)
    try:
        @breaker
        async def _call():
            r = await http.post(f"{backend_url}/predict", json=body,
                                headers={"x-request-id": trace_id})
            r.raise_for_status()
            return r.json()
        return await _call()
    except pybreaker.CircuitBreakerError:
        CB.labels(backend_url).inc()
        raise HTTPException(503, f"Backend {backend_url} circuit open")
    except httpx.TimeoutException:
        raise HTTPException(504, "Backend timeout")
    except httpx.HTTPStatusError as e:
        raise HTTPException(e.response.status_code, e.response.text)

# -------------------- endpoints --------------------
@app.post("/v1/{model}")
async def dispatch(model: str, request: Request):
    path = f"/v1/{model}"
    if path not in BACKENDS:
        raise HTTPException(404, f"Unknown model: {model}")

    client = await authenticate(request)
    await rate_limit(client["id"], client["limit_per_min"])

    body = await request.json()
    version = choose_version(path, request.headers.get("x-model-version"))
    trace_id = request.headers.get("x-request-id", str(uuid.uuid4()))

    t0 = time.perf_counter()
    try:
        result = await proxy(BACKENDS[path][version], path, body, trace_id)
        status = 200
    except HTTPException as e:
        status = e.status_code
        raise
    finally:
        elapsed = time.perf_counter() - t0
        LAT.labels(path, version).observe(elapsed)
        REQS.labels(path, status, version, client["id"]).inc()
        log.info("served", path=path, status=status, version=version,
                 client=client["id"], latency_ms=elapsed * 1000, trace_id=trace_id)
    result["_version"] = version
    return result

@app.get("/health")
async def health():
    return {"status": "ok"}
```

Lanzar:

```bash
uvicorn gateway:app --host 0.0.0.0 --port 8080 --workers 4
```

## Errores comunes

- **Rate limiting en memoria sin Redis compartido.** Con N replicas del gateway, cada una tiene su contador → el límite efectivo es N × limit.
- **Sin circuit breaker.** Si un backend se degrada, cada request espera timeout → pool de conexiones se agota → gateway caído.
- **Sin retries con backoff.** Un error 502 transitorio puede resolverse con un retry de 100 ms; sin él, el cliente ve error.
- **Retries sin idempotencia.** Reintentos a endpoints no idempotentes duplican side effects. Headers `Idempotency-Key` o whitelist de métodos seguros.
- **Gateway como SPOF.** Una sola replica → el gateway cae → **todo** cae. Siempre al menos 3 replicas en zonas distintas con autoscaling agresivo.
- **Sin distributed tracing.** Debuggear latencia es imposible sin ver dónde se gastó el tiempo (gateway? red? backend? feature store?).
- **Falta de versioning en path.** `/predict` sin `/v1/` imposibilita breaking changes. Siempre versiona.
- **API keys sin hash en BD.** Si leakea la tabla, todas las keys se comprometen. Guarda SHA-256; compara con hash del input.
- **Sin rotación de keys.** Keys eternas aumentan ventana de exposición. TTL + rotación semestral.
- **Logging del payload completo.** Logs crecen gigante y pueden contener PII. Logea solo size + hash; muestreo del contenido.
- **Timeouts no configurados en cliente.** El cliente httpx sin timeout bloquea el gateway cuando backend está lento.
- **No HTTPS entre gateway y backends.** mTLS interno es best practice (Istio/Linkerd lo dan gratis).
- **Config hardcodeada.** Cambiar un backend requiere redeploy. Usa ConfigMap + hot reload.

## Contexto industrial

- **Kong** (open source + enterprise): usado por GitHub, Expedia, Nasdaq.
- **Envoy** (CNCF, nacido en Lyft): base de Istio, usado por Stripe, Netflix, Pinterest, Lyft, Reddit.
- **AWS API Gateway**: default para startups serverless AWS; integra con Lambda, Cognito, WAF.
- **Google Apigee**: enterprise con monetización, portal developer, analytics.
- **Istio Gateway + Istio Service Mesh**: estándar K8s-nativo; cada microservicio detrás con mTLS + policies.
- **Cloudflare Workers / Fastly Compute@Edge**: gateways edge-native, ejecutan lógica en 300+ POPs.
- **OpenAI, Anthropic, Replicate, Hugging Face**: todos operan API gateways propios encima de serving layers (Triton/vLLM). Rate limiting por tier, kill-switch por abuso, routing a modelos canary.
- **Netflix Zuul 2** y **Spring Cloud Gateway**: gateways JVM muy usados en bancos y telcos.
- **Buoyant Linkerd**: service mesh Rust-based alternativo a Istio, más simple.

Observabilidad típica alrededor del gateway: **Prometheus + Grafana** (metrics), **Loki / Elasticsearch** (logs), **Jaeger / Tempo** (traces), **OpenTelemetry** (instrumentation estándar), **PagerDuty / Opsgenie** (alertas).

## Resumen

- Un **API gateway multi-modelo** centraliza auth, rate limiting, routing, versioning, circuit breaking, retries y observabilidad.
- Arquitectura en **capas**: TLS → auth → rate limit → validation → routing → circuit breaker → observabilidad → backends.
- **Rate limiting distribuido** requiere Redis (o similar) con sliding window; nunca en memoria por replica.
- **Circuit breakers** aíslan fallos de backends y previenen colapsos en cascada.
- **Versioning via header** (`X-Model-Version`) + **routing table** + **canary weights** = rollouts controlados sin coordinación con equipos de modelo.
- **Métricas Prometheus** + **structured logging** + **distributed tracing (OpenTelemetry)** son no-negociables.
- El gateway **ES infraestructura crítica**: HA multi-zona, canary para sus propios updates, runbooks probados.
- Opciones: **Kong, Envoy, NGINX, AWS API Gateway, Apigee, Kubernetes Gateway API, custom FastAPI, Traefik**. Elige según madurez del equipo y stack existente.
- **Security**: HTTPS externo, mTLS interno (Istio/Linkerd), API keys hasheadas con rotación, logging sin PII.
- Trata al gateway como **producto**: documenta la API, mide el DevEx, itera con feedback de los equipos consumidores.
