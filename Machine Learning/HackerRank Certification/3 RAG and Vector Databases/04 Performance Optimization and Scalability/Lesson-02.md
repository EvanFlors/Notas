# Optimización del Sistema: Caching, Batching y Latency Budget

## ¿Qué es?

La **optimización del sistema RAG** es el conjunto de técnicas que atacan la latencia y el throughput del pipeline **completo** (embedding → retrieval → re-ranking → generación), no solo del índice vectorial. Un HNSW con 1 ms de búsqueda es irrelevante si antes gastamos 150 ms generando el embedding de la query, 300 ms haciendo re-ranking con un cross-encoder y 800 ms esperando al LLM.

El framework mental que estructura esta optimización es el **latency budget**: una descomposición explícita del presupuesto total (ej. 500 ms p95) entre cada etapa, con un objetivo medible por componente.

```
┌─────────────────────────────────────────────────────────────┐
│  Latency Budget total: 500 ms (p95)                         │
├─────────────────────────────────────────────────────────────┤
│  Embedding de query .............  60 ms  (12 %)            │
│  Vector search (ANN) ............  15 ms  ( 3 %)            │
│  Re-ranking (cross-encoder) ..... 100 ms  (20 %)            │
│  Prompt assembly ................  10 ms  ( 2 %)            │
│  LLM generación (TTFT) .......... 250 ms  (50 %)            │
│  Serialización + red ............  65 ms  (13 %)            │
└─────────────────────────────────────────────────────────────┘
```

Las palancas que se activan sobre este presupuesto son:

| Palanca | Qué reduce | Trade-off |
|---|---|---|
| **Caching (query / embedding / semántico)** | Latencia de componentes repetitivos | Memoria + staleness |
| **Batching** | Overhead por request en embedding y LLM | ↑ throughput, pero ↑ latencia por lote |
| **Async / parallel** | Tiempo total por paralelismo | Complejidad y manejo de errores |
| **Async indexing** | Latencia de escritura | Freshness: documentos tardan en ser visibles |
| **Cuantización / distilled models** | CPU/GPU por inferencia | Pequeña pérdida de calidad |
| **Sharding + replication** | Latencia por carga, throughput | Infraestructura más compleja |

## ¿Por qué importa?

Una regla empírica de la industria (**Google, Amazon**) dice que cada 100 ms extra de latencia reduce la conversión y el engagement en ~1 %. Para un chatbot de soporte o un search assistant, pasar de 300 ms a 1.5 s percibidos destruye la experiencia: los usuarios cancelan, repiten la consulta o abandonan.

El problema es que un pipeline RAG tiene **múltiples cuellos de botella en serie**: si cada etapa es "razonablemente rápida" (100-200 ms), el total ya está en 1 segundo. Y a diferencia de una API tradicional, los costos no son solo de latencia: cada embedding de OpenAI cuesta ~$0.00002, cada token generado por GPT-4o cuesta ~$0.00001. Un sistema con 10 M queries/mes sin cache gasta **~$2 000 extra** solo por regenerar embeddings idénticos.

### Costos y métricas clave

| Métrica | Qué mide | Objetivo típico (RAG prod) |
|---|---|---|
| **p50 / p95 / p99 latency** | Latencia por percentil | p95 < 500 ms, p99 < 1500 ms |
| **QPS (queries per second)** | Throughput sostenible | 100-10 000 según producto |
| **TTFT (time to first token)** | Latencia hasta el primer token del LLM | < 400 ms |
| **Cache hit rate** | % de queries servidas desde cache | 20-60 % según workload |
| **Cost per query** | USD por query | < $0.005 en RAG masivos |
| **Error rate / timeout rate** | % de requests fallidos | < 0.5 % |

### Cost optimization: dónde se va el dinero

```
Breakdown típico de costo por query RAG (sin cache):
─────────────────────────────────────────────────────
LLM generación (GPT-4o, ~500 tokens out)   85 %
Re-ranking (Cohere Rerank API)              8 %
Embedding de query (OpenAI)                 2 %
Vector DB (Pinecone p1 pod)                 4 %
Infraestructura compute                     1 %
─────────────────────────────────────────────────────
```

El cache golpea el LLM (lo más caro). Un cache hit **ahorra el 85 % del costo** y reduce la latencia en 70-90 %.

## ¿Cómo funciona?

### Caching strategies

Un sistema RAG maduro tiene **múltiples capas** de cache, cada una atacando una redundancia distinta:

