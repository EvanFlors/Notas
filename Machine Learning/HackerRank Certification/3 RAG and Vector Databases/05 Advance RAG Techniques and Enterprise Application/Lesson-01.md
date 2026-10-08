# RAG Avanzado: Hybrid, Multi-modal y GraphRAG

## ¿Qué es?

**RAG avanzado** es la evolución del patrón clásico "embed → retrieve → generate" hacia arquitecturas que combinan múltiples señales de recuperación (densa, dispersa, grafos), múltiples modalidades (texto, imagen, tablas) y múltiples pasos de razonamiento (planeación, re-ranking, verificación). El RAG ingenuo (vector search + LLM) sirve para prototipos; en producción empresarial casi nunca es suficiente.

La diferencia clave respecto al RAG básico es el **número de estrategias simultáneas** y la **capacidad del sistema de decidir** cuál usar según la consulta.

| Dimensión | Naive RAG | Advanced RAG | Agentic RAG |
|---|---|---|---|
| Recuperación | Solo vectorial densa | Híbrida (densa + BM25), re-ranking, HyDE | El agente elige herramientas y queries |
| Modalidades | Solo texto | Texto + imagen + tabla (CLIP, ColPali) | Multimodal + llamadas a APIs |
| Decisión | Siempre recupera | Reflexión (Self-RAG, CRAG) | Planeación multi-paso + loops |
| Estructura del índice | Chunks planos | Jerarquía (RAPTOR), grafo (GraphRAG) | Memoria dinámica + sub-grafos |
| Evaluación | "Parece funcionar" | Ragas, LangSmith, golden set | A/B + traces + juicio LLM |
| Costo/latencia | Bajo | Medio | Alto (pero mejor precisión) |

### GraphRAG vs. Vector RAG

**Microsoft GraphRAG (2024)** cambió el juego para preguntas globales ("resume los temas principales del corpus"). En lugar de buscar chunks aislados, construye un grafo de entidades y relaciones, lo clusteriza en comunidades y genera resúmenes jerárquicos.

| Aspecto | Vector RAG | GraphRAG |
|---|---|---|
| Unidad base | Chunk de texto | Entidad + relación + comunidad |
| Buena en preguntas | Específicas ("¿qué dijo X sobre Y?") | Globales ("¿cuáles son los temas?") |
| Costo de indexación | Barato (solo embeddings) | Caro (LLM extrae entidades/relaciones) |
| Latencia de query | Baja (ms) | Media-alta (traverse + LLM) |
| Explicabilidad | Chunks fuente | Camino en el grafo (auditable) |
| Herramienta típica | Pinecone, Weaviate | Neo4j + Microsoft GraphRAG, LlamaIndex KG |

## ¿Por qué importa?

En empresas, el RAG ingenuo falla en escenarios reales:

- **"Pregunta: ¿Cuál es la política PTO-2024-Q3-POLICY?"** → la búsqueda densa pierde el match exacto porque el ID es un token raro. BM25 lo encuentra al instante.
- **"Pregunta: Resume la estrategia 2024 del CEO"** → ningún chunk individual contiene la respuesta; se necesita un resumen global del corpus (GraphRAG).
- **"Pregunta: ¿Qué dice el diagrama de la página 42?"** → el texto no describe la imagen; se necesita embedding visual (CLIP, ColPali).
- **"Pregunta: ¿Cuánta deuda tenemos?" (usuario del equipo de marketing)** → sin filtros de permisos, el RAG filtra información financiera confidencial.

Las apuestas son altas: una respuesta incorrecta puede ser una decisión regulatoria mal informada, un *data leak* entre tenants, o una alucinación citando una política inexistente. Por eso aparece la segunda razón por la que esto importa: **evaluación medible** (Ragas, LangSmith) y **gobernanza** (RBAC, PII, auditoría).

## ¿Cómo funciona?

### Recuperación híbrida (denso + disperso)

- **Denso (embeddings):** captura significado semántico ("vacaciones" ≈ "PTO"). Falla con IDs, códigos, números.
- **Disperso (BM25):** basado en TF-IDF con normalización por longitud. Perfecto para términos exactos. Falla con sinónimos.
- **Fusión:** típicamente **Reciprocal Rank Fusion (RRF)** o combinación lineal con normalización min-max / percentil.

```
score_hybrid(d) = α · norm(score_dense) + (1-α) · norm(score_bm25)
```

Un `α` típico es 0.6 para dominios conversacionales y 0.3-0.4 para dominios con mucho vocabulario técnico o códigos.

### Multi-modal RAG (texto + imagen)

Dos estrategias:

1. **Shared embedding space (CLIP, SigLIP, ColPali):** texto e imagen se proyectan en el mismo espacio vectorial. Una query de texto encuentra imágenes relevantes directamente.
2. **Caption + text embedding:** un VLM (GPT-4V, Claude Vision) genera descripción textual de la imagen, se embebe como texto. Más barato en query, pero pierde señal visual fina.

Para documentos complejos (PDFs con diagramas, tablas), **ColPali / ColQwen2** representa cada página como múltiples vectores (uno por patch) y rinde mejor que OCR + chunking.

### GraphRAG (pipeline)

1. **Extracción de entidades y relaciones** con un LLM sobre cada chunk.
2. **Construcción del grafo de conocimiento** (nodos = entidades, aristas = relaciones).
3. **Clustering en comunidades** (algoritmo de Leiden).
4. **Resúmenes jerárquicos por comunidad** generados con LLM.
5. **Query:**
   - *Local search:* parte de entidades mencionadas en la query → traverse → chunks relevantes.
   - *Global search:* map-reduce sobre resúmenes de comunidades.

### Patrones adicionales

- **HyDE (Hypothetical Document Embeddings):** el LLM genera una respuesta hipotética a la query, se embebe esa respuesta en vez de la query cruda. Útil cuando la query es corta y los documentos son largos.
- **RAPTOR:** construye un árbol jerárquico recursivo clusterizando y resumiendo chunks. Permite recuperar a diferentes niveles de abstracción.
- **Multi-query / RAG-Fusion:** el LLM reescribe la query en N variantes, se recuperan N listas y se fusionan con RRF.
- **Re-ranking:** después de recuperar top-50, un cross-encoder (BGE-reranker, Cohere Rerank) reordena a top-5. Mejora precision@k significativamente.

## Ejemplo con código

### 1. Retrieval híbrido con RRF

```python
from __future__ import annotations
from dataclasses import dataclass
from typing import List, Dict
import numpy as np
from rank_bm25 import BM25Okapi
from sentence_transformers import SentenceTransformer

@dataclass
class Doc:
    doc_id: str
    text: str
    tenant_id: str
    metadata: Dict

class HybridRetriever:
    """Combina búsqueda densa (embeddings) y dispersa (BM25) con RRF.

    RRF es resistente a diferencias de escala entre scorers: solo depende
    del ranking, no del valor absoluto.
    """

    def __init__(self, embedder: str = "BAAI/bge-small-en-v1.5"):
        self.model = SentenceTransformer(embedder)
        self.docs: List[Doc] = []
        self.embeddings: np.ndarray | None = None
        self.bm25: BM25Okapi | None = None

    def index(self, docs: List[Doc]) -> None:
        self.docs = docs
        texts = [d.text for d in docs]
        self.embeddings = self.model.encode(texts, normalize_embeddings=True)
        self.bm25 = BM25Okapi([t.lower().split() for t in texts])

    def _dense_rank(self, query: str, top_k: int) -> List[int]:
        q = self.model.encode([query], normalize_embeddings=True)[0]
        sims = self.embeddings @ q
        return np.argsort(-sims)[:top_k].tolist()

    def _sparse_rank(self, query: str, top_k: int) -> List[int]:
        scores = self.bm25.get_scores(query.lower().split())
        return np.argsort(-scores)[:top_k].tolist()

    def search(
        self,
        query: str,
        tenant_id: str,              # RBAC: nunca cruzar tenants
        top_k: int = 5,
        k_rrf: int = 60,             # constante estándar RRF
    ) -> List[Doc]:
        dense = self._dense_rank(query, top_k * 4)
        sparse = self._sparse_rank(query, top_k * 4)

        rrf: Dict[int, float] = {}
        for rank, idx in enumerate(dense):
            rrf[idx] = rrf.get(idx, 0) + 1 / (k_rrf + rank)
        for rank, idx in enumerate(sparse):
            rrf[idx] = rrf.get(idx, 0) + 1 / (k_rrf + rank)

        ordered = sorted(rrf.items(), key=lambda x: -x[1])
        # Filtro de tenant: CRÍTICO para multi-tenancy
        result = [self.docs[i] for i, _ in ordered if self.docs[i].tenant_id == tenant_id]
        return result[:top_k]
```

### 2. Evaluación con Ragas

```python
from ragas import evaluate
from ragas.metrics import (
    faithfulness,          # ¿La respuesta se apoya en el contexto?
    answer_relevancy,      # ¿Responde a la pregunta?
    context_precision,     # ¿El contexto top-k es relevante?
    context_recall,        # ¿El contexto cubre la respuesta ideal?
)
from datasets import Dataset

golden = Dataset.from_dict({
    "question": ["¿Cuántos días de PTO tengo?"],
    "answer":   ["20 días anuales según la política vigente."],
    "contexts": [["Los empleados reciben 20 días de vacaciones por año."]],
    "ground_truth": ["20 días anuales."],
})

report = evaluate(
    golden,
    metrics=[faithfulness, answer_relevancy, context_precision, context_recall],
)
print(report)
# Umbrales recomendados en producción:
#   faithfulness >= 0.90  (menos → alucinaciones)
#   context_precision >= 0.70  (menos → ruido en retrieval)
```

