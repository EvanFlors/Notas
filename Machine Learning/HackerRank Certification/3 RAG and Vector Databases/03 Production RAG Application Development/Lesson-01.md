# Metadata y filtrado en RAG de producción

## ¿Qué es?

En un RAG real los usuarios no quieren *"todo lo que se parece"*; quieren **el documento correcto, para su rol, de su período de tiempo y de su fuente autorizada**. La **búsqueda por similitud sola** devuelve un conjunto demasiado amplio: una query de un analista de finanzas puede traer de vuelta un contrato legal confidencial o un memo irrelevante del 2019.

**Metadata filtering** resuelve ese problema añadiendo **información estructurada** a cada chunk indexado — fecha, autor, departamento, tipo de documento, nivel de acceso — y aplicando filtros booleanos o rangos **antes** o **durante** la búsqueda vectorial.

> **Separación conceptual:** el **embedding** captura *qué dice* el documento. La **metadata** captura *qué es, de dónde viene y quién puede verlo*. Ambas conviven en el mismo registro del vector store.

### Contenido vs. metadata

```python
# Contenido (va al embedding)
content = "Nuestros ingresos trimestrales crecieron 15% comparado con el año pasado..."

# Metadata (va al filtro estructurado)
metadata = {
    "document_type": "financial_report",
    "quarter": "Q3_2024",
    "department": "finance",
    "access_level": "internal",
    "created_date": "2024-10-15",
    "author": "finance_team",
    "file_type": "pdf",
    "source": "q3_report_2024.pdf",
    "page": 7,
    "chunk_id": "q3_report_2024_p07_c03"
}
```

### Tipos de metadata que vas a necesitar

| Categoría | Campos típicos | Para qué sirve |
|---|---|---|
| **Temporal** | `created_date`, `modified_date`, `valid_until`, `version` | Recencia, expiración de políticas |
| **Fuente** | `author`, `department`, `source`, `file_type` | Atribución, routing |
| **Acceso** | `access_level`, `permissions`, `region` | Compliance, RBAC |
| **Contenido** | `language`, `topic`, `tags`, `quality_score` | Enriquecer el ranking |
| **Trazabilidad** | `chunk_id`, `parent_doc_id`, `page`, `offset` | Citas, debugging |

## ¿Por qué importa?

Un RAG sin metadata es un **buscador de biblioteca sin fichero**: puede encontrar libros parecidos, pero no sabe cuál es la edición vigente ni si tienes permiso para leerlo.

- **Precisión:** elimina ruido antes de calcular similitud. Si el usuario pregunta sobre política de vacaciones *vigente*, no quieres el PDF de 2017.
- **Compliance:** en finanzas, salud o legal, mostrar un documento al rol equivocado es una multa regulatoria. RBAC a nivel de retrieval es **obligatorio**, no opcional.
- **Performance:** filtrar primero reduce el espacio de búsqueda. Pasar de 10M chunks a 50K antes del ANN acelera latencia 10-100x.
- **Personalización:** el mismo índice sirve a mil equipos si cada query se filtra por tenant, idioma o región.
- **Explicabilidad:** la metadata viaja con el chunk hasta la respuesta final, lo que permite citar fuente, fecha y versión.

Sin estos filtros, un RAG se degrada rápido: los usuarios lo abandonan después de ver resultados contradictorios, obsoletos o fuera de su contexto.

## ¿Cómo funciona?

El pipeline de ingesta y recuperación con metadata se parece a:

```
┌─────────────────────────────────────────────────────────┐
│  Documento crudo (PDF, HTML, DOCX)                      │
│         ↓                                               │
│  Document loader (Unstructured.io / PyMuPDF)            │
│         ↓                                               │
│  Metadata extraction (fecha, autor, página, tipo)       │
│         ↓                                               │
│  Chunking (recursive / semantic / sentence-window)      │
│         ↓                                               │
│  Deduplicación (hash de contenido)                      │
│         ↓                                               │
│  Embedding model → vector                               │
│         ↓                                               │
│  Upsert en vector store (vector + metadata estructurada)│
└─────────────────────────────────────────────────────────┘
```

En **query time**:

```
query → [intent routing] → filtros estructurados + embedding
                                     ↓
                        vector_store.search(vec, filter=...)
                                     ↓
                                re-ranking
                                     ↓
                        prompt con contexto + citas
```

### Data ingestion pipelines

