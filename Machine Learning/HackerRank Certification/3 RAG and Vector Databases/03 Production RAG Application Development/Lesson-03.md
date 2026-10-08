# Re-ranking avanzado y validación de respuestas

## ¿Qué es?

**Re-ranking** es una segunda etapa de recuperación que **reordena** los candidatos obtenidos por la búsqueda vectorial inicial, usando un modelo más preciso pero más caro. **Response validation** es el conjunto de mecanismos (self-critique, confidence scoring, filtrado adaptativo) que miden la calidad de la respuesta generada **antes de entregársela al usuario**.

El flujo típico en producción es:

```
query
  │
  ├── 1. Retrieval rápido (bi-encoder, top ~100)
  │         ↓
  ├── 2. Re-ranking preciso (cross-encoder, top ~10)
  │         ↓
  ├── 3. Generación con el LLM (contexto top-5)
  │         ↓
  ├── 4. Validación / self-critique
  │         ↓
  └── 5. Filtrado adaptativo según confidence
            ↓
         respuesta al usuario (o degradación)
```

Las dos piezas son complementarias: **re-ranking** mejora la *calidad del contexto* que llega al generador; **validation** mejora la *calidad de la salida* antes de que llegue al usuario.

## ¿Por qué importa?

Un retriever basado solo en similitud de embeddings produce resultados *parecidos*, no necesariamente *útiles*. Documentos distintos pueden tener embeddings casi idénticos; documentos genuinamente relevantes pueden quedar en el puesto 20 por una diferencia marginal.

- **Precisión del top-K:** el LLM solo ve 3-10 chunks. Si los más relevantes están en los puestos 15-25, el modelo responde con basura aunque el índice los tenga.
- **Confianza calibrada:** un sistema que *siempre* responde con el mismo tono de certeza engaña al usuario. La validación permite decir *"con esta evidencia la respuesta es sólida"* vs. *"responde con cautela, la evidencia es débil"*.
- **Degradación controlada:** cuando la confianza es baja, es preferible admitir incertidumbre a inventar. Esto se decide con métricas, no con el humor del LLM.
- **Consistencia:** sin tie-breakers deterministas, dos queries idénticas pueden devolver documentos en orden distinto → confusión del usuario y caché inútil.
- **Diferencia competitiva:** la calidad percibida en un RAG de producción está dominada por la calidad del top-5, no por el tamaño del índice.

## ¿Cómo funciona?

### Bi-encoder vs. cross-encoder

| Dimensión | Bi-encoder | Cross-encoder |
|---|---|---|
| **Input** | Query y documento por separado | Par `(query, documento)` concatenado |
| **Output** | Vectores comparables por coseno | Score escalar de relevancia directa |
| **Precomputo** | Sí (todos los docs se embeben una vez) | No (cada par se calcula al vuelo) |
| **Velocidad** | Muy rápido (ANN) | Lento (una pasada forward por par) |
| **Precisión** | Buena | Mejor (capta interacción query-doc) |
| **Uso** | Primera etapa, top 50-200 | Segunda etapa, re-rank top 10-20 |

### Pipeline de dos etapas

```
query → bi-encoder → ANN search (top 100)
                         ↓
           cross-encoder predict(query, doc) por cada candidato
                         ↓
           sort por score y toma top 5-10
                         ↓
                      LLM
```

Modelos populares:

- `cross-encoder/ms-marco-MiniLM-L-6-v2` — rápido, buen baseline.
- `cross-encoder/ms-marco-MiniLM-L-12-v2` — más preciso.
- `BAAI/bge-reranker-large` — multilingüe, estado del arte.
- **Cohere Rerank** / **Jina Reranker** — APIs managed si no quieres hostear.

### Learning-to-Rank (LTR)

Cuando tienes señales de negocio (CTR, feedback explícito, autoridad de la fuente, recencia), un modelo LTR (LambdaMART, XGBoost ranking, redes neuronales de ranking) aprende a combinar múltiples señales para optimizar métricas como nDCG. Features típicas:

- **Contenido:** similitud bi-encoder, score cross-encoder, BM25, longitud, legibilidad.
- **Autoridad:** credibilidad de la fuente, citas internas, departamento owner.
- **Frescura:** fecha de publicación, última modificación, decay exponencial.
- **Interacción:** CTR histórico, dwell time, thumbs up/down.

### Tie-breaking determinista

Dos documentos con el mismo score deben siempre ordenarse igual. Usa un **hash estable del contenido** como segundo criterio de ordenamiento:

```
sort key = (score desc, sha256(content)[:8] asc)
```

Beneficios: reproducibilidad, mejor hit-rate de caché, menos confusión del usuario.

### Normalización de scores

