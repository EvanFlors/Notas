# ¿Qué es RAG (Retrieval-Augmented Generation)?

## ¿Qué es?

**RAG (Retrieval-Augmented Generation)** es una arquitectura que combina un **sistema de recuperación de información** con un **modelo generativo** (típicamente un LLM). En vez de pedirle al modelo que responda únicamente desde los pesos aprendidos durante su entrenamiento, primero se **buscan documentos relevantes** en una base de conocimiento externa y se **inyectan como contexto** en el prompt. El LLM entonces genera la respuesta **anclada** (grounded) en esos documentos.

Formalmente, un sistema RAG descompone la generación `P(y | x)` en:

```
P(y | x) ≈ Σ_z P(y | x, z) · P(z | x)
            └─ generador ─┘   └ recuperador ┘
```

- `x` es la consulta (query) del usuario.
- `z` son los documentos candidatos recuperados.
- `P(z | x)` es la probabilidad de relevancia (modelada por el **retriever**, típicamente con embeddings y búsqueda de similitud).
- `P(y | x, z)` es la generación condicionada en query + contexto (el **generator**, un LLM).

Esta formulación proviene del paper fundacional de **Lewis et al., 2020** ("Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks", Facebook AI), que acuñó el término y mostró que separar "qué sé" de "cómo lo digo" mejora drásticamente la precisión en tareas de QA.

### Analogía: examen con libro abierto

Un LLM puro es como un estudiante contestando un examen **de memoria**: puede equivocarse, inventar o quedarse desactualizado. Un sistema RAG es ese mismo estudiante pero con **el libro de texto abierto**: antes de contestar, busca la página relevante y escribe su respuesta citando lo que leyó.

### Componentes mínimos

```
                 ┌──────────────────────────────────────────┐
Usuario ──query──▶  1. Embedder (query → vector)            │
                 │  2. Vector DB (búsqueda top-k)           │
                 │  3. Context assembly (chunks + query)    │
                 │  4. LLM (prompt → respuesta)             │
                 └──────────────────────────────────────────┘
                                   │
                                   ▼
                           Respuesta con citas
```

Y en paralelo, el **pipeline de ingesta** (offline):

```
Docs crudos → Loader → Chunker → Embedder → Vector DB
```

## ¿Por qué importa?

Los LLMs "puros" (sin recuperación) tienen tres limitaciones estructurales que RAG resuelve.

### 1. Knowledge cutoff

Todo LLM se entrena hasta una fecha de corte. GPT-4 Turbo tiene cutoff en abril 2023, Claude 3.5 Sonnet en abril 2024, etc. Preguntarle "¿quién ganó el Mundial 2026?" devuelve una **negativa o una invención**. RAG permite inyectar datos **frescos** (noticias, reportes financieros publicados ayer) sin reentrenar el modelo.

### 2. Hallucinations (alucinaciones)

Los LLMs están entrenados para **sonar plausibles**, no para ser verídicos. Cuando no "saben" algo, siguen generando: inventan APIs, citas, autores, fechas, incluso DOIs falsos de papers. RAG mitiga esto porque:

- La respuesta se construye desde documentos reales.
- Se pueden mostrar **citas** y permitir al usuario verificar.
- Si no hay documentos relevantes, un buen sistema RAG responde *"no tengo información suficiente"* en vez de improvisar.

### 3. Conocimiento privado / específico de dominio

El LLM nunca vio tu **wiki interna**, los contratos de tu empresa, la documentación de tu API privada, los tickets de soporte de los últimos 2 años. RAG es la forma estándar de darle al modelo acceso a ese corpus **sin fine-tuning**.

### RAG vs. Fine-tuning

| Dimensión | RAG | Fine-tuning |
|---|---|---|
| **Qué cambia** | El contexto en runtime | Los pesos del modelo |
| **Latencia por query** | +100-500 ms (retrieval) | Igual que modelo base |
| **Costo de setup** | Bajo (indexar docs) | Alto (GPUs + data labeling) |
| **Costo de actualizar** | Casi cero (re-indexar) | Alto (reentrenar) |
| **Mejor para** | Conocimiento factual, cambiante, citado | Estilo, formato, razonamiento especializado |
| **Transparencia** | Alta (hay fuentes) | Baja (caja negra) |
| **Riesgo de alucinación** | Reducido si retrieval es bueno | No se reduce |

