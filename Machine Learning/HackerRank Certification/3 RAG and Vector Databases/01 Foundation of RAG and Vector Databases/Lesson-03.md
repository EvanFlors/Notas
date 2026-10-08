# Vector Databases, indexing y chunking

## ¿Qué es?

Una **vector database** (base de datos vectorial) es un sistema especializado para **almacenar** vectores de alta dimensión y **buscar los más similares** a una query en tiempo sub-segundo, incluso con millones o miles de millones de vectores. A diferencia de una base relacional (que busca por igualdad exacta: `WHERE id = 42`), una vector DB resuelve el problema del **Approximate Nearest Neighbor (ANN) search**:

```
Dado un query vector q ∈ ℝᵈ y un conjunto V = {v₁, ..., vₙ} ⊂ ℝᵈ,
encuentra los k vectores más cercanos a q según una métrica de distancia.
```

El reto es que una búsqueda **exacta** (brute force) es `O(n·d)`: para 10 millones de vectores de 1536 dims, cada query cuesta ~60 ms-500 ms y escala linealmente. Las vector DBs usan **índices aproximados (ANN)** que logran latencias de 1-20 ms con recall >95%, al costo de **no garantizar** devolver los k vecinos **exactos**.

### Componentes de una vector DB

```
┌─────────────────────────────────────────────────┐
│  Vector DB                                      │
│                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────────┐  │
│  │ Vectors  │  │ Metadata │  │ Index (HNSW, │  │
│  │ (ℝᵈ)     │  │ (JSON)   │  │  IVF, LSH)   │  │
│  └──────────┘  └──────────┘  └──────────────┘  │
│                                                 │
│  API: upsert, search, filter, delete            │
│  Features: persistence, replication, sharding   │
└─────────────────────────────────────────────────┘
```

## ¿Por qué importa?

Un RAG puede funcionar en un notebook con 1,000 docs y numpy. En producción, con millones de chunks, usuarios concurrentes y requerimientos de latencia (<100 ms p99), **necesitas** infraestructura dedicada. Las vector DBs resuelven:

- **Escala:** búsqueda sub-segundo en miles de millones de vectores.
- **Persistencia:** sobreviven reinicios (numpy en RAM no).
- **Concurrencia:** miles de QPS con lectura/escritura segura.
- **Filtrado híbrido:** combinar similitud vectorial con filtros de metadata (`year > 2024 AND tenant_id = "acme"`).
- **Actualizaciones incrementales:** añadir/borrar vectores sin reconstruir todo el índice.
- **Multi-tenancy, replicación, snapshots, backups.**

Sin una vector DB, un RAG a escala es inviable.

## ¿Cómo funciona?

### Algoritmos de indexación (ANN)

#### HNSW (Hierarchical Navigable Small World)

Construye un **grafo multi-capa**: la capa superior tiene pocos nodos muy conectados (saltos largos), las capas inferiores tienen más nodos (saltos cortos). La búsqueda baja por el grafo, empezando por un nodo random en la capa superior y descendiendo greedy hacia el más cercano.

- **Pros:** altísimo recall (~99%), latencia muy baja (ms), buena para alta dimensión.
- **Contras:** uso de RAM elevado (grafo entero en memoria), inserciones costosas, difícil de eliminar vectores.
- **Hiperparámetros clave:** `M` (conexiones por nodo, típ. 16-64), `ef_construction` (calidad de construcción, 100-500), `ef_search` (candidatos en búsqueda, trade-off recall/latencia).
- **Usado por:** Qdrant, Pinecone, Weaviate, Milvus, pgvector (desde 0.5), Chroma.

#### IVF (Inverted File Index)

Pre-clusteriza los vectores en `nlist` celdas con **k-means**. En búsqueda, calcula la celda más cercana al query y busca solo dentro de las `nprobe` celdas más cercanas.