```
Query entrante
      │
      ▼
┌─────────────────┐  hit → respuesta completa (10-30 % hits, 100× speedup)
│  Query cache    │
└────────┬────────┘
         │ miss
         ▼
┌─────────────────┐  hit → embedding reutilizado (40-60 % hits, 5-10× speedup)
│ Embedding cache │
└────────┬────────┘
         │ miss
         ▼
┌─────────────────┐  hit → vecinos cacheados (20-40 % hits, 2-5× speedup)
│  Search cache   │
└────────┬────────┘
         │ miss
         ▼
┌─────────────────┐  hit semántico por similitud coseno > 0.95
│ Semantic cache  │ → respuesta de query similar (10-25 % hits)
└────────┬────────┘
         │ miss
         ▼
    Pipeline completo (retrieve → rerank → LLM)
```

| Tipo de cache | Clave | TTL típico | Hit rate | Speedup |
|---|---|---|---|---|
| **Query cache** | hash exacto de la query | 15 min – 1 h | 10-30 % | 10-100× |
| **Embedding cache** | hash de la query normalizada | 1 h – 24 h | 40-60 % | 5-10× |
| **Search cache** | hash del embedding | 30 min | 20-40 % | 2-5× |
| **Semantic cache** | nearest neighbor sobre embeddings de queries | 1 h – 24 h | 10-25 % | 10-50× |
| **Context cache** | hash del set de docs recuperados | 30 min | 15-30 % | 2-3× |

**Semantic caching** es la innovación clave: en lugar de hash exacto, se calcula el embedding de la query y se busca en un índice de **queries previas** con umbral de similitud ≥ 0.95. Captura paráfrasis (`"¿cuál es la política de vacaciones?"` ≈ `"cuántos días de vacaciones tengo"`).

### Batching

Las APIs de embedding y LLM tienen **overhead fijo** por request (TCP handshake, TLS, auth, cold start). Agrupar `N` queries en un solo request amortiza ese costo:

```
Latencia_batch = overhead_fijo + N · costo_marginal
Latencia_1x1   = N · (overhead_fijo + costo_marginal)
```

Con `overhead_fijo = 80 ms` y `costo_marginal = 5 ms`:
- 32 queries en batch: `80 + 32·5 = 240 ms` (**7.5 ms/query**)
- 32 queries secuenciales: `32 · 85 = 2720 ms` (**85 ms/query**) → **11×** más lento

Trade-off: la latencia **individual** sube (una query debe esperar a que se llene el batch), pero el **throughput** del sistema sube drásticamente. Se usa un patrón de **"dynamic batching"**: se junta un batch durante una ventana `t_max` (ej. 10 ms) o hasta `N_max` requests.

### Async indexing

En lugar de bloquear el write hasta que el vector esté indexado y buscable (`sync indexing`), se encola el documento y se devuelve `202 Accepted`. Un worker separado hace embedding + insert.

```
POST /docs → cola Kafka → worker embedder → insert HNSW → disponible en ~2-30 s
```

Trade-off: **freshness**. Un doc insertado no es inmediatamente visible en búsqueda. Para producto es aceptable; para contenido crítico (ej. corrección de precio) requiere refresh forzado o lectura "read-your-writes".

### Sharding

Partir el índice horizontalmente por hash o rango. Cada shard es un índice independiente; una query se envía a **todos** los shards en paralelo (scatter) y los top-k se combinan (gather).

```
             ┌─ shard 0 (0-33 %)
query ─┬────→│─ shard 1 (33-66 %) ──→ merge top-k → respuesta
       │     └─ shard 2 (66-100 %)
       │
       └ latencia = max(shards) + overhead merge
```

Ventajas: paraleliza carga, cabe en RAM de varios nodos, aisla fallas. Costo: más conexiones, lógica de merge, y el p99 lo manda el shard más lento.

### Replication

Copias idénticas del índice detrás de un balanceador. Multiplica QPS y da alta disponibilidad.

```
                    ┌─ replica A
LB (round-robin) ─┬─│  replica B
                  │ └─ replica C
                  └ failover si cae una
```

### Latency budget: metodología

1. **Medir** cada etapa con tracing (OpenTelemetry, Datadog APM, Langfuse).
2. **Asignar** un budget por etapa con la regla **20/80**: la etapa más cara debe recibir la optimización.
3. **Monitorear** p95/p99, no promedios (los promedios ocultan outliers).
4. **Alertar** cuando una etapa consume >130 % de su budget sostenidamente.

## Ejemplo con código

### 1. Cache de embeddings con Redis