En la práctica son **complementarios**: se puede hacer fine-tuning para el *tono* y usar RAG para los *hechos*.

### Contexto histórico

- **2020:** Lewis et al. publican el paper original de RAG en NeurIPS.
- **2022:** aparece **LangChain** (octubre) y popular una abstracción "chain" sobre RAG.
- **2023:** boom tras GPT-4 (marzo). Pinecone, Weaviate, Qdrant escalan masivamente. **LlamaIndex** emerge como framework dedicado a RAG.
- **2024:** context windows crecen (GPT-4 Turbo 128K, Claude 3 200K, Gemini 1.5 1M-2M). Surge el debate "¿RAG o long-context?". Respuesta pragmática: **RAG sigue ganando** por costo, latencia, precisión y actualización incremental.
- **2025:** auge de **agentic RAG** (el agente decide cuándo/qué buscar), **GraphRAG** (Microsoft), re-rankers híbridos.

## ¿Cómo funciona?

### Pipeline detallado

```
┌─────────────────────── OFFLINE (ingesta) ───────────────────────┐
│                                                                  │
│  Documentos (PDF, HTML, MD, Notion, Confluence, SQL, APIs)      │
│          │                                                       │
│          ▼                                                       │
│   Loaders (PyPDF, Unstructured, BeautifulSoup)                  │
│          │                                                       │
│          ▼                                                       │
│   Chunking (fixed-size, recursive, semantic, markdown-aware)    │
│          │                                                       │
│          ▼                                                       │
│   Embedding model (OpenAI, Cohere, BGE, E5, sentence-trans)     │
│          │                                                       │
│          ▼                                                       │
│   Vector DB (Chroma, Pinecone, Qdrant, Weaviate, Milvus, pgv)   │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘

┌─────────────────────── ONLINE (query) ──────────────────────────┐
│                                                                  │
│  Query del usuario                                              │
│          │                                                       │
│          ▼                                                       │
│   (Opcional) Query rewriting / HyDE / multi-query               │
│          │                                                       │
│          ▼                                                       │
│   Embedding de la query (MISMO modelo que ingesta)              │
│          │                                                       │
│          ▼                                                       │
│   Vector search (top-k por cosine / dot product)                │
│          │                                                       │
│          ▼                                                       │
│   (Opcional) Re-ranker (Cohere Rerank, bge-reranker, LLM-judge) │
│          │                                                       │
│          ▼                                                       │
│   Prompt assembly: system + context (chunks) + query            │
│          │                                                       │
│          ▼                                                       │
│   LLM (GPT-4o, Claude, Llama, Mistral) → respuesta + citas      │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### Prompt típico de RAG

```
Eres un asistente que responde únicamente con base en el CONTEXTO
proporcionado. Si la respuesta no está en el contexto, di
"No tengo información suficiente".

CONTEXTO:
[chunk 1 — fuente: policies/refunds.md]
...
[chunk 2 — fuente: faq/returns.md]
...

PREGUNTA: {query_del_usuario}