- **Pros:** memoria eficiente, bueno para datasets gigantes (>100M).
- **Contras:** menor recall que HNSW si `nprobe` es bajo; requiere "entrenar" el índice.
- **Variantes:** `IVF-Flat` (vectores completos), `IVF-PQ` (con **Product Quantization**: comprime cada vector a ~16 bytes).
- **Usado por:** FAISS, Milvus, Weaviate (opcional).

#### LSH (Locality-Sensitive Hashing)

Usa funciones hash diseñadas para que vectores similares colisionen en el mismo bucket con alta probabilidad. La búsqueda consulta solo los buckets del hash de la query.

- **Pros:** muy rápido, bueno para dimensiones extremadamente altas.
- **Contras:** recall más bajo que HNSW/IVF para dimensiones moderadas; menos popular hoy.
- **Usado por:** Datasketch, algunas configs de FAISS, aplicaciones de deduplicación.

#### ScaNN (Google)

Combina IVF con **anisotropic quantization**. Dominante en benchmarks de ANN pero con menos adopción fuera de Google/Vertex AI.

#### DiskANN (Microsoft)

Grafo que vive en SSD, soporta billones de vectores con poca RAM. Usado por Milvus, Turbopuffer, bases que priorizan costo.

### Comparación de algoritmos

| Algoritmo | Recall | Latencia | RAM | Build time | Mejor para |
|---|---|---|---|---|---|
| **Flat (brute force)** | 100% | O(n) | Alta | Instantáneo | <100k vectores, baseline |
| **HNSW** | 95-99% | <10 ms | Alta | Lento | Alta precisión, 1M-100M |
| **IVF-Flat** | 90-95% | ~20 ms | Media | Medio (entrena k-means) | 10M-1B vectores |
| **IVF-PQ** | 80-90% | ~20 ms | **Muy baja** | Medio | 100M-10B con poca RAM |
| **LSH** | 70-85% | <5 ms | Baja | Rápido | Dedup, altísima dim |
| **DiskANN** | 90-95% | 10-30 ms | Mínima (SSD) | Lento | Billones, costo bajo |

### Comparación de vector DBs

| DB | Tipo | Open Source | Managed | Latencia (típ.) | Fortalezas | Costo (indicativo) |
|---|---|---|---|---|---|---|
| **FAISS** | Librería | Sí (Meta) | No | <10 ms | Rápida, educativa, control total | Gratis (self-host) |
| **Chroma** | Embedded + server | Sí | Chroma Cloud | 10-50 ms | DX simple, ideal prototipos | Gratis / managed desde $0 |
| **Qdrant** | Server | Sí (Rust) | Qdrant Cloud | 5-20 ms | Filtrado avanzado, HNSW tuneable | Gratis / $25+ /mes |
| **Weaviate** | Server | Sí (Go) | WCS | 10-30 ms | GraphQL, hybrid search, módulos | Gratis / $25+ /mes |
| **Milvus** | Server distribuido | Sí (CNCF) | Zilliz Cloud | 10-50 ms | Escala a billones, muchas índices | Gratis / $65+ /mes |
| **Pinecone** | Managed | No | Sí | 10-50 ms | Zero-ops, serverless | $0 (starter) → miles/mes |
| **pgvector** | Extensión Postgres | Sí | RDS, Supabase, Neon | 10-50 ms | SQL + vector en un solo lugar | Gratis + costo Postgres |
| **Vespa** | Server | Sí (Yahoo) | Vespa Cloud | 10-30 ms | Hybrid + ranking complejo | Gratis / managed |
| **Elasticsearch / OpenSearch** | Server | Sí | Elastic Cloud, AWS | 20-100 ms | Full-text + vector maduro | $$-$$$ |
| **Turbopuffer** | Managed serverless | No | Sí | 50-200 ms | Costo bajísimo (object storage) | $ |
| **LanceDB** | Embedded columnar | Sí | LanceDB Cloud | 5-30 ms | Vive en S3, multimodal | Gratis / managed |