Un pipeline de ingestión robusto no es solo *"cargar PDF y chunkear"*. Debe:

1. **Detectar el tipo de archivo** y usar el loader correcto.
2. **Extraer metadata** del encabezado del archivo (autor PDF, fecha de modificación, tags DOCX).
3. **Normalizar texto** (unicode, saltos de línea, encodings).
4. **Chunkear preservando estructura** (headings, tablas, listas).
5. **Enriquecer metadata** con campos derivados (idioma detectado, longitud, hash).
6. **Deduplicar** chunks idénticos entre versiones.
7. **Hacer upsert idempotente** (misma clave = reemplazo, no duplicado).

### Document loaders

| Formato | Librería recomendada | Qué extrae bien | Puntos débiles |
|---|---|---|---|
| **PDF** | PyMuPDF (`fitz`) | Texto, páginas, metadata, imágenes | PDFs escaneados (requiere OCR) |
| **PDF complejo** | Unstructured.io | Tablas, layout, OCR integrado | Más lento, más dependencias |
| **HTML** | BeautifulSoup / Unstructured | Texto limpio, enlaces, estructura | JS-rendered sites requieren Playwright |
| **DOCX** | `python-docx` / Unstructured | Párrafos, estilos, tablas | Imágenes embebidas |
| **Markdown** | `markdown-it-py` + LangChain | Headings, bloques de código | - |
| **PPTX** | `python-pptx` / Unstructured | Texto por slide, notas | Diagramas |
| **XLSX / CSV** | `pandas` / `openpyxl` | Tablas estructuradas | Fórmulas, celdas combinadas |

### Chunking strategies

| Estrategia | Cómo divide | Ventaja | Desventaja | Cuándo usar |
|---|---|---|---|---|
| **Fixed-size** | N tokens con overlap | Simple, predecible | Corta frases | Baseline / texto homogéneo |
| **Recursive** | Jerarquía de separadores (`\n\n`, `\n`, `. `, ` `) | Respeta párrafos | No semántica | **Default razonable** |
| **Semantic** | Agrupa frases cuyos embeddings son similares | Chunks temáticamente coherentes | Más caro (embeddings extra) | Documentos largos narrativos |
| **Sentence-window** | 1 frase central + N vecinas como contexto | Precisión + contexto en respuesta | Más chunks indexados | QA factual |
| **Parent-document** | Indexa chunks pequeños, retorna el padre grande | Mejor contexto al LLM | Infra más compleja | Respuestas que requieren contexto amplio |
| **Document-based** | Un chunk = una sección/heading | Preserva estructura semántica | Tamaños muy variables | Markdown, documentación técnica |

### Metadata extraction

La metadata viene de tres fuentes:

- **Intrínseca al archivo:** autor, fecha de creación, aplicación que lo generó.
- **Derivada del contenido:** idioma detectado, entidades (NER), tópicos (LDA/BERTopic), resumen.
- **Inyectada por tu negocio:** `department`, `access_level`, `tenant_id`, `project_id`.

### Incremental indexing

Reindexar todo cada vez que cambia un documento es inviable. El patrón es:

1. Calcular un **hash estable** por chunk (`sha256(content + source + chunk_index)`).
2. Guardar el hash como campo en el vector store.
3. En cada ingesta: comparar hashes nuevos vs. los existentes.
   - **Nuevo:** upsert.
   - **Igual:** skip.
   - **Hash viejo ya no existe en el documento:** delete (el chunk fue removido).

LangChain expone esto con `SQLRecordManager` + `index()`; LlamaIndex con `IngestionPipeline` + `DocstoreStrategy.UPSERTS`.

### Deduplicación

Dos fuentes comunes de duplicados:

- **Mismo contenido en varios archivos** (una política copiada en 10 wikis).
- **Overlap entre chunks** del mismo documento.

Soluciones:

- **Hash exacto** del `content.strip().lower()`.
- **MinHash / SimHash** para near-duplicates (umbral ~0.9).
- **Dedup por embedding** (cosine > 0.98) — más caro, pero captura paráfrasis.

### Source attribution y citation

Cada chunk debe cargar lo mínimo para citar: `source` (archivo), `page` (si aplica), `url` (si vino de web), `chunk_id`. En el prompt final se le pide al LLM que **cite por `[source:page]`** y en la UI se renderizan como links clicables al documento original.

### Prompt templates para RAG (grounding)

El prompt debe **forzar** al modelo a responder solo con el contexto:

```
Eres un asistente que responde preguntas USANDO EXCLUSIVAMENTE el contexto provisto.
Reglas:
1. Si la respuesta no está en el contexto, responde literalmente: "No tengo información suficiente para responder."
2. Cita cada afirmación con [source:page].
3. No inventes datos, nombres, fechas ni cifras.
4. Si el contexto es contradictorio, señálalo.

Contexto:
{context}

Pregunta: {query}

Respuesta (con citas):
```

### LlamaIndex vs. LangChain para RAG

| Dimensión | LangChain | LlamaIndex |
|---|---|---|
| Enfoque | Framework general de LLM apps | Especializado en RAG / indexación |
| Chunking | `RecursiveCharacterTextSplitter`, semantic | Node parsers con jerarquía nativa |
| Routing | LCEL, `RunnableBranch` | `RouterQueryEngine` |
| Metadata | Diccionario libre | Nodes tipados, propagación automática |
| Agentes | Muy maduro | Query engines componibles |
| Curva | Más APIs, más flexibilidad | Más opinado, menos boilerplate |

Pragmático: **LlamaIndex** para RAG puro (indexación, routing, re-ranking); **LangChain** si tu app mezcla RAG con tools, agentes, memoria y orquestación.

## Ejemplo con código

Pipeline completo: **FastAPI + Unstructured.io + chunking semántico + Qdrant + filtros por metadata + prompt con citas.**

