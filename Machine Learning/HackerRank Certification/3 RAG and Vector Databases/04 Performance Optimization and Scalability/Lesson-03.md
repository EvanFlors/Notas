# Monitoreo y Evaluación en Producción

## ¿Qué es?

El **monitoreo de un sistema RAG en producción** es la práctica de instrumentar, medir y alertar sobre dos planos simultáneos:

1. **Plano técnico:** latencia, throughput, uso de recursos, errores, hit rates.
2. **Plano de calidad:** precision@k, recall@k, tasas de alucinación, satisfacción de usuario, drift del modelo de embeddings.

A diferencia de un microservicio tradicional, donde "200 OK + < 100 ms" basta como señal de salud, un RAG puede devolver respuestas sintácticamente correctas pero **semánticamente incorrectas** (alucinaciones, documentos irrelevantes, contexto obsoleto). Un dashboard que solo mire HTTP 2xx y p95 mentirá: todo parece "verde" mientras los usuarios reciben respuestas malas.

Un sistema completo de monitoreo RAG incluye:

| Capa | Qué mide | Herramientas típicas |
|---|---|---|
| **Infra** | CPU, RAM, disco, red | Prometheus, Datadog, Grafana |
| **APM / Tracing** | Latencia por span, errores | OpenTelemetry, Datadog APM, Jaeger |
| **Métricas RAG** | precision@k, recall@k, hit rates | Langfuse, Arize AI, Phoenix, custom |
| **Evaluación offline** | LLM-as-judge sobre golden set | RAGAS, DeepEval, TruLens |
| **Feedback de usuario** | thumbs up/down, dwell time, reformulaciones | Logging aplicativo, Segment |
| **Alerting** | Umbrales + anomalías | PagerDuty, Opsgenie, Slack |

### Fórmulas base

**Precision@k:** fracción de los `k` resultados devueltos que son relevantes.

```
Precision@k = |retrieved_k ∩ relevant| / k
```

**Recall@k:** fracción de los documentos relevantes totales que fueron devueltos en el top `k`.

```
Recall@k = |retrieved_k ∩ relevant| / |relevant|
```

**MRR (Mean Reciprocal Rank):** promedio del inverso de la posición del primer resultado relevante.

```
MRR = (1/N) · Σᵢ 1 / rank_i
```

**NDCG@k:** ganancia descontada normalizada; penaliza relevantes que aparecen abajo en el ranking.

```
DCG@k  = Σᵢ₌₁ᵏ (relᵢ) / log₂(i + 1)
NDCG@k = DCG@k / IDCG@k
```

**Cache hit rate:**

```
hit_rate = cache_hits / (cache_hits + cache_misses)
```

## ¿Por qué importa?

Un RAG en producción **se degrada silenciosamente** por tres mecanismos:

1. **Knowledge drift:** el knowledge base cambia (se añaden docs, se actualizan políticas), pero el modelo de embeddings sigue viejo o los chunks se vuelven inconsistentes.
2. **Query drift:** los usuarios cambian cómo preguntan (nuevos temas, nuevo vocabulario, idiomas, estacionalidad). Las queries de hoy ya no se parecen a las del golden set de hace 6 meses.
3. **Embedding model drift:** si actualizas el modelo (`text-embedding-ada-002` → `text-embedding-3-small`), los vectores viejos quedan en otro espacio y el recall colapsa.

Sin monitoreo, estos problemas se detectan por **tickets de soporte**: el peor canal posible, porque llega semanas tarde y solo captura la punta del iceberg. Con monitoreo, se detectan en horas vía alertas sobre precision@k, cache hit rate o rating medio.

### Impacto cuantitativo

| Problema no detectado | Costo típico (empresa mediana) |
|---|---|
| p95 sube de 500 ms a 2 s por 1 semana | ~15 % drop en engagement, ~5 % en conversión |
| Recall@10 baja de 0.95 a 0.80 tras actualización de embeddings | ~30 % respuestas incorrectas o incompletas |
| Cache invalidado por bug durante 24 h | 10-50× factura de LLM del día |
| Alucinación no detectada en dominio legal/médico | riesgo regulatorio y reputacional serio |

### Herramientas recomendadas

- **Langfuse** (open source): tracing + evaluación + prompt mgmt enfocado a LLM apps.
- **Arize AI / Phoenix:** observabilidad ML con detección de drift y embedding analysis.
- **RAGAS:** librería Python para métricas automáticas de RAG (faithfulness, context precision, answer relevancy).
- **TruLens:** feedback functions programables.
- **DeepEval:** test suite estilo pytest para LLMs.
- **Prometheus + Grafana:** stack base para métricas numéricas y dashboards.

## ¿Cómo funciona?

### 1. Golden dataset