**Regla práctica:**
- Prototipo local → **Chroma** o **FAISS**.
- Producción con SQL existente → **pgvector**.
- Producción cloud managed → **Pinecone** o **Qdrant Cloud**.
- Escala masiva (>100M) → **Milvus**, **Vespa** o **Qdrant** self-hosted.
- Costo mínimo con latencia relajada → **Turbopuffer** o **LanceDB**.

### Chunking: dividir documentos antes de embeber

Los modelos de embeddings tienen límite de tokens (típ. 512-8192). Además, embeber un PDF entero en un solo vector **diluye** la señal: si el doc tiene 20 temas, el vector es un promedio y no destaca ninguno. Solución: **partir en chunks** y embeber cada uno.

#### Estrategias de chunking

| Estrategia | Cómo | Pros | Contras |
|---|---|---|---|
| **Fixed-size** | N caracteres / tokens | Simple, rápido | Corta palabras y oraciones |
| **Fixed-size + overlap** | N tokens con solapamiento (ej. 10-20%) | Preserva contexto en bordes | Duplica almacenamiento |
| **Recursive** (LangChain) | Separa por `\n\n`, luego `\n`, luego `. `, luego ` ` hasta caber | Respeta estructura natural | Más lento |
| **Sentence-based** | 1 chunk = N oraciones (spaCy, NLTK) | Semánticamente coherente | Requiere tokenizer |
| **Markdown-aware** | Respeta `##`, listas, tablas, bloques de código | Perfecto para docs técnicos | Solo para MD/HTML |
| **Semantic chunking** | Divide donde cambia el tema (gap en embeddings de oraciones sucesivas) | Chunks temáticos | Caro (embebe para chunk-ear) |
| **Hierarchical / parent-child** | Chunks pequeños para búsqueda, grandes para contexto | Mejor recall + mejor contexto | Doble almacenamiento |
| **Agentic / LLM-based** | Un LLM decide los cortes | Máxima calidad | Caro y lento |

#### Guía de tamaño

| Caso | `chunk_size` (tokens) | `overlap` |
|---|---|---|
| QA factual, docs cortos | 128-256 | 20-30 |
| Soporte / FAQ | 256-512 | 50 |
| Documentación técnica | 512-1024 | 100 |
| Papers, libros | 800-1500 | 150 |
| Código fuente | por función/clase | 0 (AST-aware) |

**Trade-off clave:**
- Chunks **muy grandes** → se **diluye** la señal, el LLM recibe mucho contenido irrelevante.
- Chunks **muy pequeños** → se **pierde contexto** (una oración sin su párrafo no se entiende).
- **Sin overlap** → una idea que cruza el borde se corta y queda inaccesible.

## Ejemplo con código

### 1. Chunking con LangChain

```python
# pip install langchain-text-splitters
from langchain_text_splitters import RecursiveCharacterTextSplitter, MarkdownHeaderTextSplitter

text = open("docs/manual.md").read()

# Recursive: respeta párrafos > oraciones > palabras
splitter = RecursiveCharacterTextSplitter(
    chunk_size=800,        # caracteres (aprox. 200 tokens)
    chunk_overlap=100,     # ~12% overlap
    separators=["\n\n", "\n", ". ", " ", ""],
)
chunks = splitter.split_text(text)
print(f"{len(chunks)} chunks, promedio {sum(len(c) for c in chunks)//len(chunks)} chars")

# Markdown-aware: respeta encabezados
md_splitter = MarkdownHeaderTextSplitter(
    headers_to_split_on=[("#", "h1"), ("##", "h2"), ("###", "h3")],
)
md_chunks = md_splitter.split_text(text)
for c in md_chunks[:3]:
    print(c.metadata, "→", c.page_content[:80])
```

### 2. Semantic chunking

```python
# pip install langchain-experimental langchain-openai
from langchain_experimental.text_splitter import SemanticChunker
from langchain_openai import OpenAIEmbeddings

splitter = SemanticChunker(
    OpenAIEmbeddings(model="text-embedding-3-small"),
    breakpoint_threshold_type="percentile",  # corta en el percentil 95 de distancia
    breakpoint_threshold_amount=95,
)
chunks = splitter.create_documents([text])
```

