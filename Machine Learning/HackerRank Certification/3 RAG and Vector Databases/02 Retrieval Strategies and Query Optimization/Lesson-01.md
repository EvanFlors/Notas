# Metodologías de Retrieval

## ¿Qué es?

**Retrieval** (recuperación) es el proceso de encontrar, dado una consulta del usuario, los documentos (o *chunks*) más relevantes dentro de una base de conocimiento. Es la "R" de **RAG** (Retrieval-Augmented Generation) y determina qué información recibe el LLM como contexto para generar su respuesta.

Formalmente, dada una consulta `q` y una colección de documentos `D = {d₁, d₂, ..., dₙ}`, un sistema de retrieval produce un ranking:

```
rank(q, D) = ordenar D por sim(q, dᵢ) descendente, devolver top-k
```

Donde `sim(q, dᵢ)` es una función de similitud que puede operar en **espacio denso** (embeddings neuronales), **espacio disperso** (frecuencias de términos) o una combinación de ambos.

### Dos familias fundamentales

| Familia | Representación | Qué captura | Ejemplo clásico |
|---|---|---|---|
| **Sparse (disperso)** | Vector de dimensión = tamaño del vocabulario, casi todo ceros | Coincidencia léxica exacta | TF-IDF, BM25 |
| **Dense (denso)** | Vector de dimensión fija (384, 768, 1536…) con valores no cero en todas las dimensiones | Significado semántico | OpenAI `text-embedding-3`, `all-MiniLM-L6-v2`, BGE, E5 |

Un tercer enfoque, **learned sparse** (SPLADE, ColBERT), combina la interpretabilidad léxica con el aprendizaje neuronal y se encuentra en producción desde ~2020.

## ¿Por qué importa?

La calidad del retrieval **limita el techo** de todo el sistema RAG: si no se recupera el fragmento correcto, ningún LLM —por bueno que sea— podrá responder bien. Este principio se conoce como *"garbage retrieval in, garbage generation out"*.

- **Dense retrieval** entiende sinónimos (`automóvil` ≈ `coche`), parafrasis y conceptos, pero puede fallar con **términos exactos** poco frecuentes (nombres de API, códigos de producto, identificadores).
- **Sparse retrieval** acierta con *keywords* exactos pero no entiende semántica: busca `coche` y no encontrará `automóvil`.
- **Hybrid** combina ambos y suele superar a cualquiera de los dos por separado en benchmarks como BEIR y MTEB.

### Contexto histórico

| Año | Hito |
|---|---|
| 1976 | Robertson & Spärck Jones formalizan el modelo probabilístico que lleva a **BM25** (Best Match 25). |
| 1994 | BM25 se consolida en el TREC-3 como baseline de referencia en IR. |
| 2013 | Word2Vec populariza los embeddings densos. |
| 2019 | DPR (Dense Passage Retrieval) demuestra que embeddings aprendidos superan a BM25 en Open-QA. |
| 2020 | **ColBERT** introduce late interaction (interacción tardía) y SPLADE populariza sparse aprendido. |
| 2021 | **Reciprocal Rank Fusion (RRF)** se vuelve estándar para fusionar rankings. |
| 2022 | **HyDE** (Hypothetical Document Embeddings) propone generar documentos falsos para mejorar la consulta. |
| 2023+ | Rerankers cross-encoder (Cohere Rerank, bge-reranker, Jina) se vuelven obligatorios en producción. |

## ¿Cómo funciona?

### Sparse retrieval: TF-IDF y BM25

**TF-IDF** (Term Frequency – Inverse Document Frequency) pondera cada término `t` en un documento `d`:

```
tf-idf(t, d) = tf(t, d) · log( N / df(t) )
```

Donde `N` es el total de documentos y `df(t)` el número de documentos que contienen `t`. Palabras raras pesan más.

**BM25** (Robertson, 1976) es una mejora probabilística de TF-IDF con dos hiperparámetros (`k₁`, `b`) y normalización por longitud:

```
                      f(t,d) · (k₁ + 1)
BM25(q,d) = Σ idf(t) · ─────────────────────────────────────────
            t∈q         f(t,d) + k₁ · (1 − b + b · |d|/avgdl)
```