```python
import redis, hashlib, json, numpy as np
from openai import OpenAI

r = redis.Redis(host="localhost", port=6379, decode_responses=False)
client = OpenAI()

def _key(text: str, model: str) -> str:
    h = hashlib.sha256(f"{model}:{text.strip().lower()}".encode()).hexdigest()
    return f"emb:{model}:{h[:24]}"

def get_embedding(text: str, model: str = "text-embedding-3-small", ttl: int = 86_400):
    k = _key(text, model)
    cached = r.get(k)
    if cached is not None:
        return np.frombuffer(cached, dtype="float32")

    # miss → llamar API
    resp = client.embeddings.create(input=text, model=model)
    emb = np.array(resp.data[0].embedding, dtype="float32")
    r.set(k, emb.tobytes(), ex=ttl)
    return emb

# Uso
e1 = get_embedding("¿cuál es la política de vacaciones?")  # miss → ~90 ms + 1 API call
e2 = get_embedding("¿cuál es la política de vacaciones?")  # hit  → ~1 ms, 0 API calls
```

### 2. Semantic cache: hit por paráfrasis

```python
import faiss, numpy as np, time

class SemanticCache:
    """
    Cache por similitud: si una query entrante se parece a una vista
    (coseno >= umbral), devuelve la respuesta cacheada.
    """
    def __init__(self, d: int = 1536, threshold: float = 0.95, ttl: int = 3600):
        self.index = faiss.IndexFlatIP(d)   # inner product (vectores normalizados)
        self.payloads = []                  # [(query, response, timestamp)]
        self.threshold = threshold
        self.ttl = ttl

    @staticmethod
    def _norm(v):
        return v / (np.linalg.norm(v) + 1e-12)

    def lookup(self, q_emb: np.ndarray):
        if self.index.ntotal == 0:
            return None
        q = self._norm(q_emb).astype("float32").reshape(1, -1)
        D, I = self.index.search(q, 1)
        sim = float(D[0, 0])
        idx = int(I[0, 0])
        if sim < self.threshold:
            return None
        query, response, ts = self.payloads[idx]
        if time.time() - ts > self.ttl:
            return None
        return {"response": response, "similarity": sim, "matched_query": query}

    def store(self, query: str, q_emb: np.ndarray, response: str):
        q = self._norm(q_emb).astype("float32").reshape(1, -1)
        self.index.add(q)
        self.payloads.append((query, response, time.time()))

# Uso: la segunda query (paráfrasis) hace hit sin llegar al LLM
cache = SemanticCache(d=1536, threshold=0.95)
# ... embed + lookup / store en el pipeline
```

Herramientas listas para producción: **GPTCache** (Zilliz), **Redis Vector Search**, **LangChain `SemanticCache`**.

### 3. Dynamic batching de embeddings

```python
import asyncio
from collections import deque

class EmbeddingBatcher:
    def __init__(self, client, model="text-embedding-3-small",
                 max_batch=64, max_wait_ms=10):
        self.client = client
        self.model = model
        self.max_batch = max_batch
        self.max_wait = max_wait_ms / 1000
        self.queue: deque = deque()
        self._task = asyncio.create_task(self._loop())

    async def embed(self, text: str):
        fut = asyncio.get_event_loop().create_future()
        self.queue.append((text, fut))
        return await fut

    async def _loop(self):
        while True:
            if not self.queue:
                await asyncio.sleep(0.001)
                continue
            batch = []
            start = asyncio.get_event_loop().time()
            while (len(batch) < self.max_batch
                   and (asyncio.get_event_loop().time() - start) < self.max_wait):
                if self.queue:
                    batch.append(self.queue.popleft())
                else:
                    await asyncio.sleep(0.001)
            texts = [t for t, _ in batch]
            resp = await self.client.embeddings.create(input=texts, model=self.model)
            for (_, fut), item in zip(batch, resp.data):
                fut.set_result(item.embedding)
```

### 4. Medir el latency budget con tracing

```python
import time, contextlib

class Budget:
    def __init__(self):
        self.spans = {}

    @contextlib.contextmanager
    def span(self, name: str):
        t0 = time.perf_counter()
        try:
            yield
        finally:
            self.spans[name] = (time.perf_counter() - t0) * 1000

    def report(self, total_budget_ms=500):
        total = sum(self.spans.values())
        print(f"{'etapa':<22} {'ms':>8} {'%':>6}  budget")
        print("-" * 55)
        for name, ms in sorted(self.spans.items(), key=lambda x: -x[1]):
            pct = 100 * ms / total
            print(f"{name:<22} {ms:>8.1f} {pct:>5.1f}%")
        status = "OK" if total < total_budget_ms else "OVER BUDGET"
        print(f"\nTOTAL: {total:.1f} ms   budget: {total_budget_ms} ms   {status}")

# Uso en el pipeline
b = Budget()
with b.span("embed_query"):     q_emb = get_embedding(query)
with b.span("vector_search"):   hits = index.search(q_emb, k=20)
with b.span("rerank"):          hits = reranker.rerank(query, hits)
with b.span("llm_generate"):    ans = llm.generate(prompt(query, hits))
b.report(total_budget_ms=500)
```

