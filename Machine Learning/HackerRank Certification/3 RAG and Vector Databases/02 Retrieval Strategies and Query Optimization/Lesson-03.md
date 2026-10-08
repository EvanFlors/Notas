# Optimización de la consulta: HyDE, Multi-Query, MMR y Metadata

## ¿Qué es?

La **optimización de la consulta** (query optimization) agrupa las técnicas que **transforman la query del usuario** —o la forma en que se usa— *antes* de llegar al retriever, para mejorar el ranking final. Mientras el re-ranking actúa sobre los candidatos, la optimización de la consulta actúa sobre la **entrada** del sistema.

Las cuatro técnicas más usadas en 2026:

| Técnica | Qué hace | Cuándo brilla |
|---|---|---|
| **Query expansion** | Reescribe o enriquece la query con sinónimos / términos relacionados | Queries cortas o ambiguas |
| **HyDE** (Hypothetical Document Embeddings) | Pide al LLM que genere un documento hipotético y busca con su embedding | Dominios técnicos donde la query no se parece al corpus |
| **Multi-query** | Genera N variaciones de la query y agrega los resultados | Queries ambiguas con múltiples intents |
| **MMR** (Maximum Marginal Relevance) | Diversifica los resultados para evitar redundancia | Resúmenes, agregación, cobertura amplia |
| **Metadata filtering** | Restringe la búsqueda con filtros estructurados (fecha, tenant, tipo) | Multi-tenant, versiones, control de acceso |

## ¿Por qué importa?

El usuario raramente escribe la query ideal. Preguntas como *"¿y lo del año pasado?"* o *"explícamelo"* no tienen información suficiente para un retriever. Además, el **gap léxico** entre lo que el usuario escribe (`"se rompió el login"`) y lo que dice el corpus (`"error 401 en authentication endpoint"`) castiga al retrieval dense y sparse por igual.

- **HyDE** cierra ese gap generando texto *parecido al corpus*.
- **Multi-query** cubre múltiples formulaciones y reduce la varianza.
- **MMR** evita que los top-5 sean cinco paráfrasis del mismo párrafo.
- **Metadata filtering** reduce drásticamente el espacio de búsqueda y es obligatorio en entornos multi-tenant o regulados.

### Contexto histórico

- **1998 — Carbonell & Goldstein** proponen **MMR** para resúmenes diversificados.
- **2022 — HyDE** (Gao et al., *"Precise Zero-Shot Dense Retrieval without Relevance Labels"*): usar un LLM como *query generator*.
- **2023 — LangChain MultiQueryRetriever** populariza el patrón multi-query.
- **2023+ — Metadata filtering** se vuelve nativo en Qdrant, Weaviate, Pinecone, Milvus, pgvector.

## ¿Cómo funciona?

### Query expansion clásica

Añadir sinónimos o términos relacionados antes de buscar:

```
Query original: "coche eléctrico barato"
Expandida:      "coche eléctrico barato OR auto EV económico OR vehículo eléctrico asequible"
```

Herramientas: WordNet, modelos T5 entrenados en query expansion, o un LLM con prompt.

### HyDE (Hypothetical Document Embeddings)

Idea: en lugar de buscar con el embedding de la query, pedimos al LLM que **genere un documento hipotético que respondería a la query**, y buscamos con el embedding de ese documento.

```
1. query  = "¿cómo configuro OAuth2 en nuestra API?"
2. hyp_doc = LLM("Genera un fragmento de documentación técnica que
                  responda: ¿cómo configuro OAuth2 en nuestra API?")
3. v_hyp   = embed(hyp_doc)
4. retrieve nearest neighbors(v_hyp)
```

El documento hipotético puede ser **factualmente incorrecto** —no importa— porque solo lo usamos para su **estructura y vocabulario**, que se parece mucho más al corpus que la pregunta original.

Funciona especialmente bien cuando:

- La query es corta y el corpus es largo y técnico.
- El retrieval dense pierde recall por el gap léxico query-passage.

Limitaciones: añade **1 llamada extra al LLM** (coste y latencia).

### Multi-query retrieval