El punto de partida es un **golden set** de 100-1000 pares `(query, documentos_relevantes_ids, respuesta_ideal)` curado manualmente o semi-automáticamente. Es el ground truth contra el que se calcula recall@k, precision@k, NDCG offline y en cada deploy.

```
golden/
├── eval_set_v3.jsonl       (query, relevant_doc_ids, ideal_answer, category)
├── split_by_category.py
└── reports/
    └── 2026-10-01_eval.json
```

### 2. Métricas online (tracing)

Cada request produce un trace con spans por etapa:

```
request_id = r-abc123
├── span: embed_query          duration=52 ms   cache_hit=False
├── span: vector_search        duration=14 ms   k=20  recall_est=0.96
├── span: rerank               duration=98 ms   model=cohere-rerank-v3
├── span: llm_generate         duration=287 ms  tokens_in=1240 tokens_out=180
└── total: 451 ms              user_rating=null
```

Agregando por ventanas rodantes (5 min, 1 h, 24 h) se calculan p50/p95/p99 por span y por endpoint.

### 3. Feedback loop

Capturar explícito e implícito:

| Tipo | Señal | Interpretación |
|---|---|---|
| **Explícito** | 👍 / 👎, rating 1-5, comentario | Ground truth parcial, bajo volumen (~1-5 % de queries) |
| **Implícito** | copy del texto, click en fuente, reformulación en < 30 s | Alto volumen, ruidoso |
| **Comportamental** | abandono, timeout, descarga de doc fuente | Útil con A/B testing |

Las reformulaciones (`query_t`, `query_{t+15s}` del mismo user_id) son oro: señalan que la respuesta previa no satisfizo.

### 4. Umbrales y alerting

```
Métrica                    Warning           Critical          Ventana
──────────────────────────────────────────────────────────────────────
p95 latency                > 800 ms          > 2000 ms         5 min
error_rate                 > 1 %             > 5 %             5 min
precision@10 (offline)     < 0.85            < 0.75            1 h
cache_hit_rate (query)     < 15 %            < 5 %             15 min
avg_user_rating            < 3.5             < 3.0             1 h
recall_regression          > 5 % drop        > 15 % drop       deploy gate
hallucination_rate         > 3 %             > 10 %            1 h
embedding_drift (KL div)   > 0.1             > 0.3             1 día
```

**Reglas de higiene:**
- Usar **ventanas rodantes** para evitar falsas alarmas por spikes transitorios.
- **Cooldown** entre alertas (10-30 min) para evitar fatiga.
- **Runbook** linkeado en cada alerta: pasos concretos de diagnóstico.
- Separar canales: críticas → PagerDuty; warnings → Slack; info → dashboard.

### 5. Evaluación automática: LLM-as-judge

Para dominios sin golden set exhaustivo, se usa un LLM potente (ej. GPT-4o, Claude) como juez con prompts estructurados:

```
Faithfulness: ¿cada afirmación de la respuesta se puede verificar
              en el contexto recuperado?  → 0.0 a 1.0

Answer relevancy: ¿la respuesta aborda la pregunta?  → 0.0 a 1.0

Context precision: ¿los chunks recuperados son relevantes
                   a la pregunta?  → 0.0 a 1.0
```

RAGAS las implementa en una línea. Calibrar vs. humanos sobre 100-200 ejemplos antes de confiar en estas métricas.

## Ejemplo con código

### 1. Métricas de recall@k y precision@k contra golden set

```python
import json, numpy as np
from statistics import mean

def precision_at_k(retrieved_ids, relevant_ids, k=10):
    top = retrieved_ids[:k]
    return len(set(top) & set(relevant_ids)) / k

def recall_at_k(retrieved_ids, relevant_ids, k=10):
    if not relevant_ids:
        return 0.0
    top = retrieved_ids[:k]
    return len(set(top) & set(relevant_ids)) / len(relevant_ids)

def mrr(retrieved_ids, relevant_ids):
    for i, doc_id in enumerate(retrieved_ids, 1):
        if doc_id in relevant_ids:
            return 1.0 / i
    return 0.0

def ndcg_at_k(retrieved_ids, relevant_ids, k=10):
    gains = [1.0 if d in relevant_ids else 0.0 for d in retrieved_ids[:k]]
    dcg = sum(g / np.log2(i + 2) for i, g in enumerate(gains))
    ideal = sorted(gains, reverse=True)
    idcg = sum(g / np.log2(i + 2) for i, g in enumerate(ideal))
    return dcg / idcg if idcg > 0 else 0.0

# Evaluación sobre el golden set
with open("golden/eval_set_v3.jsonl") as f:
    golden = [json.loads(l) for l in f]

results = {"p@10": [], "r@10": [], "mrr": [], "ndcg@10": []}
for item in golden:
    retrieved = rag_system.retrieve(item["query"], k=20)
    retrieved_ids = [doc.id for doc in retrieved]
    rel = set(item["relevant_doc_ids"])
    results["p@10"].append(precision_at_k(retrieved_ids, rel, 10))
    results["r@10"].append(recall_at_k(retrieved_ids, rel, 10))
    results["mrr"].append(mrr(retrieved_ids, rel))
    results["ndcg@10"].append(ndcg_at_k(retrieved_ids, rel, 10))

print({k: round(mean(v), 3) for k, v in results.items()})
# → {'p@10': 0.78, 'r@10': 0.91, 'mrr': 0.82, 'ndcg@10': 0.86}
```