Combinar scores de distintos retrievers (bi-encoder, BM25, cross-encoder) requiere ponerlos en la misma escala:

| Método | Rango | Fórmula | Cuándo |
|---|---|---|---|
| **Min-Max** | [0, 1] | `(x - min) / (max - min)` | General, rápido |
| **Z-score** | ℝ | `(x - μ) / σ` | Distribución ~gaussiana |
| **Sigmoid** | (0, 1) | `1 / (1 + e⁻ˣ)` | Scores no acotados |
| **Reciprocal Rank Fusion** | (0, 1] | `Σ 1/(k + rank_i)` | Combinar múltiples retrievers sin normalizar scores |

### Self-critique y validación

Mecanismos que corren sobre `(query, contexto, respuesta)` para asignar una confianza:

- **Factual consistency / grounding** — ¿la respuesta se apoya en el contexto?
- **Completeness** — ¿cubre todas las partes de la pregunta?
- **Source attribution** — ¿cita las fuentes correctas?
- **Internal consistency** — ¿se contradice a sí misma?

Implementación: scores heurísticos (overlap léxico, NLI, LLM-as-judge) ponderados.

### Adaptive filtering

Según el score de confianza final, la respuesta se entrega con distinto tratamiento:

| Confidence | Acción |
|---|---|
| ≥ 0.80 | Entregar directamente |
| 0.60 – 0.80 | Entregar con disclaimer *"basado en información disponible…"* |
| < 0.60 | Degradar: *"no tengo evidencia suficiente para responder con confianza"* y sugerir reformular |

## Ejemplo con código

Pipeline completo: **bi-encoder + Qdrant + cross-encoder re-rank + RRF para fusión + ResponseValidator con 4 criterios + AdaptiveFilter + FastAPI.**