### 3. Ingesta completa en Chroma

```python
# pip install chromadb sentence-transformers
import chromadb
from sentence_transformers import SentenceTransformer
from langchain_text_splitters import RecursiveCharacterTextSplitter

embedder = SentenceTransformer("BAAI/bge-small-en-v1.5")
splitter = RecursiveCharacterTextSplitter(chunk_size=500, chunk_overlap=50)

docs = {
    "refunds.md": "Los reembolsos tardan 5-7 días...",
    "shipping.md": "Las entregas internacionales toman 10-15 días...",
    "support.md": "El soporte atiende de lunes a viernes...",
}

client = chromadb.PersistentClient(path="./chroma_db")
collection = client.get_or_create_collection(
    name="kb",
    metadata={"hnsw:space": "cosine", "hnsw:M": 32, "hnsw:construction_ef": 200},
)

for source, text in docs.items():
    chunks = splitter.split_text(text)
    embeddings = embedder.encode(chunks, normalize_embeddings=True).tolist()
    collection.add(
        ids=[f"{source}::{i}" for i in range(len(chunks))],
        documents=chunks,
        embeddings=embeddings,
        metadatas=[{"source": source, "chunk": i} for i in range(len(chunks))],
    )

# Query con filtro de metadata
query = "¿cuánto tarda mi reembolso?"
q_emb = embedder.encode([query], normalize_embeddings=True).tolist()
results = collection.query(
    query_embeddings=q_emb,
    n_results=3,
    where={"source": "refunds.md"},   # filtro híbrido
)
for doc, meta, dist in zip(results["documents"][0],
                           results["metadatas"][0],
                           results["distances"][0]):
    print(f"[{1 - dist:.3f}] ({meta['source']}) {doc[:80]}...")
```

### 4. Qdrant con HNSW tuneado y filtros

```python
# pip install qdrant-client
from qdrant_client import QdrantClient
from qdrant_client.models import (
    Distance, VectorParams, PointStruct, HnswConfigDiff,
    Filter, FieldCondition, MatchValue,
)

qd = QdrantClient(url="http://localhost:6333")
qd.recreate_collection(
    collection_name="kb",
    vectors_config=VectorParams(size=384, distance=Distance.COSINE),
    hnsw_config=HnswConfigDiff(m=32, ef_construct=200),
)

# upsert con metadata
qd.upsert(
    collection_name="kb",
    points=[
        PointStruct(id=i, vector=v, payload={"source": s, "year": 2026})
        for i, (v, s) in enumerate(zip(embeddings, ["refunds.md"] * len(embeddings)))
    ],
)

# search con filtro
hits = qd.search(
    collection_name="kb",
    query_vector=q_emb[0],
    limit=5,
    search_params={"hnsw_ef": 128},   # ↑ recall, ↑ latencia
    query_filter=Filter(must=[
        FieldCondition(key="year", match=MatchValue(value=2026))
    ]),
)
for h in hits:
    print(h.score, h.payload)
```

### 5. FAISS puro para benchmark local

```python
# pip install faiss-cpu
import faiss, numpy as np

d = 384
index = faiss.IndexHNSWFlat(d, 32)        # M=32
index.hnsw.efConstruction = 200
index.hnsw.efSearch = 64

vecs = np.random.random((100_000, d)).astype("float32")
faiss.normalize_L2(vecs)
index.add(vecs)

q = np.random.random((1, d)).astype("float32"); faiss.normalize_L2(q)
D, I = index.search(q, k=5)
print(D, I)
```

### 6. pgvector (Postgres)

```sql
CREATE EXTENSION IF NOT EXISTS vector;
CREATE TABLE kb (
    id SERIAL PRIMARY KEY,
    source TEXT,
    content TEXT,
    embedding vector(384)
);

-- Índice HNSW (pgvector >= 0.5)
CREATE INDEX ON kb USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

-- Búsqueda top-5 con filtro
SELECT content, 1 - (embedding <=> $1) AS similarity
FROM kb
WHERE source = 'refunds.md'
ORDER BY embedding <=> $1
LIMIT 5;
```