### 2. Collector de métricas con ventana rodante

```python
import time, statistics
from dataclasses import dataclass, field
from collections import deque
from datetime import datetime, timedelta
from typing import Optional, Dict

@dataclass
class QueryTrace:
    query_id: str
    ts: datetime
    total_ms: float
    retrieve_ms: float
    rerank_ms: float
    llm_ms: float
    k_retrieved: int
    cache_hits: Dict[str, bool]
    user_rating: Optional[int] = None   # 1-5
    error: Optional[str] = None

class MetricsCollector:
    def __init__(self, retention_h: int = 24):
        self.retention = timedelta(hours=retention_h)
        self.traces: deque = deque()

    def record(self, t: QueryTrace):
        self.traces.append(t)
        self._gc()

    def _gc(self):
        cutoff = datetime.utcnow() - self.retention
        while self.traces and self.traces[0].ts < cutoff:
            self.traces.popleft()

    def _ok(self):
        return [t for t in self.traces if t.error is None]

    def summary(self) -> Dict:
        ok = self._ok()
        if not ok:
            return {"error": "no data"}
        lat = [t.total_ms for t in ok]
        ratings = [t.user_rating for t in ok if t.user_rating is not None]
        hits_query = sum(1 for t in ok if t.cache_hits.get("query"))
        hits_emb = sum(1 for t in ok if t.cache_hits.get("embedding"))
        n = len(ok)
        return {
            "n": n,
            "success_rate": n / len(self.traces),
            "p50_ms": statistics.median(lat),
            "p95_ms": statistics.quantiles(lat, n=20)[18] if n >= 20 else None,
            "p99_ms": statistics.quantiles(lat, n=100)[98] if n >= 100 else None,
            "cache_hit_query": hits_query / n,
            "cache_hit_embedding": hits_emb / n,
            "avg_rating": statistics.mean(ratings) if ratings else None,
            "rating_n": len(ratings),
        }
```

### 3. LLM-as-judge con RAGAS

```python
from ragas import evaluate
from ragas.metrics import faithfulness, answer_relevancy, context_precision
from datasets import Dataset

samples = {
    "question":    [t.query for t in traces],
    "answer":      [t.answer for t in traces],
    "contexts":    [[c.text for c in t.contexts] for t in traces],
    "ground_truth":[t.golden_answer for t in traces],   # opcional
}
ds = Dataset.from_dict(samples)

report = evaluate(
    ds,
    metrics=[faithfulness, answer_relevancy, context_precision],
)
print(report)
# faithfulness: 0.87   answer_relevancy: 0.91   context_precision: 0.78
```

### 4. Alerting con umbrales

```python
class AlertManager:
    def __init__(self, cooldown_s: int = 1800):
        self.last_fired: Dict[str, float] = {}
        self.cooldown = cooldown_s

    def check(self, metrics: Dict):
        rules = [
            ("p95_latency_critical", metrics.get("p95_ms", 0) > 2000, "critical"),
            ("p95_latency_warning",  metrics.get("p95_ms", 0) > 800,  "warning"),
            ("low_hit_rate",         metrics.get("cache_hit_query", 1) < 0.05, "warning"),
            ("low_rating",           (metrics.get("avg_rating") or 5) < 3.0,   "critical"),
            ("success_rate_low",     metrics.get("success_rate", 1) < 0.95,    "critical"),
        ]
        now = time.time()
        for name, firing, sev in rules:
            if not firing:
                continue
            if now - self.last_fired.get(name, 0) < self.cooldown:
                continue
            self.notify(name, sev, metrics)
            self.last_fired[name] = now

    def notify(self, name, sev, metrics):
        # integrar con PagerDuty / Slack / Opsgenie
        print(f"[{sev.upper()}] {name}   context={metrics}")
```

### 5. Detección de drift del embedding