```python
# requirements:
#   fastapi uvicorn qdrant-client sentence-transformers
#   langchain-openai numpy pydantic

import hashlib
from typing import Any

import numpy as np
from fastapi import FastAPI
from pydantic import BaseModel
from qdrant_client import QdrantClient
from sentence_transformers import SentenceTransformer, CrossEncoder
from langchain_openai import ChatOpenAI

# ------------------------------------------------------------
# Modelos
# ------------------------------------------------------------
BI_ENCODER    = SentenceTransformer("intfloat/multilingual-e5-base")
CROSS_ENCODER = CrossEncoder("BAAI/bge-reranker-base")
LLM           = ChatOpenAI(model="gpt-4o-mini", temperature=0)
JUDGE         = ChatOpenAI(model="gpt-4o", temperature=0)

qdrant = QdrantClient(host="localhost", port=6333)
COLLECTION = "docs_prod"


# ------------------------------------------------------------
# 1. Retrieval en dos etapas: bi-encoder -> cross-encoder
# ------------------------------------------------------------
def retrieve_candidates(query: str, top_k: int = 100) -> list[dict]:
    vec = BI_ENCODER.encode(f"query: {query}").tolist()
    hits = qdrant.search(COLLECTION, query_vector=vec, limit=top_k)
    return [{"content": h.payload["content"],
             "metadata": h.payload,
             "sim_score": float(h.score)} for h in hits]


def rerank_cross_encoder(query: str, docs: list[dict],
                         top_k: int = 10,
                         w_sim: float = 0.3,
                         w_cross: float = 0.7) -> list[dict]:
    pairs = [(query, d["content"]) for d in docs]
    cross = CROSS_ENCODER.predict(pairs, show_progress_bar=False)
    cross_norm = _min_max(np.asarray(cross))
    sim_norm   = _min_max(np.asarray([d["sim_score"] for d in docs]))

    for i, d in enumerate(docs):
        d["cross_score"]      = float(cross[i])
        d["cross_score_norm"] = float(cross_norm[i])
        d["sim_score_norm"]   = float(sim_norm[i])
        d["final_score"]      = w_sim * sim_norm[i] + w_cross * cross_norm[i]
        d["tie_hash"]         = hashlib.sha256(
                                   d["content"].encode("utf-8")).hexdigest()[:8]

    return sorted(docs,
                  key=lambda x: (-x["final_score"], x["tie_hash"]))[:top_k]


def _min_max(x: np.ndarray) -> np.ndarray:
    rng = x.max() - x.min()
    return (x - x.min()) / rng if rng > 0 else np.full_like(x, 0.5)


# ------------------------------------------------------------
# 2. Reciprocal Rank Fusion para combinar varios retrievers
# ------------------------------------------------------------
def rrf_fuse(rankings: list[list[dict]], k: int = 60,
             top_k: int = 20) -> list[dict]:
    scores: dict[str, float] = {}
    cache:  dict[str, dict]  = {}
    for ranking in rankings:
        for rank, doc in enumerate(ranking, start=1):
            key = doc["metadata"]["chunk_hash"]
            scores[key] = scores.get(key, 0.0) + 1 / (k + rank)
            cache.setdefault(key, doc)
    fused = sorted(cache.values(),
                   key=lambda d: -scores[d["metadata"]["chunk_hash"]])
    for d in fused:
        d["rrf_score"] = scores[d["metadata"]["chunk_hash"]]
    return fused[:top_k]


# ------------------------------------------------------------
# 3. Response validator (multi-criteria + LLM judge)
# ------------------------------------------------------------
JUDGE_PROMPT = """Evalua la respuesta respecto al contexto. Responde JSON:
{{"faithful": 0.0-1.0, "complete": 0.0-1.0, "reason": "..."}}

Contexto:
{context}

Pregunta: {query}
Respuesta: {response}
"""


class ResponseValidator:
    WEIGHTS = {"faithful": 0.45, "complete": 0.25,
               "attribution": 0.15, "retrieval": 0.15}

    def validate(self, query: str, response: str,
                 docs: list[dict]) -> dict:
        context = "\n".join(d["content"] for d in docs)

        faithful, complete = self._llm_judge(query, response, context)
        attribution = self._attribution_score(response, docs)
        retrieval   = self._retrieval_quality(docs)

        confidence = (self.WEIGHTS["faithful"]    * faithful +
                      self.WEIGHTS["complete"]    * complete +
                      self.WEIGHTS["attribution"] * attribution +
                      self.WEIGHTS["retrieval"]   * retrieval)

        return {
            "confidence":    round(confidence, 3),
            "faithfulness":  faithful,
            "completeness":  complete,
            "attribution":   attribution,
            "retrieval":     retrieval,
        }

    def _llm_judge(self, query, response, context) -> tuple[float, float]:
        import json
        prompt = JUDGE_PROMPT.format(context=context, query=query,
                                     response=response)
        raw = JUDGE.invoke(prompt).content
        try:
            parsed = json.loads(raw)
            return float(parsed["faithful"]), float(parsed["complete"])
        except Exception:
            return 0.5, 0.5                       # fallback neutro

    def _attribution_score(self, response, docs) -> float:
        sources = {d["metadata"].get("source", "") for d in docs}
        hits = sum(1 for s in sources if s and s.lower() in response.lower())
        return min(1.0, hits / max(1, len(sources)))

    def _retrieval_quality(self, docs) -> float:
        """Promedio ponderado por posicion de los cross-scores."""
        if not docs:
            return 0.0
        weights = np.array([1 / (i + 1) for i in range(len(docs))])
        scores  = np.array([d.get("cross_score_norm", d["sim_score"])
                            for d in docs])
        return float(np.average(scores, weights=weights))


# ------------------------------------------------------------
# 4. Filtrado adaptativo segun confianza
# ------------------------------------------------------------
class AdaptiveResponseFilter:
    def apply(self, response: str, validation: dict,
              citations: list) -> dict:
        c = validation["confidence"]
        if c >= 0.80:
            return {"answer": response, "confidence_level": "high",
                    "validation": validation, "citations": citations}
        if c >= 0.60:
            return {"answer": f"Segun la informacion disponible: {response}",
                    "confidence_level": "medium",
                    "note": "Confianza moderada en las fuentes",
                    "validation": validation, "citations": citations}
        return {"answer": "No tengo evidencia suficiente para responder con "
                          "confianza. Intenta reformular la pregunta o "
                          "aporta mas contexto.",
                "confidence_level": "low",
                "validation": validation, "citations": []}


# ------------------------------------------------------------
# 5. Orquestacion end-to-end + FastAPI
# ------------------------------------------------------------
RAG_PROMPT = """Responde EXCLUSIVAMENTE con el contexto. Cita como [source:page].
Si no hay evidencia, responde literalmente:
"No tengo informacion suficiente para responder."

Contexto:
{context}

Pregunta: {query}
Respuesta:
"""


def rag_answer(query: str) -> dict:
    candidates = retrieve_candidates(query, top_k=100)
    reranked   = rerank_cross_encoder(query, candidates, top_k=5)

    context = "\n\n".join(
        f"[{d['metadata'].get('source','?')}:{d['metadata'].get('page','?')}] "
        f"{d['content']}" for d in reranked
    )
    response = LLM.invoke(RAG_PROMPT.format(context=context,
                                            query=query)).content

    validation = ResponseValidator().validate(query, response, reranked)
    final      = AdaptiveResponseFilter().apply(
        response, validation,
        [{"source": d["metadata"].get("source"),
          "page":   d["metadata"].get("page"),
          "score":  d["final_score"]} for d in reranked]
    )
    return final


app = FastAPI()


class QueryIn(BaseModel):
    query: str


@app.post("/query")
def query_endpoint(payload: QueryIn):
    return rag_answer(payload.query)
```

