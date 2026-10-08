# Multi-Modal RAG: recuperación aumentada más allá del texto

## ¿Qué es?

**Multi-modal RAG** extiende el patrón clásico de Retrieval-Augmented Generation para recuperar y razonar sobre **imágenes, audio, video y texto** en una única base de conocimiento. En vez de almacenar solo chunks de texto, almacenas embeddings de todos los tipos de contenido en un **espacio semántico unificado**, de modo que una pregunta puede devolver una mezcla de párrafos, diagramas y fragmentos de video relevantes.

El modelo generativo final (un VLM como Claude Sonnet 4, GPT-4o, Gemini 2.0) recibe la pregunta junto con los resultados recuperados —incluyendo las imágenes reales, no solo descripciones— y produce una respuesta que integra todas las fuentes.

### Dos arquitecturas principales

| Enfoque | Cómo embebe imágenes | Pros | Contras |
|---|---|---|---|
| **Descripción + text-embedding** | VLM genera caption, se embebe el texto | Reutiliza stack de RAG textual; barato en query | Alto costo one-time de indexing; pierde detalle visual |
| **Embedding multimodal nativo** (CLIP, SigLIP, Nomic Embed Vision, Cohere Embed v4) | La imagen va directo al encoder visual | Preserva señal visual; permite query imagen→imagen | Requiere infra separada; el reranker debe ser multimodal |

En producción se combinan: embeddings nativos para búsqueda, y descripciones generadas en indexing como metadata adicional para filtrado y reranking.

## ¿Por qué importa?

Un sistema de **soporte técnico** que ayuda a reparar un router no puede responder solo con texto: necesita mostrar diagramas de conexión, fotos del panel trasero y clips de los indicadores LED parpadeando. Casos reales:

- **Shopify Sidekick**: busca en catálogos de productos combinando descripciones y fotos para responder "¿tienes algo parecido a esto?".
- **Mem.ai, Notion AI, Glean**: buscan en bases de notas que mezclan texto, screenshots y PDFs.
- **Servicios médicos (Nabla, Abridge)**: indexan transcripciones de consultas + imágenes clínicas.
- **Soporte de hardware (Nvidia, Dell)**: manuales técnicos con cientos de fotos de componentes.
- **E-commerce visual**: Instacart, Shopify, Amazon buscan productos con fotos del usuario.
- **Legal y contratos**: PDFs con sellos, firmas, tablas y texto que requieren interpretación conjunta.

Antes de 2024, hacer esto requería construir un pipeline a medida. Hoy existen embeddings multimodales de calidad producción (Cohere Embed v4 lanzado en 2024, Nomic Embed Vision, Voyage multimodal, SigLIP de Google) y bases vectoriales que los soportan nativamente (Qdrant, Weaviate, LanceDB, pgvector con filtros por tipo).

## ¿Cómo funciona?

### Fases del pipeline

```
INDEXING (una vez, batch)
┌─────────────┐    ┌───────────┐    ┌──────────────┐
│  Documentos │ -> │ Chunking  │ -> │ Embedding    │
│  Imágenes   │    │ + captions│    │ (unificado o │
│  Audio/Video│    │ (VLM)     │    │  por modal.) │
└─────────────┘    └───────────┘    └──────┬───────┘
                                           │
                                    ┌──────▼───────┐
                                    │ Vector DB    │
                                    │ + metadata   │
                                    └──────────────┘

QUERY (cada request)
┌───────┐  ┌──────────┐  ┌──────────┐  ┌───────────┐  ┌─────────┐
│Pregunta│->│Embedding │->│Retrieval │->│ Rerank    │->│ VLM gen │
│        │  │(same enc)│  │(ANN top-k│  │ (multimod)│  │ con     │
│        │  │          │  │ + filter)│  │           │  │ imagen  │
└───────┘  └──────────┘  └──────────┘  └───────────┘  └─────────┘
```