```python
import numpy as np
from scipy.stats import entropy

def kl_divergence(p_hist, q_hist, eps=1e-10):
    p = p_hist + eps; q = q_hist + eps
    p /= p.sum(); q /= q.sum()
    return float(entropy(p, q))

def embedding_drift(ref_embs: np.ndarray, cur_embs: np.ndarray, bins: int = 50):
    """
    Mide drift por dimensión promediando la KL divergence entre
    histogramas de embeddings de referencia vs. tráfico actual.
    """
    kls = []
    for d in range(ref_embs.shape[1]):
        lo = min(ref_embs[:, d].min(), cur_embs[:, d].min())
        hi = max(ref_embs[:, d].max(), cur_embs[:, d].max())
        p, _ = np.histogram(ref_embs[:, d], bins=bins, range=(lo, hi))
        q, _ = np.histogram(cur_embs[:, d], bins=bins, range=(lo, hi))
        kls.append(kl_divergence(p.astype(float), q.astype(float)))
    return float(np.mean(kls))

# Umbral típico: > 0.1 warning, > 0.3 critical → retrain / re-embedding
```

## Errores comunes

- **Mirar solo métricas técnicas** (latencia, 2xx). El RAG puede estar devolviendo respuestas malas con 200 OK y p95 óptimo. Siempre acompañar con métricas de calidad.
- **No tener golden set** o tener uno estático y pequeño. Sin ground truth no sabes si un cambio mejora o empeora el sistema. Mantener el golden set vivo y añadir ejemplos reales continuamente.
- **Confiar ciegamente en LLM-as-judge** sin calibrarlo contra humanos. Los jueces LLM tienen sesgos (prefieren respuestas largas, estructura markdown). Validar con muestras humanas antes de alertar sobre ellos.
- **Alertar por el promedio.** La media esconde outliers. Alertar siempre por p95/p99 y tasas (error rate, hallucination rate).
- **No monitorear recall tras updates del índice.** HNSW degrada con deletes; actualizar embeddings cambia el espacio. Correr evaluación offline en el pipeline de deploy como gate.
- **Alert fatigue.** Umbrales demasiado agresivos y sin cooldown → el equipo ignora las alertas. Mejor pocas alertas accionables con runbook claro.
- **No capturar feedback del usuario** o capturarlo sin link al `request_id`. Sin trazabilidad el feedback es inútil.
- **Perder trazabilidad end-to-end.** Un request debe tener `request_id` único propagado desde el frontend hasta la DB vectorial y el LLM. Sin esto, debuggear incidentes es imposible.
- **No separar métricas por segmento** (idioma, categoría, tenant). El promedio global puede estar bien mientras un tenant importante sufre. Dashboards segmentados por `tenant_id` y `category`.
- **No warmear caches ni calentar índices tras deploy.** p99 se dispara durante 10-30 min post-deploy; monitorear "deploy p99" como métrica aparte.
- **Confundir drift de datos con drift de modelo.** Si cambia el patrón de queries (data drift) la métrica cae por razones legítimas; si cambia la relación query↔respuesta (concept drift) hay que re-evaluar los chunks o fine-tunear.
- **No versionar prompts, modelos, índices.** Al debuggear "¿por qué ayer funcionaba?", si no sabes qué versión del prompt + embedding model + index estaba desplegada, estás ciego. Linkar `version` en cada trace.

## Resumen

- Monitorear un RAG requiere **dos planos**: técnico (latencia, errores, hit rates) y de calidad (precision@k, recall@k, faithfulness, satisfacción).
- Las **fórmulas base** son `Precision@k`, `Recall@k`, `MRR` y `NDCG@k`; se calculan contra un **golden set** curado y versionado.
- El **tracing distribuido** (OpenTelemetry, Langfuse) con `request_id` end-to-end es la base de la observabilidad; sin él no se puede debuggear.
- **Métricas en ventana rodante** y por **percentiles (p50/p95/p99)** son obligatorias; los promedios mienten.
- El **feedback de usuario** (explícito, implícito, comportamental) cierra el loop y es la única señal realmente alineada con el valor entregado.
- **LLM-as-judge** (RAGAS, TruLens, DeepEval) escala la evaluación automática, pero debe calibrarse contra humanos.
- El **alerting efectivo** usa warning/critical, cooldowns, runbooks y canales separados; alert fatigue mata equipos.
- Monitorear **drift**: de queries, del knowledge base y del modelo de embeddings. KL divergence es un buen punto de partida.
- Siempre tener un **gate de evaluación offline** en el pipeline de deploy: si recall@10 cae > 5 %, bloquear el deploy.
- Herramientas típicas: **Langfuse / Arize / Phoenix** (RAG-specific), **Prometheus + Grafana** (infra), **RAGAS / DeepEval** (eval), **PagerDuty / Opsgenie** (alerting).
- Regla de oro: lo que no se mide, se degrada. Y en RAG, se degrada en silencio.