**Qué observar:**

- `retrieve_candidates` trae 100 chunks con el bi-encoder (barato); `rerank_cross_encoder` reduce a 5 con el cross-encoder (caro pero preciso).
- La **combinación ponderada** `0.3 * sim + 0.7 * cross` prioriza al cross-encoder sin ignorar al retriever inicial.
- El **tie-breaker por hash** garantiza orden determinista para scores empatados.
- `rrf_fuse` permite combinar varios retrievers (p.ej. vectorial + BM25 + keyword) sin preocuparse por normalizar scores.
- El **LLM judge** usa un modelo *distinto* y más fuerte que el generador (`gpt-4o` vs. `gpt-4o-mini`).
- `retrieval_quality` promedia los cross-scores ponderando por posición: si los top-1 y top-2 son buenos, pesa más que si lo son top-9 y top-10.
- `AdaptiveResponseFilter` **degrada activamente** cuando la confianza es baja, en lugar de dejar pasar una respuesta frágil.

## Errores comunes

- **Confiar en un solo signal de ranking.** Similitud de embeddings sola ignora autoridad, recencia y señales de interacción. Combina con cross-encoder y, si tienes datos de uso, LTR.
- **No usar tie-breaker determinista.** Mismo query → distinto orden → usuarios confundidos y caché inútil. Siempre un segundo criterio estable (hash, id, fecha).
- **Mal balance bi-encoder / cross-encoder.** `top_k=10` en la primera etapa es demasiado poco para que el cross-encoder tenga sobre qué trabajar; usa 50-200.
- **Cross-encoder en batch de 1.** Procesar pares uno a uno destroza el throughput. Agrupa en batches y usa GPU si está disponible.
- **No normalizar scores entre retrievers.** Mezclar scores de BM25 (rango 0-30) con cosine (0-1) hace que BM25 domine siempre. Normaliza o usa RRF.
- **Confidence mal calibrado.** Si el 90% de las respuestas marcan `confidence > 0.8`, el score no está discriminando. Calibra con un dataset etiquetado y ajusta los umbrales.
- **LLM judge igual al generador.** El modelo rara vez marca sus propios errores. Usa un modelo distinto y preferentemente superior.
- **Sin degradación.** Entregar siempre una respuesta aunque la confianza sea 0.2 es la receta para alucinaciones de alta visibilidad. Mejor "no sé".
- **Re-rankear sobre poca diversidad.** Si tu top-100 bi-encoder son 100 variantes del mismo documento, el cross-encoder no puede arreglarlo. Agrega MMR (Maximal Marginal Relevance) para forzar diversidad antes del re-rank.
- **No cachear embeddings de queries.** Para queries repetidas (dashboards, autosuggest), cachear el embedding y los candidates ahorra 80% del costo.
- **Olvidar el costo del LLM judge.** Usar `gpt-4o` por cada query duplica el costo. Reserva el judge para una muestra (p.ej. 10%) o para cuando la confianza heurística esté en zona gris.

## Resumen

- **Re-ranking** convierte la búsqueda vectorial de *"documentos parecidos"* en *"documentos relevantes"* al introducir una segunda etapa con cross-encoder.
- La arquitectura estándar es **dos etapas**: bi-encoder trae 100 candidatos rápido, cross-encoder reordena 5-10 con precisión.
- **Reciprocal Rank Fusion (RRF)** es la forma más robusta y simple de combinar varios retrievers sin normalizar scores.
- **Tie-breakers deterministas** (hash de contenido) garantizan reproducibilidad y hit-rate de caché.
- **Learning-to-Rank** incorpora señales de negocio (CTR, autoridad, recencia) cuando tienes datos de uso.
- **Response validation** opera sobre `(query, contexto, respuesta)` con criterios múltiples: faithfulness, completeness, attribution, retrieval quality.
- Usa un **LLM-as-judge distinto y más fuerte** que el generador, con `temperature=0`.
- **Adaptive filtering** entrega la respuesta con tres niveles: alta → directa, media → con disclaimer, baja → degradada a *"no sé"*.
- Siempre **degrada** antes de entregar una respuesta de baja confianza — es más barato que un ticket de soporte y protege la confianza del usuario.
- Modelos de cross-encoder recomendados: `BAAI/bge-reranker-large` (open), **Cohere Rerank** / **Jina Reranker** (managed).
- El cuello de botella del cross-encoder es el batch size: GPU + batches de 32-64 lo hacen viable en producción.
- Calibra umbrales de confianza contra feedback humano real; no dejes los valores por defecto en producción.