```python
# requirements:
#   fastapi uvicorn qdrant-client sentence-transformers
#   unstructured[pdf] pymupdf langchain langchain-openai
#   openai pydantic

import hashlib
import uuid
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any

from fastapi import FastAPI, UploadFile, HTTPException
from pydantic import BaseModel
from qdrant_client import QdrantClient
from qdrant_client.models import (
    Distance, VectorParams, PointStruct,
    Filter, FieldCondition, MatchValue, Range,
)
from sentence_transformers import SentenceTransformer
from unstructured.partition.auto import partition
from langchain_experimental.text_splitter import SemanticChunker
from langchain_openai import OpenAIEmbeddings, ChatOpenAI

# ------------------------------------------------------------
# Infra
# ------------------------------------------------------------
EMBED_MODEL = SentenceTransformer("intfloat/multilingual-e5-base")
EMBED_DIM = 768
COLLECTION = "docs_prod"

qdrant = QdrantClient(host="localhost", port=6333)
if COLLECTION not in [c.name for c in qdrant.get_collections().collections]:
    qdrant.create_collection(
        collection_name=COLLECTION,
        vectors_config=VectorParams(size=EMBED_DIM, distance=Distance.COSINE),
    )

llm = ChatOpenAI(model="gpt-4o-mini", temperature=0)

# ------------------------------------------------------------
# Ingesta: loader + chunking semantico + metadata + dedup
# ------------------------------------------------------------
def load_document(path: str) -> list[dict[str, Any]]:
    """Usa Unstructured.io para parsear PDF/DOCX/HTML preservando layout."""
    elements = partition(filename=path)
    pages = []
    for el in elements:
        pages.append({
            "text": str(el),
            "category": el.category,                  # Title, NarrativeText, Table
            "page_number": el.metadata.page_number,
            "source": Path(path).name,
        })
    return pages


def semantic_chunking(pages: list[dict]) -> list[dict]:
    """Chunking semantico: agrupa frases por similitud de embedding."""
    splitter = SemanticChunker(
        OpenAIEmbeddings(model="text-embedding-3-small"),
        breakpoint_threshold_type="percentile",
        breakpoint_threshold_amount=95,
    )
    chunks = []
    for p in pages:
        for i, text in enumerate(splitter.split_text(p["text"])):
            chunks.append({
                "text": text,
                "source": p["source"],
                "page_number": p["page_number"],
                "chunk_index": i,
            })
    return chunks


def chunk_hash(c: dict) -> str:
    key = f"{c['source']}|{c['page_number']}|{c['chunk_index']}|{c['text']}"
    return hashlib.sha256(key.encode("utf-8")).hexdigest()


def ingest(path: str, department: str, access_level: str) -> int:
    """Pipeline completo: load -> chunk -> dedup -> embed -> upsert."""
    pages = load_document(path)
    chunks = semantic_chunking(pages)

    # Deduplicacion por hash
    seen_hashes: set[str] = set()
    existing = {p.payload["chunk_hash"] for p in
                qdrant.scroll(COLLECTION, limit=100_000)[0]}

    points = []
    for c in chunks:
        h = chunk_hash(c)
        if h in seen_hashes or h in existing:
            continue
        seen_hashes.add(h)

        vec = EMBED_MODEL.encode(f"passage: {c['text']}").tolist()
        points.append(PointStruct(
            id=str(uuid.uuid4()),
            vector=vec,
            payload={
                "content": c["text"],
                "source": c["source"],
                "page": c["page_number"],
                "chunk_index": c["chunk_index"],
                "chunk_hash": h,
                "department": department,
                "access_level": access_level,
                "created_date": datetime.utcnow().isoformat(),
                "lang": "es",
            },
        ))

    if points:
        qdrant.upsert(collection_name=COLLECTION, points=points)
    return len(points)


# ------------------------------------------------------------
# Query: intent routing + filtros + re-rank + prompt con citas
# ------------------------------------------------------------
def detect_intent_filters(query: str, user: dict) -> dict:
    """Mapea palabras clave de la query a filtros estructurados."""
    q = query.lower()
    filters = {"access_level_in": _allowed_levels(user["access_level"])}

    if any(w in q for w in ["ultimo", "reciente", "actual", "nuevo"]):
        filters["date_after"] = (datetime.utcnow() - timedelta(days=30)).isoformat()
    if any(w in q for w in ["politica", "procedimiento", "guia"]):
        filters["document_type"] = "policy"
    if any(w in q for w in ["empleado", "nomina", "beneficio"]):
        filters["department"] = "hr"
    elif any(w in q for w in ["presupuesto", "ingreso", "finanzas"]):
        filters["department"] = "finance"
    return filters


def _allowed_levels(level: str) -> list[str]:
    hierarchy = {"public": ["public"],
                 "internal": ["public", "internal"],
                 "confidential": ["public", "internal", "confidential"]}
    return hierarchy.get(level, ["public"])


def build_qdrant_filter(f: dict) -> Filter:
    must: list = []
    if "department" in f:
        must.append(FieldCondition(key="department",
                                   match=MatchValue(value=f["department"])))
    if "access_level_in" in f:
        must.append(FieldCondition(key="access_level",
                                   match=MatchValue(any=f["access_level_in"])))
    if "date_after" in f:
        must.append(FieldCondition(key="created_date",
                                   range=Range(gte=f["date_after"])))
    return Filter(must=must)


def search_with_fallback(query: str, user: dict, top_k: int = 5) -> list[dict]:
    """Multi-stage: estricto -> relaja fecha -> solo publico."""
    vec = EMBED_MODEL.encode(f"query: {query}").tolist()
    stages = [
        detect_intent_filters(query, user),
        {k: v for k, v in detect_intent_filters(query, user).items()
         if k != "date_after"},
        {"access_level_in": ["public"]},
    ]
    for stage, f in enumerate(stages, 1):
        hits = qdrant.search(
            collection_name=COLLECTION,
            query_vector=vec,
            query_filter=build_qdrant_filter(f),
            limit=top_k * 4,          # recall alto para re-rank
        )
        if hits:
            return [{**h.payload, "score": h.score, "stage": stage}
                    for h in hits[:top_k]]
    return []


RAG_PROMPT = """Eres un asistente corporativo. Responde EXCLUSIVAMENTE con la
informacion del contexto. Si la respuesta no esta, responde literalmente:
"No tengo informacion suficiente para responder."

Reglas:
- Cita cada afirmacion con [source:page].
- No inventes cifras, nombres ni fechas.
- Si el contexto es contradictorio, senalalo.

Contexto:
{context}

Pregunta: {query}

Respuesta (con citas):
"""


def answer(query: str, user: dict) -> dict:
    chunks = search_with_fallback(query, user, top_k=5)
    if not chunks:
        return {"answer": "No tengo informacion suficiente para responder.",
                "citations": []}

    context = "\n\n".join(
        f"[{c['source']}:{c['page']}] {c['content']}" for c in chunks
    )
    prompt = RAG_PROMPT.format(context=context, query=query)
    response = llm.invoke(prompt).content

    return {
        "answer": response,
        "citations": [{"source": c["source"], "page": c["page"],
                       "score": c["score"]} for c in chunks],
    }


# ------------------------------------------------------------
# FastAPI
# ------------------------------------------------------------
app = FastAPI(title="RAG prod demo")


class QueryIn(BaseModel):
    query: str
    department: str
    access_level: str


@app.post("/ingest")
async def ingest_endpoint(file: UploadFile, department: str, access_level: str):
    tmp = Path(f"/tmp/{file.filename}")
    tmp.write_bytes(await file.read())
    n = ingest(str(tmp), department, access_level)
    return {"ingested_chunks": n}


@app.post("/query")
def query_endpoint(payload: QueryIn):
    if payload.access_level not in {"public", "internal", "confidential"}:
        raise HTTPException(400, "access_level invalido")
    user = {"department": payload.department,
            "access_level": payload.access_level}
    return answer(payload.query, user)
```