| Métrica Ragas | Qué mide | Qué revela si falla |
|---|---|---|
| `faithfulness` | % de claims de la respuesta soportados por el contexto | El LLM alucina o ignora el contexto |
| `answer_relevancy` | Qué tan directamente responde la pregunta | Respuestas evasivas o fuera de tema |
| `context_precision` | % de chunks recuperados que son útiles | Retrieval ruidoso; mejorar re-ranking |
| `context_recall` | % de la respuesta verdadera cubierta por el contexto | Falta cobertura; subir top-k o reindexar |

### 3. GraphRAG con Neo4j

```python
from neo4j import GraphDatabase

CYPHER_LOCAL_SEARCH = """
// Encuentra entidades mencionadas y expande 2 hops
MATCH (e:Entity)
WHERE e.name IN $entities AND e.tenant_id = $tenant_id
CALL {
  WITH e
  MATCH (e)-[r*1..2]-(neighbor:Entity)
  RETURN neighbor, r
}
MATCH (neighbor)-[:MENTIONED_IN]->(c:Chunk)
RETURN DISTINCT c.text AS text, c.source AS source
LIMIT $k
"""

class GraphRAG:
    def __init__(self, uri: str, user: str, pwd: str):
        self.driver = GraphDatabase.driver(uri, auth=(user, pwd))

    def extract_entities(self, query: str, llm) -> list[str]:
        prompt = f"Lista entidades (personas, empresas, productos) en: {query}"
        return llm.extract_json(prompt)  # ["ResNet", "BERT"]

    def local_search(self, query: str, tenant_id: str, llm, k: int = 10):
        entities = self.extract_entities(query, llm)
        with self.driver.session() as s:
            rows = s.run(CYPHER_LOCAL_SEARCH,
                         entities=entities, tenant_id=tenant_id, k=k).data()
        context = "\n".join(r["text"] for r in rows)
        return llm.generate(f"Contexto:\n{context}\n\nPregunta: {query}")
```

### 4. Self-RAG con decision gate

```python
from enum import Enum

class Decision(Enum):
    ANSWER_DIRECTLY = "no_retrieval"
    RETRIEVE_ONCE = "retrieve_once"
    RETRIEVE_AND_REFINE = "retrieve_refine"

def route(query: str, llm) -> Decision:
    """Un LLM pequeño decide la estrategia; evita latencia innecesaria."""
    judgment = llm.classify(
        system="Clasifica la consulta como factual_simple, factual_compleja o conocimiento_general.",
        user=query,
    )
    return {
        "conocimiento_general": Decision.ANSWER_DIRECTLY,
        "factual_simple":       Decision.RETRIEVE_ONCE,
        "factual_compleja":     Decision.RETRIEVE_AND_REFINE,
    }[judgment]

def self_rag(query: str, retriever, llm) -> str:
    decision = route(query, llm)
    if decision is Decision.ANSWER_DIRECTLY:
        return llm.generate(query)

    docs = retriever.search(query, tenant_id="acme", top_k=5)
    answer = llm.generate(f"Contexto: {docs}\nPregunta: {query}")

    # CRAG (Corrective RAG): verifica y, si falta soporte, re-retrieva
    support = llm.score_support(answer, docs)   # 0..1
    if support < 0.6 and decision is Decision.RETRIEVE_AND_REFINE:
        new_query = llm.rewrite(query, hint="agrega términos técnicos")
        docs = retriever.search(new_query, tenant_id="acme", top_k=5)
        answer = llm.generate(f"Contexto: {docs}\nPregunta: {query}")
    return answer
```

### 5. Multi-tenancy + PII + encryption at rest

