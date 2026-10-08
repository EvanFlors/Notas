# Re-ranking: refinando los candidatos recuperados

## ¿Qué es?

**Re-ranking** es una segunda etapa que toma los `k` candidatos devueltos por un retriever rápido (dense, sparse o hybrid) y los **re-ordena** usando un modelo más preciso pero más costoso. Es el patrón canónico de IR moderno:

```
Query ─► Retriever (rápido, top_k=50) ─► Re-ranker (lento, top_n=5) ─► LLM
         bi-encoder / BM25               cross-encoder
```

El retriever optimiza **recall** ("¿está la respuesta entre los 50?"), el re-ranker optimiza **precision** ("¿los 5 primeros son los mejores?").

### Bi-encoder vs cross-encoder

| Arquitectura | Cómo compara query y doc | Latencia | Precisión |
|---|---|---|---|
| **Bi-encoder** (retriever) | Codifica query y doc por separado, compara con cosine | ~1 ms sobre millones de docs (ANN) | Media |
| **Cross-encoder** (re-ranker) | Pasa `[query, doc]` juntos por el transformer y produce un score escalar | ~10-50 ms por par | Alta |

El cross-encoder puede atender a cada token de la query contra cada token del documento (full attention), lo que captura relaciones imposibles para un bi-encoder.

## ¿Por qué importa?

Añadir un re-ranker suele subir el **NDCG@10** entre 10 y 30 puntos sobre un retriever puro, sin cambiar nada más del pipeline. Es la **mejora individual con mejor ROI** en RAG moderno.

- **Mitiga falsos positivos del dense retrieval**: documentos que son semánticamente parecidos pero no responden la pregunta.
- **Permite usar `top_k` alto en el retriever** (50-100) sin saturar al LLM: el re-ranker filtra.
- **Es intercambiable**: puedes mejorar el pipeline cambiando solo el modelo de rerank, sin re-indexar.

### Contexto histórico

- **2019 — MonoBERT**: Nogueira & Cho muestran que un BERT cross-encoder re-rankea pasajes mejor que BM25.
- **2020 — ColBERT**: Khattab & Zaharia introducen *late interaction*, un punto medio entre bi- y cross-encoder.
- **2023 — Cohere Rerank v2** se vuelve el estándar comercial multilingüe.
- **2023 — bge-reranker** (BAAI) abre el ecosistema open source con calidad comparable.
- **2024 — Jina Reranker v2** y modelos nativamente multilingües dominan MTEB-Rerank.

## ¿Cómo funciona?

### Cross-encoder: la arquitectura

Dado `(q, d)`, el cross-encoder construye la entrada:

```
[CLS] query_tokens [SEP] document_tokens [SEP]
```

y pasa esto por un transformer. El vector `[CLS]` final alimenta una cabeza lineal que produce un **score escalar de relevancia**.

Como la query se vuelve a procesar junto con cada documento, no se puede pre-calcular → latencia proporcional a `k`. Por eso solo se re-rankean 10-100 candidatos, no millones.

### Comparativa de re-rankers populares (2026)

| Modelo | Tipo | Multilingüe | Context length | Latencia aprox. (CPU/GPU) | Licencia |
|---|---|---|---|---|---|
| **Cohere Rerank 3** | API comercial | Sí (100+ idiomas) | 4096 | ~100 ms / 1000 docs vía API | Comercial |
| **bge-reranker-v2-m3** (BAAI) | Open source | Sí | 8192 | ~20 ms/par (GPU) | MIT |
| **bge-reranker-large** | Open source | Inglés principalmente | 512 | ~15 ms/par (GPU) | MIT |
| **jina-reranker-v2-base-multilingual** | API + open | Sí | 1024 | ~API | Apache 2.0 |
| **mxbai-rerank-large-v1** | Open source | Inglés | 512 | ~15 ms/par (GPU) | Apache 2.0 |
| **ms-marco-MiniLM-L-6-v2** | Open source (clásico) | Inglés | 512 | ~2 ms/par (CPU) | Apache 2.0 |
| **ColBERTv2** | Late interaction | Inglés | 300 | Rápido (pre-computa) | MIT |

### Elección práctica

- **Prototipo rápido / local**: `cross-encoder/ms-marco-MiniLM-L-6-v2` (22 MB, CPU-friendly).
- **Producción multilingüe**: Cohere Rerank 3 (API gestionada) o `bge-reranker-v2-m3` (self-hosted).
- **Latencia extrema (<50 ms)**: ColBERT, que pre-computa representaciones.

### Flujo típico de dos etapas

```
1. Dense/Hybrid retrieve top-50     → 10 ms
2. Cross-encoder rerank top-50 → 5  → 150 ms
3. LLM genera con 5 chunks           → 1500 ms
                                     --------
                             Total:    1660 ms
```

## Ejemplo con código

### Cross-encoder local con `sentence-transformers`

```python
# pip install sentence-transformers
from sentence_transformers import CrossEncoder

# Modelo ligero entrenado en MS MARCO (clásico, CPU-friendly)
reranker = CrossEncoder("cross-encoder/ms-marco-MiniLM-L-6-v2")

query = "¿cómo cambio mi contraseña?"
candidates = [
    "Política de reembolsos en 30 días.",
    "Para reiniciar tu contraseña ve a Ajustes > Seguridad.",
    "Nuestro horario de atención es de 9 a 18 h.",
    "Si olvidaste tu clave usa el enlace 'Recuperar acceso'.",
    "La API expone el endpoint /auth/v2/token.",
]

# El cross-encoder recibe pares (query, doc)
pairs = [(query, doc) for doc in candidates]
scores = reranker.predict(pairs)

reranked = sorted(zip(scores, candidates), key=lambda x: -x[0])
for s, d in reranked:
    print(f"{s:+.3f}  {d}")
```