RESPUESTA (cita las fuentes entre corchetes):
```

### Métricas clave

| Métrica | Qué mide | Cómo se evalúa |
|---|---|---|
| **Recall@k** | ¿Está el documento correcto en los top-k? | Dataset etiquetado (query → doc_id correcto) |
| **MRR (Mean Reciprocal Rank)** | Posición promedio del primer resultado correcto | 1/rank |
| **nDCG@k** | Calidad del ranking considerando posición | Ground truth graduado |
| **Faithfulness** | ¿La respuesta está respaldada por el contexto? | Ragas, LLM-as-judge |
| **Answer relevance** | ¿La respuesta contesta la pregunta? | Ragas, humanos |
| **Context precision** | ¿Los chunks recuperados son relevantes? | Ragas |

Frameworks de evaluación: **Ragas**, **TruLens**, **DeepEval**, **ARES**.

### Cuándo usar RAG

Elige RAG cuando:

- El conocimiento necesita **actualizarse** con frecuencia (docs internos, news, catálogo).
- Debes **citar fuentes** (compliance, legal, salud).
- El corpus es **grande** (no cabe en el context window).
- Quieres **evitar reentrenamientos** costosos.
- Necesitas **control de acceso** por documento (multi-tenancy).

### Cuándo NO usar RAG

- **Tareas creativas puras:** poesía, brainstorming, ficción.
- **Conversación casual:** small talk, charla general.
- **Cálculo matemático / lógica pura:** mejor tool-calling (Python interpreter).
- **Latencia ultra-baja (<50 ms):** retrieval añade overhead.
- **Dominio ya cubierto:** el LLM base ya responde bien (ej. sintaxis básica de Python).

## Ejemplo con código

Ejemplo mínimo end-to-end usando **sentence-transformers** (embeddings local) y **ChromaDB** (vector DB in-process). Después, variante con **OpenAI** + **Qdrant**.

```python
# ============================================================
# RAG mínimo: sentence-transformers + ChromaDB
# ============================================================
# pip install sentence-transformers chromadb

from sentence_transformers import SentenceTransformer
import chromadb

# 1. Corpus de ejemplo (política de reembolsos de una empresa ficticia)
docs = [
    "Los reembolsos se procesan en 5-7 días hábiles tras aprobación.",
    "Para solicitar un reembolso, el pedido debe tener menos de 30 días.",
    "Los productos digitales no son reembolsables una vez descargados.",
    "El horario de atención al cliente es de lunes a viernes 9-18 CST.",
    "Para cambios de talla, usa el portal de devoluciones sin costo extra.",
]
ids = [f"doc_{i}" for i in range(len(docs))]

# 2. Embedder (384 dims, rápido, open-source)
embedder = SentenceTransformer("all-MiniLM-L6-v2")
embeddings = embedder.encode(docs, normalize_embeddings=True).tolist()

# 3. Vector DB
client = chromadb.Client()
collection = client.create_collection(
    name="policies",
    metadata={"hnsw:space": "cosine"},  # métrica
)
collection.add(ids=ids, documents=docs, embeddings=embeddings)

# 4. Query
query = "¿Cuánto tardan en devolverme el dinero?"
q_emb = embedder.encode([query], normalize_embeddings=True).tolist()
results = collection.query(query_embeddings=q_emb, n_results=3)

print("Chunks recuperados:")
for doc, dist in zip(results["documents"][0], results["distances"][0]):
    print(f"  [{1 - dist:.3f}] {doc}")

# 5. Ensamblar prompt y llamar al LLM (pseudocódigo)
context = "\n".join(f"- {d}" for d in results["documents"][0])
prompt = f"""Responde únicamente con base en el CONTEXTO.
Si no está la respuesta, di "no tengo información suficiente".

CONTEXTO:
{context}

PREGUNTA: {query}
RESPUESTA:"""

# respuesta = openai_client.chat.completions.create(
#     model="gpt-4o-mini",
#     messages=[{"role": "user", "content": prompt}],
# )
# print(respuesta.choices[0].message.content)
```

### Variante producción: OpenAI + Qdrant

```python
# pip install openai qdrant-client
from openai import OpenAI
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct

oai = OpenAI()
qd = QdrantClient(url="http://localhost:6333")

# Crear colección (text-embedding-3-small → 1536 dims)
qd.recreate_collection(
    collection_name="kb",
    vectors_config=VectorParams(size=1536, distance=Distance.COSINE),
)

def embed(texts: list[str]) -> list[list[float]]:
    resp = oai.embeddings.create(model="text-embedding-3-small", input=texts)
    return [d.embedding for d in resp.data]

# Ingesta
docs = ["...", "...", "..."]  # tu corpus
vectors = embed(docs)
qd.upsert(
    collection_name="kb",
    points=[
        PointStruct(id=i, vector=v, payload={"text": t})
        for i, (v, t) in enumerate(zip(vectors, docs))
    ],
)

# Consulta
query = "¿Política de reembolso para productos digitales?"
q_vec = embed([query])[0]
hits = qd.search(collection_name="kb", query_vector=q_vec, limit=4)