- `f(t,d)`: frecuencia del término `t` en el documento `d`.
- `|d|` / `avgdl`: longitud del documento normalizada por la longitud media.
- `k₁ ∈ [1.2, 2.0]`: controla la saturación de la frecuencia (BM25 ignora repeticiones excesivas).
- `b ∈ [0, 1]`, típicamente 0.75: controla cuánto se penaliza la longitud.
- `idf(t) = log( (N − df(t) + 0.5) / (df(t) + 0.5) + 1 )`

BM25 sigue siendo el **baseline a batir** en 2026, incluso frente a modelos neuronales modernos en dominios de nicho.

### Dense retrieval

Un modelo de embeddings `E` convierte texto en un vector `v ∈ ℝᵈ`:

```
v_query = E("¿cómo reinicio mi contraseña?")   # p.ej. ℝ⁷⁶⁸
v_docᵢ  = E(docᵢ)                              # pre-calculado offline
score    = cos(v_query, v_docᵢ) = (v_q · v_d) / (||v_q||·||v_d||)
```

Los embeddings se buscan con un índice ANN (HNSW, IVF, ScaNN) en el *vector store* (Qdrant, Weaviate, Pinecone, Milvus, pgvector).

Modelos modernos requieren **prefijos de instrucción**:

- **E5**: `"query: ..."` para consultas y `"passage: ..."` para documentos.
- **BGE**: `"Represent this sentence for searching relevant passages: ..."` solo en la consulta.
- **GTE / Jina**: generalmente sin prefijo.

Omitir el prefijo degrada el recall en 5-15 puntos.

### Comparativa dense vs sparse vs hybrid

| Criterio | Sparse (BM25) | Dense (embeddings) | Hybrid (RRF) |
|---|---|---|---|
| Coincidencia exacta de keywords | Excelente | Débil | Excelente |
| Sinónimos y paráfrasis | Muy pobre | Excelente | Muy bueno |
| Nombres propios, códigos, SKUs | Excelente | Pobre | Excelente |
| Cross-lingual (ES→EN) | Nulo | Bueno con modelos multilingües | Bueno |
| Coste de indexación | Muy bajo | Alto (GPU para embeddings) | Alto |
| Coste de consulta | Bajo (índice invertido) | Medio (ANN) | Medio-alto |
| Interpretabilidad | Alta (se ven qué términos pesan) | Baja (vector opaco) | Media |
| Benchmark BEIR (NDCG@10 promedio) | ~0.42 | ~0.45 | ~0.52 |

### Fusión de rankings: Reciprocal Rank Fusion (RRF)

Para combinar los rankings de dense y sparse se usa RRF (Cormack et al., 2009):

```
RRF(d) = Σ   1 / (k + rank_s(d))
         s∈S
```

Donde `S` es el conjunto de sistemas (dense, sparse), `rank_s(d)` es la posición de `d` en el ranking `s`, y `k = 60` por convención. RRF es **sin parámetros** (robusto) y suele batir a combinaciones ponderadas lineales.

### Métricas de similitud

| Métrica | Fórmula | Cuándo usar |
|---|---|---|
| **Cosine** | `(A·B) / (||A||·||B||)` | Default para texto. Ignora magnitud. |
| **Dot product** | `Σ A[i]·B[i]` | Cuando los embeddings están normalizados (equivale a cosine) y se busca velocidad. |
| **Euclidean (L2)** | `√Σ(A[i]−B[i])²` | Raro en texto; útil en datos de baja dimensionalidad. |

## Ejemplo con código

### BM25 con `rank_bm25`

```python
# pip install rank_bm25
from rank_bm25 import BM25Okapi

corpus = [
    "Cómo reiniciar tu contraseña desde el portal de clientes",
    "Política de reembolsos en los primeros 30 días",
    "Autenticación con la API usando el endpoint auth/v2/token",
    "Guía de integración OAuth2 con nuestro servicio",
]

# Tokenización mínima (en producción: lowercase, acentos, stemming)
tokenized_corpus = [doc.lower().split() for doc in corpus]
bm25 = BM25Okapi(tokenized_corpus, k1=1.5, b=0.75)

query = "endpoint auth/v2/token".lower().split()
scores = bm25.get_scores(query)

for score, doc in sorted(zip(scores, corpus), reverse=True):
    print(f"{score:5.2f}  {doc}")
```

### Dense retrieval con `sentence-transformers` (prefijo E5)