Pedimos al LLM N reformulaciones de la query y agregamos los resultados (unión o RRF):

```
query = "problemas con login"
→ LLM genera:
    1. "errores al iniciar sesión"
    2. "fallos de autenticación"
    3. "no puedo entrar a mi cuenta"
→ ejecutamos retrieve con cada una
→ fusionamos con RRF
```

Reduce la **varianza del fraseo** del usuario a costa de 3-5× más búsquedas (que son baratas).

### MMR: Maximum Marginal Relevance

Fórmula (Carbonell & Goldstein, 1998):

```
MMR = argmax [ λ · sim(d, q)  −  (1 − λ) · max sim(d, dⱼ) ]
      d∈R\S                       dⱼ∈S
```

- `R`: candidatos; `S`: seleccionados hasta ahora.
- `sim(d, q)`: relevancia respecto a la query.
- `max sim(d, dⱼ)`: máxima similitud con lo ya elegido (penaliza redundancia).
- `λ ∈ [0, 1]`: trade-off relevancia (λ=1) vs. diversidad (λ=0). Típico: **0.5-0.7**.

Elige iterativamente el documento que **más añade** respecto a la query y **menos repite** respecto a lo ya seleccionado.

### Metadata filtering

Al indexar, cada chunk guarda metadata:

```json
{
  "content": "...",
  "metadata": {
    "tenant_id": "acme",
    "doc_type": "policy",
    "lang": "es",
    "created_at": "2025-03-15",
    "version": 7
  }
}
```

En la consulta, se filtra **antes** o **durante** la búsqueda ANN:

```
WHERE tenant_id = 'acme' AND doc_type = 'policy' AND created_at >= '2024-01-01'
```

Esto es **obligatorio** en entornos multi-tenant, elimina ruido, y suele ser la mejora de precisión más barata.

### Combinando todo: pipeline moderno

```
query ─► metadata filter ─► multi-query (3 variantes)
          │                     │
          │                     ├─► retrieve hybrid (dense + BM25) top-50 cada una
          │                     │
          └─► RRF fusión ──────┤
                                │
                                ├─► cross-encoder rerank → top-10
                                │
                                └─► MMR diversificar → top-5 al LLM
```

## Ejemplo con código

### HyDE con OpenAI + embeddings

```python
# pip install openai
from openai import OpenAI
import numpy as np

client = OpenAI()

def hyde_retrieve(query, doc_embeddings, docs, top_k=5):
    # 1) Documento hipotético
    completion = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{
            "role": "user",
            "content": f"Escribe un fragmento de documentación técnica "
                       f"(2-3 frases) que responda: {query}"
        }],
    )
    hyp_doc = completion.choices[0].message.content

    # 2) Embedding del documento hipotético
    emb = client.embeddings.create(
        model="text-embedding-3-small",
        input=hyp_doc,
    ).data[0].embedding
    emb = np.array(emb)
    emb /= np.linalg.norm(emb)

    # 3) Búsqueda nearest neighbor
    sims = doc_embeddings @ emb
    top = np.argsort(sims)[-top_k:][::-1]
    return [(float(sims[i]), docs[i]) for i in top]
```

### Multi-query con LangChain

```python
# pip install langchain langchain-openai
from langchain.retrievers.multi_query import MultiQueryRetriever
from langchain_openai import ChatOpenAI
from langchain_community.vectorstores import Chroma

base_retriever = Chroma(...).as_retriever(search_kwargs={"k": 20})
llm = ChatOpenAI(model="gpt-4o-mini", temperature=0)

retriever = MultiQueryRetriever.from_llm(
    retriever=base_retriever,
    llm=llm,
    include_original=True,         # también usa la query original
)

docs = retriever.invoke("problemas con el login")
# Internamente genera ~3 variantes, consulta cada una y deduplica
```

### MMR a mano (sobre embeddings normalizados)