### Pipeline completo: BM25 + dense + cross-encoder rerank

```python
from rank_bm25 import BM25Okapi
from sentence_transformers import SentenceTransformer, CrossEncoder
import numpy as np

docs = [...]  # corpus grande
bi_encoder   = SentenceTransformer("intfloat/multilingual-e5-base")
cross_encoder = CrossEncoder("BAAI/bge-reranker-v2-m3")

# ---------- INDEXACIÓN (offline) ----------
tokenized = [d.lower().split() for d in docs]
bm25 = BM25Okapi(tokenized)
doc_emb = bi_encoder.encode([f"passage: {d}" for d in docs],
                            normalize_embeddings=True)

# ---------- CONSULTA (online) ----------
def retrieve_and_rerank(query, k_retrieve=50, k_final=5):
    # 1) Sparse: BM25
    bm25_scores = bm25.get_scores(query.lower().split())
    bm25_top = np.argsort(bm25_scores)[-k_retrieve:]

    # 2) Dense
    q_emb = bi_encoder.encode([f"query: {query}"], normalize_embeddings=True)
    dense_scores = (q_emb @ doc_emb.T)[0]
    dense_top = np.argsort(dense_scores)[-k_retrieve:]

    # 3) Unión de candidatos (RRF simplificado)
    candidates = list(set(bm25_top) | set(dense_top))

    # 4) Rerank con cross-encoder
    pairs = [(query, docs[i]) for i in candidates]
    rerank_scores = cross_encoder.predict(pairs)

    best = sorted(zip(rerank_scores, candidates), key=lambda x: -x[0])[:k_final]
    return [(float(s), docs[i]) for s, i in best]

for score, doc in retrieve_and_rerank("endpoint de autenticación"):
    print(f"{score:+.2f}  {doc}")
```

### Cohere Rerank (API gestionada)

```python
# pip install cohere
import cohere

co = cohere.Client(api_key="...")

response = co.rerank(
    model="rerank-multilingual-v3.0",
    query="¿cómo integro OAuth2?",
    documents=candidates,     # lista de strings o dicts con 'text'
    top_n=5,
    return_documents=True,
)

for r in response.results:
    print(f"{r.relevance_score:.3f}  {r.document.text}")
```

### ColBERT (late interaction) con RAGatouille

```python
# pip install ragatouille
from ragatouille import RAGPretrainedModel

RAG = RAGPretrainedModel.from_pretrained("colbert-ir/colbertv2.0")
RAG.index(collection=docs, index_name="mi_corpus")

results = RAG.search(query="endpoint de autenticación", k=5)
for r in results:
    print(r["score"], r["content"][:120])
```

## Errores comunes

- **Re-rankear demasiados candidatos.** Cada par cuesta 10-50 ms; con `k=500` tu latencia se dispara. Mantén `k_retrieve ≤ 100`.
- **Re-rankear demasiado pocos.** Si pasas solo 5 candidatos al reranker, no puede corregir errores del retriever: el documento correcto podría no estar entre esos 5. Patrón habitual: 20-50 → 3-10.
- **Truncar documentos largos sin estrategia.** Los cross-encoders tienen límite de tokens (512 clásico, 8192 para `bge-reranker-v2-m3`). Si truncas por la mitad, la respuesta puede quedar cortada. Usa chunks acordes al modelo.
- **No normalizar los scores del reranker.** Son *logits*, no probabilidades. Convertir con sigmoid si necesitas umbral: `score = 1/(1+exp(-logit))`.
- **Usar modelo monolingüe para corpus multilingüe.** `ms-marco-MiniLM` fue entrenado en inglés; con español degrada notablemente. Usa `bge-reranker-v2-m3`, Cohere multilingual o Jina multilingual.
- **Mezclar scores de retriever y reranker.** No son comparables. Usa el score del reranker como ranking final; el del retriever solo para filtrar candidatos.
- **No cachear.** Si la misma query se repite (dashboards, autocompletado), cachea los resultados del rerank: ahorra latencia y coste.
- **Omitir el reranker "porque todavía responde bien".** En producción, la diferencia entre `NDCG@10 = 0.65` y `0.80` se traduce en satisfacción del usuario y menos alucinaciones del LLM.

## Resumen

- **Re-ranking** es la segunda etapa que reordena los candidatos del retriever con un modelo más caro y más preciso.
- Los **cross-encoders** procesan `[query, doc]` juntos → mucha más precisión que los bi-encoders a costa de latencia.
- Patrón estándar: **retrieve top-50 → rerank → top-5 al LLM**.
- Modelos de referencia 2026: **Cohere Rerank 3** (API), **bge-reranker-v2-m3** (open source multilingüe), **Jina Reranker v2**, **ColBERTv2** (late interaction).
- Añadir un reranker suele subir **10-30 puntos de NDCG@10** sin re-indexar nada: la mejora de mayor ROI en RAG.
- Cuidado con límites de tokens, idioma del modelo, tamaño de `k_retrieve` y normalización de scores.
- En la Lección 3 veremos cómo mejorar la **consulta** misma (HyDE, multi-query, MMR, metadata filtering).