```python
# pip install sentence-transformers
from sentence_transformers import SentenceTransformer
import numpy as np

model = SentenceTransformer("intfloat/multilingual-e5-base")

docs = [
    "passage: Cómo reiniciar tu contraseña desde el portal",
    "passage: Política de reembolsos de 30 días",
    "passage: Autenticación con la API usando auth/v2/token",
]
doc_emb = model.encode(docs, normalize_embeddings=True)

query = "query: ¿cómo cambio mi password?"
q_emb = model.encode([query], normalize_embeddings=True)

sims = (q_emb @ doc_emb.T)[0]      # dot = cosine si están normalizados
for s, d in sorted(zip(sims, docs), reverse=True):
    print(f"{s:.3f}  {d[9:]}")      # quitamos 'passage: '
```

### Hybrid search con Qdrant (dense + sparse + RRF)

```python
# pip install qdrant-client fastembed
from qdrant_client import QdrantClient, models

client = QdrantClient(":memory:")

client.create_collection(
    collection_name="docs",
    vectors_config={
        "dense": models.VectorParams(size=384, distance=models.Distance.COSINE),
    },
    sparse_vectors_config={"sparse": models.SparseVectorParams()},
)

# Suponiendo que ya calculamos dense y sparse (p.ej. con FastEmbed + SPLADE)
# ...upsert de puntos omitido por brevedad...

results = client.query_points(
    collection_name="docs",
    prefetch=[
        models.Prefetch(query=dense_vec,  using="dense",  limit=20),
        models.Prefetch(query=sparse_vec, using="sparse", limit=20),
    ],
    query=models.FusionQuery(fusion=models.Fusion.RRF),   # Reciprocal Rank Fusion
    limit=5,
)
```

### Hybrid con Weaviate (alpha-weighted)

```python
import weaviate
client = weaviate.connect_to_local()
collection = client.collections.get("Docs")

response = collection.query.hybrid(
    query="endpoint de autenticación",
    alpha=0.5,        # 0 = puro BM25, 1 = puro vector; 0.5 = balance
    limit=5,
)
```

## Errores comunes

- **Usar solo dense retrieval en dominios técnicos.** Nombres de API, SKUs, códigos de error (`ERR_42`) raramente aparecen en el corpus de pre-entrenamiento del embedding → se pierden en coincidencia léxica. Siempre añade BM25 en paralelo.
- **No filtrar por metadata.** Buscar en 10 millones de chunks cuando el usuario pertenece al tenant `A` o pregunta por documentos del 2024 trae ruido masivo. Filtra por `tenant_id`, `doc_type`, `date` **antes** del ANN.
- **`top_k` mal elegido.** Muy bajo (1-2) → pierdes contexto relevante; muy alto (50+) → diluyes la señal y rebasas la ventana del LLM. Patrón robusto: recupera `top_k=20-50`, re-rankea a 3-5.
- **Olvidar el prefijo de instrucción.** Modelos como E5 y BGE requieren `"query: ..."` / `"passage: ..."`. Sin ellos, el recall cae drásticamente.
- **No normalizar embeddings.** Si usas dot product sin normalizar obtendrás scores sensibles a la magnitud y rankings inconsistentes.
- **Confiar en cosine > 0.5 como "relevante".** El umbral depende totalmente del modelo. BGE da scores más altos que `all-MiniLM`. Calibra con tu propio *golden set*.
- **No re-rankear.** Dense/sparse te dan candidatos; un cross-encoder los re-ordena mucho mejor. Ver Lección 2.
- **Mezclar modelos de embedding distintos en el mismo índice.** Los vectores viven en espacios incomparables → similitudes sin sentido. Si cambias de modelo, re-indexa todo.

## Resumen

- **Retrieval = encontrar los chunks correctos**; su calidad fija el techo del RAG.
- **Sparse (BM25)** domina la coincidencia léxica exacta; **dense** entiende semántica; **hybrid + RRF** suele ganar en benchmarks (BEIR).
- **BM25** es la fórmula probabilística de 1976 que sigue siendo baseline obligatorio en 2026.
- Para texto usa **cosine similarity** (o dot product sobre vectores normalizados).
- Modelos modernos (E5, BGE) requieren **prefijos de instrucción** distintos para query y passage.
- Herramientas estándar: `rank_bm25`, Elasticsearch / OpenSearch, Qdrant, Weaviate, Milvus, pgvector.
- En la Lección 2 veremos **re-rankers** (Cohere, bge-reranker, cross-encoders) y en la Lección 3 técnicas de **optimización de la consulta** (HyDE, multi-query, MMR).
