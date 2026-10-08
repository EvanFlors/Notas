# Caching en Sistemas de IA

## ¿Qué es?

**Caching** es almacenar el resultado de una operación costosa (consulta a BD, feature computation, embedding, predicción de un LLM) en memoria rápida para reutilizarlo cuando se vuelva a pedir el mismo input. En sistemas de IA, un cache bien diseñado puede reducir latencia 10-100× y recortar la factura de GPU a la mitad.

![Multi-level caching architecture](https://hrcdn.net/ai-engineering/module-7/light/aiops-lesson02-caching-layers.svg)

Hay seis tipos relevantes para pipelines de ML/LLM:

| Tipo | Qué guarda | Costo evitado |
|---|---|---|
| **Feature cache** | Features computados por usuario/entidad | Queries a BD, agregaciones |
| **Prediction cache** | Output del modelo para un input | Forward pass completo |
| **Embedding cache** | Vectores de items/queries | Inferencia del encoder |
| **KV-cache (LLM)** | Keys/Values del attention por tokens de prompt | Re-encoding del prefijo |
| **Prompt / prefix cache** | Prompts enteros frecuentes (system prompts, few-shot) | Prefill de miles de tokens |
| **Model cache** | Pesos cargados en VRAM | Carga desde disco/S3 (segundos) |
| **Intermediate cache** | Outputs de etapas de un pipeline | Recomputar pasos intermedios |
| **Negative cache** | Resultados "no existe" | Queries repetidas a BD inexistente |

## ¿Por qué importa?

La ley de Pareto aplica brutal en inferencia: típicamente **20% de los inputs generan 80% del tráfico**. Un top-100 de productos, de queries, de prompts de usuario. Si cada uno cuesta 100ms de GPU y lo cacheas, estás regalando throughput gratis.

Ejemplo numérico realista: servicio a 10,000 req/s, 40% de inputs son repetidos, cada predicción cuesta 5ms de GPU.

```
Requests cacheadas/día = 10,000 × 0.40 × 86,400 = 345.6 M
GPU-time ahorrada     = 345.6M × 5ms = 1,728,000 s = 480 GPU-horas/día
```

A $3/h de A100, eso es **$1,440/día ahorrados** solo por tener un Redis.

Para LLMs el ahorro es aún mayor por el **prefill**: procesar un prompt de 4000 tokens con Llama-70B puede costar 2-3 segundos. Si tu system prompt es idéntico en todas las requests, cachear su KV-cache (prefix caching de vLLM) ahorra ese costo en cada request.

## ¿Cómo funciona?

### Niveles de cache (multi-level)

```
L1: In-process (lru_cache, caffeine)   ─► ns, por pod, chico
L2: Local al nodo (sidecar Redis)      ─► 100µs, por nodo
L3: Distribuido (Redis Cluster)        ─► 1-2ms, compartido
L4: CDN / edge                         ─► 10ms, geo-distribuido
L5: Materialized view (Postgres)       ─► 10-50ms, persistente
```

### Estrategias de invalidación

| Estrategia | Cómo | Pros | Contras |
|---|---|---|---|
| **TTL fijo** | Expira tras N segundos | Simple | Compromiso ciego freshness/hit-rate |
| **TTL adaptativo** | TTL variable por volatilidad del dato | Mejor hit rate | Más código |
| **Event-based** | Invalida al cambiar la fuente | Freshness máxima | Requiere bus de eventos |
| **Version-based** | Guardas `(data, version)`; comparas | Precisión | Lecturas más caras |
| **Lazy** | Marca stale, recomputa al próximo hit | Reparte carga | Breve ventana de datos viejos |
| **Write-through** | Escribe cache + BD juntos | Siempre fresco | Writes más lentos |
| **Write-behind** | Escribe cache, flushea a BD async | Writes rapidísimos | Riesgo de pérdida |

### Patrones de acceso

**Cache-aside (lazy loading):** el app chequea cache; si miss, lee BD, guarda en cache, devuelve.

```python
def get(key):
    if (v := cache.get(key)) is not None:
        return v
    v = db.get(key)
    cache.set(key, v, ex=60)
    return v
```

**Read-through:** la biblioteca de cache abstrae la BD. El app siempre pide al cache.

**Refresh-ahead:** antes de que expire, un worker lo refresca proactivamente. Útil para datos "siempre consultados".

### Cache de prefijos para LLMs (prefix caching)

Un prompt típico tiene estructura:
```
[SYSTEM: Eres un asistente...]  ← mismo en todas las requests
[FEW-SHOT examples...]           ← mismo
[USER: {query variable}]         ← cambia
```

Los primeros ~3000 tokens son idénticos. **Prefix caching** (vLLM, Together, Anthropic) detecta prefijos compartidos y reusa su KV-cache: la request paga solo el prefill de los tokens nuevos. Ahorro típico 60-80% del costo de prefill.

### Semantic cache (para LLMs)

Dos queries textualmente distintas pero semánticamente iguales (`"¿capital de Francia?"` vs `"dime la capital francesa"`) comparten respuesta. Un **semantic cache** embebe la query, busca vecinos en un vector store, y si el coseno supera 0.95 devuelve la respuesta cacheada. Herramientas: GPTCache, Redis Vector Search.

## Ejemplo con código

### Cache multinivel con Redis + in-process

```python
import hashlib, json, time
from functools import lru_cache
import redis

r = redis.Redis(host="redis-cluster", decode_responses=True)

def key_for(payload: dict) -> str:
    raw = json.dumps(payload, sort_keys=True).encode()
    return "pred:" + hashlib.sha256(raw).hexdigest()[:16]

@lru_cache(maxsize=10_000)
def _l1_get(k: str) -> str | None:
    """L1 in-process: solo para TTL ultra-corto. Aqui simulado."""
    return None  # el real seria un dict con expiracion

def cached_predict(model, payload: dict, ttl: int = 300):
    k = key_for(payload)

    # L1
    if (v := _l1_get(k)) is not None:
        return json.loads(v)

    # L2 distribuido
    if (v := r.get(k)) is not None:
        return json.loads(v)

    # Miss: inferencia real
    start = time.perf_counter()
    pred = model.predict(payload)
    latency_ms = (time.perf_counter() - start) * 1000

    # Guardar con TTL + metricas
    r.set(k, json.dumps(pred), ex=ttl)
    r.incrbyfloat("stats:miss_time_ms", latency_ms)
    return pred
```

### Cache-aside con invalidación por evento (Kafka)

```python
from kafka import KafkaConsumer

def listen_invalidations():
    """Al recibir evento de actualizacion, borra la entrada del cache."""
    consumer = KafkaConsumer(
        "entity-updates",
        group_id="cache-invalidator",
        value_deserializer=lambda m: json.loads(m.decode()),
    )
    for msg in consumer:
        entity_id = msg.value["id"]
        for prefix in ("user:", "features:", "embeddings:"):
            r.delete(f"{prefix}{entity_id}")
```

### Prefix caching con vLLM

```python
from vllm import LLM, SamplingParams

llm = LLM(
    model="meta-llama/Meta-Llama-3-8B-Instruct",
    enable_prefix_caching=True,   # KV-cache compartido entre prompts
    gpu_memory_utilization=0.9,
)

SYSTEM = "Eres un asistente que responde en espanol neutro. " * 100  # ~1000 tokens

# Las 1000 queries comparten SYSTEM: solo la primera paga el prefill completo.
# Las siguientes reusan los KV cacheados y pagan solo tokens nuevos.
prompts = [f"{SYSTEM}\nUsuario: pregunta {i}" for i in range(1000)]
outputs = llm.generate(prompts, SamplingParams(max_tokens=128))
```

### Semantic cache con embeddings

```python
import numpy as np
from sentence_transformers import SentenceTransformer
import redis
from redis.commands.search.field import VectorField, TextField
from redis.commands.search.query import Query

encoder = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")
r = redis.Redis()

# Indice vectorial (una sola vez)
r.ft("semcache").create_index([
    VectorField("vec", "HNSW", {"TYPE": "FLOAT32", "DIM": 384, "DISTANCE_METRIC": "COSINE"}),
    TextField("response"),
])

THRESHOLD = 0.05   # coseno distance <= 0.05  ≈ similitud >= 0.95

def semantic_cached_llm(query: str, llm_fn):
    emb = encoder.encode(query).astype(np.float32).tobytes()
    q = (
        Query("*=>[KNN 1 @vec $v AS score]")
        .return_fields("response", "score")
        .dialect(2)
    )
    hits = r.ft("semcache").search(q, query_params={"v": emb}).docs
    if hits and float(hits[0].score) < THRESHOLD:
        return hits[0].response                     # cache hit semantico

    # Miss: llama al LLM y guarda
    resp = llm_fn(query)
    r.hset(f"sem:{hash(query)}", mapping={"vec": emb, "response": resp})
    return resp
```

### Monitoreo de hit rate

```python
# metrics.py (expuesto via Prometheus)
from prometheus_client import Counter, Histogram

HITS   = Counter("cache_hits_total", "Cache hits", ["layer"])
MISSES = Counter("cache_misses_total", "Cache misses", ["layer"])
LAT    = Histogram("cache_lookup_seconds", "Lookup latency", ["layer"])

def observe(layer: str, hit: bool, dt: float):
    (HITS if hit else MISSES).labels(layer).inc()
    LAT.labels(layer).observe(dt)
# hit_rate = sum(rate(cache_hits_total[5m])) / sum(rate(cache_hits_total[5m]) + rate(cache_misses_total[5m]))
```

## Errores comunes

- **Cachear datos que cambian en segundos con TTL de minutos.** Sirves datos stale a usuarios. Usa event-based invalidation para datos críticos.
- **TTL demasiado agresivo.** Hit rate <20% → el cache cuesta más de lo que ahorra (CPU de serialización, red). Mide siempre.
- **No ponerle límite de memoria al Redis.** `maxmemory` sin configurar + política `noeviction` = OOM y servicio caído. Usa `allkeys-lru` o `allkeys-lfu`.
- **Thundering herd en el miss.** 1000 requests simultáneas al mismo key que expiró → 1000 inferencias duplicadas. Soluciones: *single-flight* (una request computa, el resto espera), lock distribuido, o pre-refresh.
- **Guardar objetos no serializables.** NumPy arrays, pandas DataFrames entran crudos y revientan al deserializar. Usa `pickle`, `msgpack` o `orjson`.
- **No invalidar al re-entrenar modelo.** Cambiaste el modelo v2 → el cache sigue sirviendo predicciones del v1. Incluye `model_version` en la cache key.
- **Cachear datos personalizados sin segmentar por usuario.** Un bug famoso: dos usuarios ven el mismo "resumen personal". Incluye `user_id` en la key.
- **Ignorar coste de la red al cache.** Cache remoto a 50ms es más lento que recomputar un modelo pequeño en 20ms. Mide; a veces no cachear es la mejor decisión.
- **Semantic cache con threshold laxo.** Threshold 0.80 devuelve respuestas de queries parecidas pero distintas. Para producción, 0.92-0.97 según el dominio.

## Resumen

- Caching ahorra latencia (10-100×) y GPU (hasta 50-80% del tráfico repetido).
- Tipos clave en IA: feature, prediction, embedding, **KV-cache / prefix**, model, intermediate, negative, **semantic**.
- Estrategias de invalidación: TTL (simple), event-based (fresco), version-based (preciso), lazy (reparte carga).
- Patrones: **cache-aside** por defecto; **read-through** y **write-through** cuando el stack lo soporta.
- Multi-nivel: in-process → Redis distribuido → CDN. Cada nivel captura un patrón distinto de localidad.
- **vLLM prefix caching** es ganancia gratuita para system prompts repetidos; **semantic cache** (GPTCache) amplifica hit rate en LLMs.
- Siempre instrumenta `hit_rate`, `miss_rate`, `eviction_rate`, `p99_lookup_latency`. Si no mides, no sabes si vale la pena.
- Herramientas: Redis, Redis Vector Search, Memcached, GPTCache, Caffeine, CDN (CloudFront, Fastly), vLLM, TGI.