## Errores comunes

- **Chunks demasiado grandes.** 2000 tokens por chunk → se **diluye** la señal; el embedding promedia 10 temas y no destaca ninguno. Objetivo: 1 chunk = 1 idea.
- **Chunks demasiado pequeños.** 50 tokens pierden contexto; el LLM recibe fragmentos sin suficiente info para responder. Prefiere 256-512 para texto normal.
- **No usar overlap.** Una idea que cruza el borde del chunk queda **mitad en uno y mitad en otro**, y ninguno la contiene completa. Usa 10-20% de overlap.
- **Chunking que ignora estructura.** Partir a mitad de una tabla, bloque de código o lista destroza el significado. Usa splitters **aware** del formato (Markdown, HTML, código con AST).
- **Mezclar query y document embeddings de modelos asimétricos.** Con E5/Cohere embed-v3 usar el **mismo prefijo** rompe el modelo. Query = `search_query`, docs = `search_document`.
- **No normalizar vectores.** Si tu índice está configurado como `cosine` pero mandas vectores no normalizados, muchos backends igual los normalizan internamente; si usas `dot`, el ranking se corrompe. **Normaliza en ingesta y en query**.
- **Dimensionalidad mal ajustada.** Crear la colección con `size=768` y mandar vectores de 1536 → error. O peor: silencioso (algún backend trunca). Verifica siempre.
- **Elegir por hype.** No necesitas Pinecone para 10,000 docs. Empieza con Chroma o pgvector; sube de complejidad cuando duela.
- **Olvidar los filtros de metadata.** Un vector search sin filtros devuelve docs de todos los tenants / todas las fechas. Usa `payload` + filtros para seguridad y relevancia.
- **No monitorear recall.** Los índices ANN pueden degradarse al crecer la data o cambiar la distribución. Mide **Recall@k vs. brute force** periódicamente en un sample.
- **No planear el rebuild.** Añadir muchos vectores a un HNSW puede fragmentarlo; a veces conviene reconstruir desde cero. Planea ventanas de mantenimiento.
- **Latencia por batch size.** Enviar 1000 queries secuenciales en vez de un batch → 1000x más latencia. Usa el API batch cuando exista.
- **No cachear embeddings de queries frecuentes.** Las top queries se repiten; cachear ahorra API calls y latencia.

## Resumen

- Una **vector DB** almacena vectores y los busca por **similitud aproximada (ANN)** en milisegundos.
- Algoritmos: **HNSW** (grafo multi-capa, alta precisión), **IVF** (clustering, memoria eficiente), **IVF-PQ** (comprime vectores), **LSH** (hash), **DiskANN** (SSD, billones).
- Herramientas: **FAISS, Chroma, Qdrant, Weaviate, Milvus, Pinecone, pgvector, Vespa, LanceDB**. Elige por escala, hosting, costo y features de filtrado.
- **Chunking** es la decisión más impactante del pipeline: tamaño, overlap, estrategia (fixed, recursive, markdown-aware, semantic, hierarchical).
- Reglas de oro de chunking: **respeta la estructura**, **usa overlap**, **ajusta tamaño al tipo de contenido**, **un chunk = una idea**.
- Filtrado híbrido (vector + metadata) es imprescindible en multi-tenant y para precision.
- **Normaliza siempre**, **respeta prefijos asimétricos**, **verifica dimensionalidad**, **cachea queries frecuentes**.
- Empieza simple (Chroma/pgvector) y escala solo cuando la operación lo exija; migrar es costoso pero no imposible porque el **pipeline conceptual** (chunk → embed → index → search) es portable entre DBs.
- Monitorea **recall, latencia, memoria y fullness** del índice; los sistemas ANN se degradan silenciosamente.
- La trilogía RAG queda cerrada: **por qué** (Lesson-01), **cómo compara significado** (Lesson-02 embeddings), **dónde vive y cómo se busca a escala** (esta lesson).