```python
import re, hmac, hashlib
from cryptography.fernet import Fernet

PII_PATTERNS = {
    "email":       re.compile(r"\b[\w.+-]+@[\w-]+\.[\w.-]+\b"),
    "ssn":         re.compile(r"\b\d{3}-\d{2}-\d{4}\b"),
    "credit_card": re.compile(r"\b(?:\d[ -]*?){13,16}\b"),
}

def redact_pii(text: str) -> str:
    for name, pat in PII_PATTERNS.items():
        text = pat.sub(f"[REDACTED_{name.upper()}]", text)
    return text

class SecureIndex:
    def __init__(self, key: bytes):
        self.cipher = Fernet(key)   # AES-128 en modo CBC + HMAC

    def encrypt_payload(self, text: str) -> bytes:
        return self.cipher.encrypt(text.encode())

    def index_document(self, raw_text: str, tenant_id: str, retriever):
        # 1) PII OUT antes de embebido (nunca sube a modelos externos)
        safe = redact_pii(raw_text)
        # 2) Embedding sobre texto saneado
        doc = Doc(
            doc_id=hashlib.sha256(raw_text.encode()).hexdigest(),
            text=safe,
            tenant_id=tenant_id,                   # filtro obligatorio
            metadata={"ciphertext": self.encrypt_payload(raw_text)},
        )
        retriever.index([doc])
```

## Errores comunes

### ### Enterprise concerns (RBAC, PII, multi-tenancy, audit trails)

- **No evaluar RAG ("parece funcionar en 3 demos").** Sin un golden set + Ragas / LangSmith, cada deploy es ruleta rusa. Mínimo: 50-200 preguntas con respuestas verificadas, ejecutadas en CI.
- **Olvidar filtros de tenant → data leakage.** Un bug clásico: el `tenant_id` se aplica en la UI pero no en la query al vector store. Resultado: un usuario de ACME ve chunks de GLOBEX. **Siempre filtrar en el motor de retrieval**, no en la capa de presentación. Idealmente, pre-filtrar antes del ANN (muchos vector DBs lo soportan como *metadata filter*).
- **Embeddings sin encryption at rest.** Los embeddings **se pueden invertir** parcialmente (ataques de embedding inversion recuperan texto). Cifra el índice en reposo (AES-256) y el texto fuente que guardas como payload.
- **PII enviado a modelos de embedding externos.** OpenAI, Cohere, Voyage ven tu texto. Redacta PII *antes* de llamar al endpoint, o usa modelos on-prem (BGE, E5, Nomic) para datos regulados.
- **No versionar el índice.** Reindexar con un modelo nuevo sin versionar impide A/B tests y rollbacks. Usa aliases: `prod` → `index_v3`; para rollback apunta `prod` → `index_v2` en segundos.
- **Sin plan de rollback.** Un cambio en el chunker, el embedder o el prompt puede degradar `faithfulness` sin que lo notes. Blue/green deploy + métrica Ragas en shadow traffic.
- **Un solo embedding model para todas las modalidades.** Forzar imágenes a texto con OCR pierde información visual. Usa CLIP/ColPali para visual y mantén índices separados fusionados en query.
- **Audit trail incompleto.** Cada query debe loguear: `user_id`, `tenant_id`, `query`, `retrieved_doc_ids`, `response`, `latency`, `cost_tokens`, `timestamp`. Esto es obligatorio para HIPAA, GDPR, SOX y para debuggear quejas.
- **Over-engineering del routing.** Empezar con un router de 7 estrategias antes de validar que una sola funciona introduce latencia y bugs. Baseline → medir → agregar complejidad solo si Ragas lo justifica.
- **Normalización de scores incorrecta.** Combinar `cosine_sim ∈ [0,1]` con `BM25 ∈ [0, 50]` con un `average()` entrega resultados dominados por BM25. Usa RRF (robusto por ranking) o normalización por percentil.

## Resumen

- El **RAG avanzado** combina recuperación densa, dispersa, de grafos y multi-modal; decide dinámicamente qué usar.
- La **fusión híbrida** con RRF o combinación lineal normalizada resuelve el problema de "términos exactos vs. significado".
- **GraphRAG (Microsoft, 2024)** destaca en preguntas globales; **vector RAG** sigue siendo mejor para preguntas específicas.
- **Multi-modal** con CLIP, SigLIP o ColPali permite buscar imágenes con texto y viceversa en un espacio compartido.
- **Ragas** (faithfulness, answer_relevancy, context_precision, context_recall) convierte "parece funcionar" en métricas accionables.
- En enterprise, los no-funcionales mandan: **RBAC via metadata filters**, **PII redaction antes de embeddings**, **encryption at rest**, **multi-tenancy con filtro por `tenant_id`**, **audit trail por query** y **plan de rollback con versionado de índice**.
- Herramientas clave 2024-2026: **Ragas**, **LangSmith**, **Neo4j + Microsoft GraphRAG**, **LlamaIndex advanced patterns**, **BGE-reranker**, **Cohere Rerank**.
- Patrones a tener en el radar: **HyDE**, **RAPTOR**, **Self-RAG (2023)**, **CRAG (2024)**, **multi-query / RAG-Fusion**.
- Nunca despliegues RAG sin: golden set evaluado en CI, filtro de tenant pre-ANN, PII redaction, encryption y audit log por query.