**Qué observar:**

- `partition()` de Unstructured.io hace todo el trabajo sucio de PDF/DOCX/HTML con un solo API.
- `SemanticChunker` genera chunks temáticamente coherentes en lugar de cortar frases.
- `chunk_hash` + comparación con los hashes ya indexados garantiza **upsert idempotente**.
- El filtro de Qdrant se construye **a partir del rol del usuario**, no se confía en el cliente.
- El prompt obliga al grounding con una frase literal de rechazo.

## Errores comunes

- **No deduplicar chunks.** Dos copias del mismo contrato en wikis distintas aparecen dos veces en la respuesta y el LLM las trata como fuentes independientes, inflando la "confianza".
- **Perder metadata al chunkear.** Si cortas texto sin propagar `source`, `page` y `author`, pierdes la capacidad de citar. Siempre heredar la metadata del documento padre en cada chunk hijo.
- **No refrescar el índice cuando los documentos cambian.** Políticas que se actualizan quedan sombra'd por versiones viejas. Resuelve con incremental indexing (`SQLRecordManager` en LangChain, `IngestionPipeline` en LlamaIndex) y campo `version`.
- **Embedding model mismatch entre ingesta y query.** Si indexaste con `text-embedding-ada-002` y buscas con `e5-base`, los vectores viven en espacios distintos y el recall colapsa. Fijar el modelo en config y versionarlo con el índice.
- **No citar fuentes.** Un RAG sin citas es indistinguible de un LLM alucinando. Las citas también permiten al usuario auditar y corregir.
- **Confiar en metadata provista por el cliente.** `access_level` nunca debe venir del request del usuario; sale del token de sesión o del IdP.
- **Schemas inconsistentes.** `dept: "finance"` vs. `department: "Finance"` → filtros silenciosamente vacíos. Normaliza en ingesta (lowercase, nombres canónicos) y valida con Pydantic.
- **Over-filtering.** Filtros estrictos devuelven cero resultados. Siempre tener fallback multi-stage que relaja progresivamente.
- **Chunking fijo sin overlap.** Pierdes contexto entre fronteras. Mínimo 10-20% de overlap para `fixed-size`, o usa `recursive`/`semantic`.
- **Indexar texto sin normalizar.** Unicode mixto, saltos `\r\n` de Windows, espacios no-breaking rompen la deduplicación por hash. Normaliza antes de hashear.

## Resumen

- **Metadata filtering** es lo que convierte un demo de RAG en un sistema de producción: precisión, compliance, personalización y explicabilidad.
- El pipeline de ingesta tiene siete pasos: **load → extraer metadata → normalizar → chunkear → deduplicar → embedding → upsert idempotente**.
- Elige la **chunking strategy** según el documento: `recursive` como default, `semantic` para texto narrativo, `sentence-window` para QA factual, `parent-document` para respuestas con contexto amplio.
- **Unstructured.io** y **PyMuPDF** cubren casi todos los formatos que te vas a encontrar.
- Aplica filtros **antes** del ANN para reducir espacio de búsqueda y respetar RBAC.
- Usa **intent routing** para traducir queries naturales a filtros estructurados automáticamente.
- Implementa **multi-stage filtering** para evitar respuestas vacías cuando los filtros estrictos no matchean nada.
- **Incremental indexing** con hashes evita reindexar todo y mantiene el índice fresco.
- **Dedup** por hash exacto + near-duplicate detection (MinHash) para evitar inflar el ranking.
- El **prompt** debe forzar grounding: *"responde solo con el contexto; si no está, di que no sabes"* + citas obligatorias.
- **LlamaIndex** para RAG puro, **LangChain** para apps que mezclan RAG con agentes y tools.
- Nunca confíes en metadata que llegue del cliente: `access_level` sale del IdP, no del request body.