```python
import numpy as np

def mmr(query_emb, doc_embs, docs, k=5, lambda_=0.6):
    sims_q = doc_embs @ query_emb          # relevancia
    selected, remaining = [], list(range(len(docs)))

    for _ in range(min(k, len(docs))):
        if not selected:
            idx = int(np.argmax(sims_q[remaining]))
        else:
            sims_sel = doc_embs[remaining] @ doc_embs[selected].T  # redundancia
            max_sim_sel = sims_sel.max(axis=1)
            score = lambda_ * sims_q[remaining] - (1 - lambda_) * max_sim_sel
            idx = int(np.argmax(score))

        chosen = remaining.pop(idx)
        selected.append(chosen)

    return [docs[i] for i in selected]
```

LangChain, Qdrant y pgvector exponen MMR nativo: `.max_marginal_relevance_search(query, k=5, lambda_mult=0.6)`.

### Metadata filtering en Qdrant

```python
from qdrant_client import models

hits = client.query_points(
    collection_name="docs",
    query=query_vector,
    query_filter=models.Filter(
        must=[
            models.FieldCondition(key="tenant_id", match=models.MatchValue(value="acme")),
            models.FieldCondition(key="doc_type",  match=models.MatchValue(value="policy")),
            models.FieldCondition(
                key="created_at",
                range=models.Range(gte="2024-01-01"),
            ),
        ]
    ),
    limit=10,
)
```

Equivalente en Weaviate:

```python
from weaviate.classes.query import Filter

response = collection.query.near_vector(
    near_vector=qv,
    filters=Filter.by_property("tenant_id").equal("acme")
          & Filter.by_property("doc_type").equal("policy"),
    limit=10,
)
```

## Errores comunes

- **Aplicar HyDE a dominios donde no hay gap léxico.** Si el usuario escribe exactamente como el corpus (FAQs internas), HyDE añade latencia sin mejorar recall.
- **Multi-query sin deduplicar.** Si tres variantes devuelven los mismos top-10, acabas con contexto redundante y nada nuevo. Usa RRF o unión + MMR.
- **MMR con λ demasiado bajo.** λ=0 solo diversifica y pierde relevancia; λ=0.3 ya trae ruido. Empieza con 0.5-0.7.
- **No filtrar por metadata y recuperar chunks de otros tenants.** Problema de seguridad y de ruido: el vector más cercano puede pertenecer a otro cliente. Siempre filtra por `tenant_id` **antes** del ANN.
- **Filtros post-hoc en vez de nativos.** Recuperar top-100 y luego hacer `filter()` en Python mata la precisión: el ANN ya descartó los documentos realmente relevantes. Usa el `filter` del vector store.
- **Olvidar actualizar los índices de metadata.** Si filtras por un campo no indexado, el vector store hace *scan* lineal → lento con millones de chunks. Crea índices (`payload index` en Qdrant, `filterable: true` en Weaviate).
- **Query expansion con sinónimos malos.** Expandir `"Python"` con `"serpiente"` arruina el retrieval. Si usas un LLM, dale contexto del dominio.
- **Cadenas demasiado largas.** HyDE + multi-query + rerank + MMR añade 4 pasos y 2-3 llamadas al LLM. Mide: a veces hybrid + rerank es suficiente.

## Resumen

- La **query del usuario** rara vez es la mejor consulta para el retriever: optimizarla sube la calidad sin tocar el índice.
- **HyDE** (2022): el LLM genera un documento hipotético y buscamos con su embedding. Cierra el gap léxico query ↔ passage.
- **Multi-query**: generar N reformulaciones y fusionar (RRF) reduce la varianza del fraseo.
- **MMR** (Carbonell 1998): equilibra relevancia (`λ·sim(d,q)`) y diversidad (`−(1−λ)·max sim(d,dⱼ)`); típico λ=0.5-0.7.
- **Metadata filtering**: filtros estructurados (tenant, fecha, tipo) son la mejora de precisión más barata y obligatoria en producción.
- Patrón pro: `metadata filter → multi-query hybrid → RRF → cross-encoder rerank → MMR → LLM`.
- Herramientas: `langchain.retrievers.MultiQueryRetriever`, soporte nativo de MMR en Qdrant / pgvector / LangChain, filtros nativos en todos los vector stores modernos.
- Mide siempre: cada paso añade latencia y coste; a veces menos es más.