![Arquitectura de multi-modal RAG: embeber todo el contenido en un espacio vectorial unificado para recuperación cross-modal](https://hrcdn.net/ai-engineering/module-5/light/multimodal-lesson03-rag-architecture.svg)

### Chunking adaptado a cada modalidad

| Modalidad | Estrategia de chunking |
|---|---|
| Texto largo | Semantic chunking (LangChain `SemanticChunker`) o por secciones |
| PDF con layout | Unstructured, Marker, Mistral OCR, Reducto; conservar tablas e imágenes como chunks separados |
| Imágenes | Un chunk por imagen; opcionalmente generar sub-regiones con detección (DETR, YOLO) |
| Audio | Chunks por utterance usando diarización + VAD (pyannote, Deepgram); 15-60 s por chunk |
| Video | 1 frame por N segundos + transcripción alineada por timestamp |

### Embeddings: nativos vs. basados en caption

**Embedding multimodal nativo** (CLIP, SigLIP, Cohere Embed v4):

```python
# Cohere Embed v4 (soporta texto e imagen en el mismo espacio)
import cohere, base64
co = cohere.ClientV2()

def embed_text(text: str) -> list[float]:
    r = co.embed(texts=[text], model="embed-english-v3.0",
                 input_type="search_document", embedding_types=["float"])
    return r.embeddings.float[0]

def embed_image(path: str) -> list[float]:
    with open(path, "rb") as f:
        b64 = base64.b64encode(f.read()).decode()
    r = co.embed(images=[f"data:image/jpeg;base64,{b64}"],
                 model="embed-english-v3.0",
                 input_type="image", embedding_types=["float"])
    return r.embeddings.float[0]
```

**Caption-based** (reutiliza text embedding, útil si ya tienes stack textual):

```python
import anthropic, base64
from openai import OpenAI

claude = anthropic.Anthropic()
openai = OpenAI()

def describir_imagen(path: str) -> str:
    with open(path, "rb") as f:
        b64 = base64.b64encode(f.read()).decode()
    r = claude.messages.create(
        model="claude-3-5-haiku-20241022",   # modelo barato para indexing
        max_tokens=400,
        messages=[{"role": "user", "content": [
            {"type": "image", "source": {
                "type": "base64", "media_type": "image/jpeg", "data": b64}},
            {"type": "text", "text":
                "Describe esta imagen de forma exhaustiva para búsqueda: "
                "sujetos, colores, texto visible, acciones, contexto, estilo."}
        ]}])
    return r.content[0].text

def embed_text(text: str) -> list[float]:
    r = openai.embeddings.create(model="text-embedding-3-small", input=text)
    return r.data[0].embedding
```

### Vector store con filtros por modalidad

Usar un payload rico (modalidad, fuente, timestamp, tenant) permite filtros poderosos:

```python
from qdrant_client import QdrantClient
from qdrant_client.models import (
    VectorParams, Distance, PointStruct, Filter, FieldCondition, MatchValue,
)

qd = QdrantClient("localhost", port=6333)
qd.recreate_collection(
    "kb",
    vectors_config=VectorParams(size=1024, distance=Distance.COSINE),
)

# Indexar
qd.upsert("kb", points=[
    PointStruct(id=1, vector=embed_text("Reiniciar el router X450..."),
                payload={"type": "text", "producto": "X450", "fuente": "manual"}),
    PointStruct(id=2, vector=embed_image("panel.jpg"),
                payload={"type": "image", "producto": "X450",
                         "fuente": "foto_tecnica", "path": "panel.jpg"}),
])

# Query con filtro: solo contenido del producto X450
hits = qd.search(
    "kb",
    query_vector=embed_text("¿Cómo reinicio el router?"),
    query_filter=Filter(must=[FieldCondition(key="producto",
                                             match=MatchValue(value="X450"))]),
    limit=5,
)
```

### Retrieval híbrido: BM25 + vectorial + rerank

En producción los mejores resultados vienen de combinar:

1. **BM25 / full-text** para keywords exactos (números de parte, códigos de error).
2. **Dense retrieval** vectorial para semántica.
3. **Reranker multimodal** que puntúa (query, documento) y reordena top-50 → top-5.

Cohere **Rerank 3.5** (2024) y Voyage **rerank-2** soportan reranking multimodal.

```python
# Fusion con RRF (Reciprocal Rank Fusion)
def rrf(rankings: list[list[int]], k: int = 60) -> list[int]:
    scores = {}
    for ranking in rankings:
        for pos, doc_id in enumerate(ranking):
            scores[doc_id] = scores.get(doc_id, 0) + 1 / (k + pos + 1)
    return sorted(scores, key=scores.get, reverse=True)

bm25_ranking = buscar_bm25(query)        # [12, 7, 3, ...]
dense_ranking = buscar_dense(query)      # [7, 15, 12, ...]
fusion = rrf([bm25_ranking, dense_ranking])[:20]
reranked = cohere_rerank(query, fusion)[:5]
```

## Ejemplo con código

Sistema de **soporte técnico multimodal** completo que indexa manuales (texto), fotos de componentes y transcripciones de video tutorial, y responde preguntas devolviendo texto + imágenes citadas.

```python
import os, base64, hashlib, json
from dataclasses import dataclass
from pathlib import Path
import anthropic, cohere
from openai import OpenAI
from qdrant_client import QdrantClient
from qdrant_client.models import (
    VectorParams, Distance, PointStruct, Filter, FieldCondition, MatchValue,
)

claude = anthropic.Anthropic()
openai = OpenAI()
co = cohere.ClientV2()
qd = QdrantClient(":memory:")

COLECCION = "soporte"
qd.recreate_collection(COLECCION, vectors_config=VectorParams(
    size=1536, distance=Distance.COSINE
))

@dataclass
class Chunk:
    id: str
    tipo: str          # text | image | audio
    contenido: str     # texto o ruta
    descripcion: str   # caption para image/audio
    metadata: dict

def embed(text: str) -> list[float]:
    r = openai.embeddings.create(model="text-embedding-3-small",
                                 input=text, dimensions=1536)
    return r.data[0].embedding

def describir(image_path: str) -> str:
    """Caption de imagen con Haiku (barato) para indexing."""
    b64 = base64.b64encode(Path(image_path).read_bytes()).decode()
    r = claude.messages.create(
        model="claude-3-5-haiku-20241022", max_tokens=400,
        messages=[{"role": "user", "content": [
            {"type": "image", "source": {"type": "base64",
                "media_type": "image/jpeg", "data": b64}},
            {"type": "text", "text":
                "Describe exhaustivamente para búsqueda técnica. "
                "Si hay números de modelo o códigos de error, inclúyelos."}
        ]}])
    return r.content[0].text

def transcribir(audio_path: str) -> str:
    with open(audio_path, "rb") as f:
        r = openai.audio.transcriptions.create(
            model="whisper-1", file=f, language="es")
    return r.text

class SoporteKB:
    def __init__(self):
        self.chunks: dict[str, Chunk] = {}
        self.next_id = 0

    def _add(self, tipo: str, contenido: str, descripcion: str, meta: dict):
        cid = f"{tipo}_{self.next_id}"
        self.next_id += 1
        texto_para_embed = descripcion if tipo != "text" else contenido
        vec = embed(texto_para_embed)
        self.chunks[cid] = Chunk(cid, tipo, contenido, descripcion, meta)
        qd.upsert(COLECCION, points=[PointStruct(
            id=self.next_id, vector=vec,
            payload={"cid": cid, "tipo": tipo, **meta},
        )])

    def add_text(self, text: str, meta: dict):
        for i, para in enumerate(text.split("\n\n")):
            if len(para.strip()) > 50:
                self._add("text", para.strip(), para.strip()[:200],
                          {**meta, "parrafo": i})

    def add_image(self, path: str, meta: dict):
        self._add("image", path, describir(path), meta)

    def add_audio(self, path: str, meta: dict):
        self._add("audio", path, transcribir(path), meta)

    def retrieve(self, query: str, top_k: int = 10,
                 filtros: dict | None = None) -> list[Chunk]:
        qvec = embed(query)
        qfilter = None
        if filtros:
            qfilter = Filter(must=[FieldCondition(
                key=k, match=MatchValue(value=v)
            ) for k, v in filtros.items()])
        hits = qd.search(COLECCION, query_vector=qvec,
                         query_filter=qfilter, limit=top_k * 3)
        candidatos = [self.chunks[h.payload["cid"]] for h in hits]

        # Rerank con Cohere
        docs = [c.descripcion[:1000] for c in candidatos]
        rr = co.rerank(model="rerank-v3.5", query=query,
                       documents=docs, top_n=top_k)
        return [candidatos[r.index] for r in rr.results]

    def responder(self, pregunta: str, filtros: dict | None = None) -> dict:
        resultados = self.retrieve(pregunta, top_k=5, filtros=filtros)
        if not resultados:
            return {"respuesta": "No tengo información suficiente.",
                    "fuentes": []}

        contenido = [{"type": "text", "text":
            f"Pregunta: {pregunta}\n\nUsa el siguiente contexto. "
            f"Cita las fuentes como [n]."}]

        fuentes = []
        for i, c in enumerate(resultados, 1):
            if c.tipo == "text":
                contenido.append({"type": "text",
                    "text": f"\n[{i}] (texto, {c.metadata}): {c.contenido}"})
            elif c.tipo == "image":
                contenido.append({"type": "text",
                    "text": f"\n[{i}] (imagen, {c.metadata}): {c.descripcion}"})
                b64 = base64.b64encode(Path(c.contenido).read_bytes()).decode()
                contenido.append({"type": "image", "source": {
                    "type": "base64", "media_type": "image/jpeg", "data": b64}})
            elif c.tipo == "audio":
                contenido.append({"type": "text", "text":
                    f"\n[{i}] (audio transcrito, {c.metadata}): {c.descripcion}"})
            fuentes.append({"n": i, "tipo": c.tipo, "meta": c.metadata})

        r = claude.messages.create(
            model="claude-3-5-sonnet-20241022", max_tokens=1000,
            messages=[{"role": "user", "content": contenido}])
        return {"respuesta": r.content[0].text, "fuentes": fuentes}

# Uso
kb = SoporteKB()
kb.add_text(open("manual_x450.txt").read(), {"producto": "X450"})
for img in Path("fotos").glob("x450_*.jpg"):
    kb.add_image(str(img), {"producto": "X450"})
kb.add_audio("tutorial_reinicio.m4a", {"producto": "X450", "tema": "reinicio"})

print(kb.responder("Luz roja en el panel, ¿qué significa?",
                   filtros={"producto": "X450"}))
```

### Retrieval cross-modal avanzado

- **Hybrid retrieval** (BM25 + dense + rerank): ya cubierto arriba.
- **Query expansion**: pide al LLM que reformule la pregunta en 3 variantes antes de buscar.
- **HyDE (Hypothetical Document Embeddings)**: pide al LLM que genere una respuesta hipotética y busca con esa en vez de con la pregunta.
- **Multi-vector per document** (ColPali, ColBERT para visión): embebe cada región de la imagen por separado para matching fino.
- **Routing por modalidad**: un clasificador decide si la pregunta merece imágenes ("muéstrame...") o solo texto.

### Evaluación de multi-modal RAG

| Métrica | Qué mide | Cómo |
|---|---|---|
| Hit@k | ¿Está la fuente correcta en top-k? | Dataset etiquetado |
| MRR / NDCG | Calidad del ranking | Dataset etiquetado |
| Context relevance | ¿Los chunks recuperados son útiles? | LLM-as-judge |
| Faithfulness | ¿La respuesta se apoya en el contexto? | Ragas, DeepEval |
| Answer correctness | ¿La respuesta es correcta? | Golden set + LLM-judge |
| Image relevance | ¿Las imágenes citadas aplican? | VLM-as-judge |

## Errores comunes

- **Mezclar modelos de embedding entre indexing y query.** Si indexas con `text-embedding-3-small` y consultas con `text-embedding-ada-002`, los resultados son basura. Fija y versiona.
- **Describir cada imagen con el modelo más caro.** Para catálogos de 100k imágenes usar Sonnet en captioning es ruinoso. Usa Haiku 3.5 o Gemini Flash para captions en batch; reserva Sonnet para query time.
- **Sin filtros por metadata.** En un KB con 10 productos distintos, buscar sin `producto=X450` trae resultados cruzados. Siempre filtra.
- **Top-k demasiado grande.** Más contexto no es mejor: el LLM se confunde y la factura sube. 5-10 es el rango útil para la mayoría de apps.
- **No cachear captions.** Si re-ingestas con cada deploy pagas captioning de nuevo. Cachea por hash de archivo.
- **Olvidar fallback cuando no hay hits.** Si el filtro deja 0 resultados, responde "no encontré nada específico" en vez de alucinar.
- **No reranquear.** Dense retrieval sin reranker suele perder 20-30 puntos de precisión. Cohere Rerank 3.5 o Voyage rerank-2 son casi gratis comparados con no usarlos.
- **PDFs tratados como texto plano.** Perder las tablas y figuras es perder la mitad de la información. Usa Unstructured, Marker, Reducto o Mistral OCR que preservan layout.
- **Chunks demasiado grandes o demasiado pequeños.** 100 tokens pierde contexto; 2000 tokens diluye la señal. 300-600 tokens es un buen default; evalúa.
- **No evaluar.** Sin dataset golden no sabes si tu RAG mejora o empeora con cada cambio. Construye 50-200 pares (pregunta, respuesta_esperada, fuentes_correctas) desde el día uno.

## Resumen

- Multi-modal RAG **unifica recuperación** de texto, imágenes, audio y video en un espacio semántico común.
- Dos arquitecturas: **embeddings multimodales nativos** (Cohere Embed v4, Nomic, SigLIP, CLIP) o **caption-based** (VLM genera descripción, se embebe texto). Combínalas.
- Pipeline: **chunking adaptado por modalidad → embedding → vector DB con metadata → retrieval híbrido → rerank → VLM con imágenes citadas**.
- El VLM final (Claude Sonnet 4, GPT-4o, Gemini 2.0) debe recibir **la imagen real**, no solo su descripción, para razonar visualmente.
- **Retrieval híbrido** (BM25 + dense + rerank) supera consistentemente a dense solo. Reciprocal Rank Fusion es un patrón simple y efectivo.
- Filtros por **metadata** (producto, fuente, tenant) son críticos para precisión en bases heterogéneas.
- Costos se controlan con **caching de captions**, **modelos baratos en indexing**, y top-k acotado.
- Evalúa con **Hit@k, faithfulness, answer correctness** y VLM-as-judge para imágenes citadas. Sin evaluación continua, cada cambio es apuesta a ciegas.