### 5. Async indexing con cola

```python
import asyncio
from asyncio import Queue

write_queue: Queue = Queue(maxsize=10_000)

async def api_upsert_doc(doc):          # endpoint HTTP: no bloquea
    await write_queue.put(doc)          # devuelve 202
    return {"status": "queued"}

async def indexer_worker(index, embedder, batch_size=32):
    while True:
        batch = []
        try:
            batch.append(await asyncio.wait_for(write_queue.get(), timeout=0.1))
        except asyncio.TimeoutError:
            continue
        while len(batch) < batch_size and not write_queue.empty():
            batch.append(write_queue.get_nowait())
        texts = [d["text"] for d in batch]
        embs = await embedder.embed_batch(texts)
        index.add_items(embs, ids=[d["id"] for d in batch])
```

## Errores comunes

- **Optimizar sin medir.** Cambiar `efSearch` o añadir cache antes de instrumentar con tracing es apostar a ciegas. Siempre: medir → identificar bottleneck → optimizar → re-medir.
- **Promediar en vez de usar percentiles.** La p50 puede ser 100 ms y la p99 ser 3 s por culpa de un shard lento o un cold start. Los usuarios sufren la p99.
- **No cachear embeddings regenerados.** El mismo texto se embebe docenas de veces (queries repetidas, documentos reindexados). Un cache de embeddings con TTL de 1 hora ahorra 40-60 % de llamadas y dólares.
- **TTL demasiado largo** → respuestas stale después de updates del knowledge base. TTL demasiado corto → hit rate colapsa. Alinear TTL con la frecuencia de cambio de los documentos.
- **Umbral del semantic cache demasiado bajo** (`< 0.9`) → devuelves respuestas incorrectas por queries parecidas pero distintas (ej. "política de vacaciones" vs. "política de despidos"). Mínimo recomendado 0.95 y auditar false positives.
- **Batching sin ventana máxima** → la primera request espera "indefinidamente" a que se llene el batch. Siempre `max_wait_ms` como fallback.
- **Scaling horizontal antes de optimizar vertical.** Lanzar 10 réplicas de un servicio ineficiente solo paga 10× el bill en vez de arreglar el bug. Primero perfilar, luego replicar.
- **Async indexing sin SLA de freshness.** Si no monitoreas el lag de la cola, un pico de writes puede dejar documentos invisibles durante horas. Métrica obligatoria: `queue_depth` y `oldest_message_age`.
- **No warmear caches post-deploy.** Al reiniciar un servicio, el hit rate es 0 % y los p99 se disparan. Hacer **cache warming** con las top-N queries históricas antes de recibir tráfico real.
- **Cache invalidation compleja.** Intentar invalidar entradas específicas cuando cambian documentos lleva a bugs sutiles. Preferir TTL + hashing versionado (`emb:v3:...`) y purgar por prefijo cuando cambie el modelo.
- **No shardear cuando el dataset crece.** Un único nodo HNSW con 50 M vectores satura RAM y satura CPU en reindexaciones. Shardear por `hash(doc_id)` o por tenant.
- **Confundir re-ranking lento con problema de retrieval.** Si el bottleneck es el cross-encoder (100-300 ms), optimizar el ANN de 5 ms a 2 ms no mueve la aguja. Atacar primero la etapa dominante.

## Resumen

- La optimización RAG se piensa como un **latency budget**: descomponer el p95 total en el gasto por etapa y atacar al dominante.
- El **caching multi-nivel** (query, embedding, search, semantic, context) ataca redundancias distintas: hit rates combinados reducen latencia 50-80 % y costo 60-90 %.
- El **semantic cache** captura paráfrasis mediante embeddings y similitud coseno con umbral alto (≥ 0.95); herramientas como GPTCache lo implementan listo.
- El **batching dinámico** amortiza overhead fijo de APIs: trade-off entre latencia individual (↑) y throughput (↑↑); siempre con `max_wait_ms`.
- **Async indexing** desacopla writes del pipeline de search: alta ingestión al costo de freshness; monitorear lag de la cola.
- **Sharding** paraleliza para datasets grandes; **replication** multiplica QPS y da HA. El p99 lo dicta el shard/replica más lento.
- Métricas obligatorias: **p50/p95/p99 latency**, **QPS**, **TTFT**, **cache hit rate**, **cost per query**, **error rate**.
- Herramientas: **Redis** para caching, **GPTCache / LangChain SemanticCache** para semántico, **OpenTelemetry / Langfuse** para tracing, **Milvus/Qdrant/Pinecone** para sharding y replication nativos.
- Regla de oro: **profile first, optimize second**. Nunca optimizar sin medir ni percentiles. Y siempre warmear caches post-deploy.