context = "\n\n".join(h.payload["text"] for h in hits)
chat = oai.chat.completions.create(
    model="gpt-4o-mini",
    messages=[
        {"role": "system", "content": "Responde solo con base en el contexto."},
        {"role": "user", "content": f"CONTEXTO:\n{context}\n\nPREGUNTA: {query}"},
    ],
)
print(chat.choices[0].message.content)
```

### Con LangChain (abstracción de alto nivel)

```python
from langchain_openai import OpenAIEmbeddings, ChatOpenAI
from langchain_community.vectorstores import Chroma
from langchain.chains import RetrievalQA

emb = OpenAIEmbeddings(model="text-embedding-3-small")
vs = Chroma.from_texts(texts=docs, embedding=emb, collection_name="kb")
qa = RetrievalQA.from_chain_type(
    llm=ChatOpenAI(model="gpt-4o-mini"),
    retriever=vs.as_retriever(search_kwargs={"k": 4}),
    return_source_documents=True,
)
print(qa.invoke({"query": "¿Cuánto tarda el reembolso?"}))
```

## Errores comunes

- **Usar RAG donde no hace falta.** Preguntas conversacionales ("hola, ¿cómo estás?") no necesitan retrieval. Añaden latencia y costo. Añade un **router** que decida si invocar el pipeline.
- **Confundir RAG con fine-tuning.** RAG añade *conocimiento*; fine-tuning cambia *comportamiento*. Para "quiero que el bot hable como pirata" fine-tunea; para "quiero que conozca mis docs" usa RAG.
- **Mezclar embedders.** Si indexas con `all-MiniLM-L6-v2` y consultas con `text-embedding-3-small`, los vectores viven en **espacios distintos** y la similitud no tiene sentido. Reglas de oro: **mismo modelo para ingesta y query** y **re-indexar todo** al cambiar de modelo.
- **No evaluar el retriever de forma aislada.** Si la respuesta es mala, puede ser por el LLM o por recuperación pobre. Mide **Recall@k** antes de culpar al generador.
- **Context stuffing sin límite.** Meter 50 chunks porque "cabe" degrada la calidad (**lost-in-the-middle**: Liu et al. 2023 mostraron que los LLMs ignoran contenido en el medio del prompt). Usa top-k pequeño (3-6) + re-ranker.
- **Olvidar las citas.** Sin referencias el usuario no puede verificar; se pierde el principal beneficio de RAG. Siempre devuelve `source_id` o URL.
- **No filtrar por metadata.** Si tu DB tiene docs de 2015 y de 2026, sin filtro temporal el modelo puede contestar con info obsoleta. Usa `filter={"year": {"$gte": 2024}}`.
- **Chunking ingenuo.** Partir a mitad de una oración o tabla rompe el significado. Prefiere chunking recursivo o semántico (ver Lesson-03).
- **No manejar el caso "sin resultados".** Si ningún chunk supera un umbral de similitud, el LLM debe decir "no sé", no inventar. Implementa `threshold` + fallback.

## Resumen

- **RAG** = recuperación + generación: busca documentos relevantes y los inyecta como contexto antes de que el LLM responda.
- Resuelve tres problemas estructurales de los LLMs: **knowledge cutoff**, **alucinaciones** y **falta de conocimiento privado**.
- Formulación matemática (Lewis et al. 2020): `P(y|x) ≈ Σ_z P(y|x,z) · P(z|x)`.
- **RAG vs. fine-tuning:** RAG añade conocimiento (barato, actualizable, citable); fine-tuning cambia comportamiento (caro, estable). Son complementarios.
- Pipeline estándar: **loader → chunker → embedder → vector DB** (offline) y **query → embed → search → re-rank → LLM** (online).
- Mide con **Recall@k, MRR, nDCG, faithfulness, answer relevance** usando frameworks como **Ragas**.
- Las decisiones críticas son: **qué embedder** (Lesson-02), **qué vector DB** (Lesson-03) y **cómo chunk-ear** (Lesson-03).
- No uses RAG para tareas creativas, matemáticas puras o cuando la latencia debe ser extrema.
- Siempre: mismo modelo de embeddings para ingesta y query; top-k pequeño; citas en la respuesta; fallback cuando no hay match.
