# Quality Assurance y validación de salidas en RAG

## ¿Qué es?

**Quality assurance (QA)** en RAG es el conjunto de pruebas, métricas y monitores que garantizan que el sistema entrega respuestas **correctas, fundamentadas y auditables** en producción. No es un test unitario aislado: es una capa continua que corre durante el desarrollo, el deploy y la operación.

Un RAG puede fallar en tres frentes independientes:

| Capa | Qué puede fallar | Impacto en el usuario |
|---|---|---|
| **Retrieval** | Documentos irrelevantes con alto score, chunking pobre, fuentes obsoletas rankeadas arriba | Evidencia débil → respuesta incorrecta |
| **Generation** | Alucinaciones no soportadas por el contexto, respuestas incompletas, contradicciones | Confusión, pérdida de confianza |
| **Sistema** | Errores de filtrado por metadata, latencia alta, inconsistencia entre sesiones | Mala UX, inestabilidad |

QA cubre las tres capas con una estrategia **en capas**: unit tests por componente, evaluación automatizada del pipeline completo, detección de alucinaciones y monitoreo continuo en producción.

## ¿Por qué importa?

Un RAG en producción se usa para decisiones **con consecuencias reales**: diagnósticos, consejo financiero, aprobaciones legales, soporte técnico. Una respuesta confidentemente incorrecta puede costar dinero, salud o reputación.

- **Confianza:** una sola alucinación visible destruye meses de adopción. Los usuarios perdonan "no sé"; no perdonan "aquí tienes un número inventado".
- **Regresiones silenciosas:** actualizar el embedding model, cambiar un prompt o reindexar puede degradar el recall en 20% sin que nadie se entere hasta que llegan los tickets.
- **Model drift:** los LLMs mejoran, pero también cambian: una respuesta que funcionaba con GPT-4-0613 puede romperse con GPT-4-0125.
- **Content drift:** la knowledge base crece y se contamina. Lo que ayer tenía Precision@5 = 0.9, hoy puede tener 0.6.
- **Compliance:** en salud y finanzas, demostrar que mediste calidad es **requisito regulatorio**.

Sin QA, un RAG es una lotería: a veces impresiona, a veces humilla, y no sabes cuándo.

## ¿Cómo funciona?

QA en RAG se organiza en cuatro bloques:

```
┌───────────────────────────────────────────────────┐
│ 1. Unit tests por componente                      │
│    embedding · retriever · generador · filtros    │
├───────────────────────────────────────────────────┤
│ 2. Evaluación end-to-end con dataset dorado       │
│    Precision@K · Recall · MRR · Faithfulness      │
├───────────────────────────────────────────────────┤
│ 3. Deteccion de alucinaciones                     │
│    numericas · entidades · fechas · LLM-as-judge  │
├───────────────────────────────────────────────────┤
│ 4. Monitoreo en vivo                              │
│    latencia · tasa de error · feedback · drift    │
└───────────────────────────────────────────────────┘
```

### Métricas clave

**Retrieval:**

| Métrica | Qué mide | Fórmula |
|---|---|---|
| **Precision@K** | Fracción de los top-K que son relevantes | `relevantes_en_topK / K` |
| **Recall@K** | Fracción de los relevantes totales que aparecieron en top-K | `relevantes_en_topK / total_relevantes` |
| **MRR** | Qué tan arriba está el primer relevante | `mean(1 / rank_del_primer_relevante)` |
| **nDCG@K** | Calidad del ranking con pesos logarítmicos | normalización de DCG |
| **Hit Rate** | ¿Al menos un relevante en top-K? | binario |

**Generation (RAGAS y afines):**

| Métrica | Qué mide |
|---|---|
| **Faithfulness** | ¿La respuesta se apoya en el contexto? (anti-alucinación) |
| **Answer Relevance** | ¿Responde la pregunta? |
| **Context Precision** | ¿El contexto recuperado era útil? |
| **Context Recall** | ¿Se recuperó todo lo necesario para responder? |
| **Answer Correctness** | ¿Coincide con el ground truth? |

**Sistema:**

- Latencia (p50, p95, p99)
- Tasa de error / respuestas vacías
- Costo por query (tokens de embedding + LLM)
- CSAT, thumbs up/down del usuario

### Grounding en la validación

Validar grounding = probar que **cada afirmación de la respuesta está respaldada por algún chunk del contexto**. Técnicas:

- **Overlap léxico** (bag of words) — rápido, superficial.
- **NLI (Natural Language Inference)** — un modelo decide si cada frase de la respuesta es *entailed* por el contexto.
- **LLM-as-judge** — se le pasa `(contexto, respuesta)` a un LLM evaluador con un prompt tipo *"¿cada afirmación está soportada?"*.

### Unit testing por componente

Antes de testear end-to-end, aisla cada bloque:

- **Embedding:** dimensión correcta, sin NaN, norma > 0, similitud semántica razonable entre pares conocidos.
- **Retriever:** para una query ancla, retorna el documento ancla en top-K.
- **Filtros de metadata:** un query con `department=finance` nunca retorna chunks de `department=hr`.
- **Generador:** dado un contexto que contiene el dato, la respuesta debe contenerlo.

### Golden dataset

Un **dataset dorado** es una colección de 50-500 triples `(query, respuesta_esperada, documentos_fuente)` curada manualmente por expertos del dominio. Es la base para medir regresiones. Reglas:

- Cubrir casos frecuentes **y** edge cases (preguntas ambiguas, fuera de dominio, con negación).
- Versionarlo en git.
- Revisarlo trimestralmente para refrescar con queries reales.

### Herramientas

- **RAGAS** — métricas de retrieval + generation con LLM-as-judge, listas para producción.
- **DeepEval / promptfoo** — frameworks de testing para prompts y pipelines.
- **TruLens** — tracing y evaluación end-to-end.
- **LangSmith** / **LlamaIndex Evaluation** — plataformas integradas al framework.
- **Evidently / WhyLabs / Arize** — monitoreo de drift en producción.

## Ejemplo con código

Pipeline de QA integrado: **unit tests + RAGAS + hallucination detection + monitor en producción + FastAPI con endpoint `/feedback`.**

```python
# requirements:
#   fastapi uvicorn ragas datasets pandas numpy
#   langchain-openai sentence-transformers pytest
#   qdrant-client

import json
import re
import statistics
import time
from datetime import datetime
from typing import Any

import numpy as np
import pandas as pd
from fastapi import FastAPI
from pydantic import BaseModel
from langchain_openai import ChatOpenAI, OpenAIEmbeddings
from ragas import evaluate
from ragas.metrics import (
    faithfulness,
    answer_relevancy,
    context_precision,
    context_recall,
)
from datasets import Dataset

# ------------------------------------------------------------
# 1. UNIT TESTS POR COMPONENTE (pytest-style)
# ------------------------------------------------------------
def test_embedding_quality(embed_fn, dim: int = 1536) -> None:
    """Dimensiones correctas, sin NaN, norma no-cero, sensibilidad semantica."""
    casos = ["", "a", "A" * 2000, "Que es la politica de vacaciones?"]
    for texto in casos:
        v = np.asarray(embed_fn(texto))
        assert v.shape == (dim,),           f"Dim incorrecta para: {texto!r}"
        assert not np.isnan(v).any(),       f"NaN en: {texto!r}"
        assert np.linalg.norm(v) > 0,       f"Norma cero en: {texto!r}"

    # similitud semantica razonable
    a, b, c = embed_fn("perro"), embed_fn("canino"), embed_fn("ecuaciones diferenciales")
    sim_ab = _cos(a, b)
    sim_ac = _cos(a, c)
    assert sim_ab > sim_ac, "El retriever no distingue conceptos basicos"


def _cos(x, y) -> float:
    x, y = np.asarray(x), np.asarray(y)
    return float(np.dot(x, y) / (np.linalg.norm(x) * np.linalg.norm(y)))


def test_metadata_filter_isolation(retriever) -> None:
    """Un filtro por departamento NUNCA debe filtrar un chunk de otro."""
    hits = retriever.search("politica", filters={"department": "finance"}, top_k=20)
    assert all(h["metadata"]["department"] == "finance" for h in hits)


def test_generation_uses_context(generate_fn) -> None:
    ctx = "La empresa ofrece 22 dias de vacaciones."
    resp = generate_fn("Cuantos dias de vacaciones?", ctx)
    assert "22" in resp, "El generador ignoro el contexto"


# ------------------------------------------------------------
# 2. EVALUACION END-TO-END CON RAGAS
# ------------------------------------------------------------
GOLDEN_DATASET = [
    {
        "question": "Cuantos dias de vacaciones reciben los empleados?",
        "ground_truth": "20 dias anuales",
        "contexts": ["Los empleados reciben 20 dias de vacaciones al ano."],
        "expected_sources": ["employee_handbook_2024.pdf"],
    },
    {
        "question": "Cual fue el crecimiento de ingresos en Q3 vs Q2?",
        "ground_truth": "15% de incremento Q2 -> Q3",
        "contexts": ["Los ingresos aumentaron 15% de Q2 a Q3 2024."],
        "expected_sources": ["q3_financial_report.pdf"],
    },
]


def run_ragas(rag_system) -> pd.DataFrame:
    """Corre el golden dataset contra el sistema real y evalua con RAGAS."""
    records = []
    for item in GOLDEN_DATASET:
        resp = rag_system.query(item["question"])
        records.append({
            "question":     item["question"],
            "answer":       resp["answer"],
            "contexts":     [c["content"] for c in resp["citations"]],
            "ground_truth": item["ground_truth"],
        })
    ds = Dataset.from_list(records)
    result = evaluate(
        ds,
        metrics=[faithfulness, answer_relevancy,
                 context_precision, context_recall],
        llm=ChatOpenAI(model="gpt-4o-mini", temperature=0),
        embeddings=OpenAIEmbeddings(model="text-embedding-3-small"),
    )
    return result.to_pandas()


# ------------------------------------------------------------
# 3. DETECCION DE ALUCINACIONES (lexica + LLM-as-judge)
# ------------------------------------------------------------
NUMBER_RE = re.compile(r"\b\d+(?:[.,]\d+)?%?\b")
DATE_RE   = re.compile(r"\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b")


def detect_hallucinations_lexical(context: str, response: str) -> list[str]:
    """Detecta numeros, porcentajes y fechas en la respuesta que no estan en el contexto."""
    issues = []
    for n in set(NUMBER_RE.findall(response)):
        if n not in context:
            issues.append(f"Numero no respaldado: {n}")
    for d in set(DATE_RE.findall(response)):
        if d not in context:
            issues.append(f"Fecha no respaldada: {d}")
    return issues


JUDGE_PROMPT = """Eres un auditor estricto. Evalua si CADA afirmacion de la respuesta
esta respaldada por el contexto. Responde en JSON:
{{"supported": true|false, "unsupported_claims": ["...", "..."]}}

Contexto:
{context}

Respuesta:
{response}
"""


def detect_hallucinations_llm(context: str, response: str) -> dict:
    judge = ChatOpenAI(model="gpt-4o-mini", temperature=0)
    out = judge.invoke(JUDGE_PROMPT.format(context=context, response=response)).content
    try:
        return json.loads(out)
    except json.JSONDecodeError:
        return {"supported": None, "unsupported_claims": [], "raw": out}


# ------------------------------------------------------------
# 4. MONITOREO CONTINUO EN PRODUCCION
# ------------------------------------------------------------
class QualityMonitor:
    def __init__(self, window: int = 500):
        self.window = window
        self.events: list[dict[str, Any]] = []

    def record(self, query: str, context: str, response: str,
               latency_ms: float, citations: list) -> dict:
        issues_lex = detect_hallucinations_lexical(context, response)
        resp_words = set(response.lower().split())
        ctx_words  = set(context.lower().split())
        ctx_use = len(resp_words & ctx_words) / max(1, len(resp_words))

        quality = {
            "timestamp":        datetime.utcnow().isoformat(),
            "query":            query,
            "latency_ms":       latency_ms,
            "response_len":     len(response.split()),
            "context_usage":    ctx_use,
            "n_citations":      len(citations),
            "lexical_issues":   issues_lex,
            "flagged":          bool(issues_lex) or ctx_use < 0.2,
        }
        self.events.append(quality)
        self.events = self.events[-self.window:]
        return quality

    def summary(self) -> dict:
        if not self.events:
            return {"status": "no_data"}
        n = len(self.events)
        return {
            "window":          n,
            "p50_latency_ms":  statistics.median(e["latency_ms"] for e in self.events),
            "p95_latency_ms":  np.percentile([e["latency_ms"] for e in self.events], 95),
            "flagged_rate":    sum(e["flagged"] for e in self.events) / n,
            "avg_ctx_usage":   statistics.mean(e["context_usage"] for e in self.events),
            "avg_citations":   statistics.mean(e["n_citations"] for e in self.events),
        }


# ------------------------------------------------------------
# 5. FastAPI con /query y /feedback
# ------------------------------------------------------------
app = FastAPI()
monitor = QualityMonitor()


class QueryIn(BaseModel):
    query: str


class FeedbackIn(BaseModel):
    query: str
    rating: int        # 1-5
    comment: str = ""


@app.post("/query")
def query_endpoint(payload: QueryIn, rag_system):   # inyecta tu RAG real
    t0 = time.perf_counter()
    resp = rag_system.query(payload.query)
    latency_ms = (time.perf_counter() - t0) * 1000
    context = "\n".join(c["content"] for c in resp["citations"])

    q = monitor.record(payload.query, context, resp["answer"],
                       latency_ms, resp["citations"])

    # Guardrail: si hay alucinaciones lexicas, degradar la respuesta
    if q["flagged"]:
        resp["answer"] = ("No tengo informacion suficiente para responder con "
                          "la confianza requerida.")
        resp["degraded"] = True
    return resp


@app.post("/feedback")
def feedback_endpoint(payload: FeedbackIn):
    # En produccion: push a Postgres / Redshift para analizar correlacion
    # rating vs. metricas del monitor y detectar drift.
    with open("feedback.jsonl", "a") as f:
        f.write(payload.model_dump_json() + "\n")
    return {"ok": True}


@app.get("/health/quality")
def quality_summary():
    return monitor.summary()
```

**Qué observar:**

- Los **unit tests** son baratos y detectan regresiones antes de que lleguen al pipeline.
- **RAGAS** usa un LLM-as-judge para faithfulness y relevancia; combinarlo con el golden dataset da una señal numérica reproducible por commit.
- La detección léxica de números/fechas es un **primer filtro barato**; el LLM-judge es el segundo pase más caro y preciso.
- El `QualityMonitor` degrada activamente la respuesta cuando detecta flags, en lugar de dejarla pasar.
- El endpoint `/feedback` cierra el loop: correlacionar `rating` del usuario con las métricas internas te dice si tus métricas realmente capturan calidad percibida.

## Errores comunes

- **Testear solo el happy path.** Si tu suite no incluye preguntas fuera de dominio, con negación, con nombres propios ambiguos o malformed, el sistema se rompe en producción con la primera query real.
- **Confiar ciegamente en BLEU/ROUGE.** Son métricas léxicas: una respuesta semánticamente perfecta pero reformulada puede sacar BLEU bajo. Úsalas junto a faithfulness y evaluación humana.
- **Golden dataset sesgado o estático.** Si lo creó un solo experto, refleja su sesgo. Si no se actualiza, deja de reflejar las queries reales. Refresca trimestralmente con muestras de producción.
- **Sin baseline.** Mejorar de "F1 = 0.72" a "F1 = 0.74" no significa nada sin saber qué logra un baseline simple (BM25 + GPT-3.5). Mide siempre contra un baseline reproducible.
- **Monitorear solo uptime.** El sistema puede estar 100% disponible devolviendo basura. Monitorea *calidad*, no solo *disponibilidad*.
- **Ignorar el feedback del usuario.** `thumbs down` es la señal más barata y la más desperdiciada. Guárdala, correlaciónala con la query, úsala para alimentar el próximo golden dataset.
- **LLM-as-judge con el mismo modelo generador.** Un modelo rara vez detecta sus propios errores. Usa un modelo *diferente* (y preferentemente más fuerte) como juez.
- **No controlar temperatura en evaluación.** Si evalúas con `temperature > 0` las métricas tienen ruido run-to-run. Fija `temperature=0` para benchmarks reproducibles.
- **No versionar el golden dataset ni el prompt.** Reproducir resultados viejos es imposible. Guárdalos en git con tag.
- **Alertar sin umbrales por severidad.** Alertar en Slack cada vez que `faithfulness < 1.0` genera fatiga. Define tiers: *info / warning / page*.

## Resumen

- QA en RAG no es un test aislado: es una capa continua en **cuatro niveles** — unit tests, evaluación end-to-end, detección de alucinaciones, monitoreo en vivo.
- Las métricas se agrupan en tres familias: **retrieval** (Precision@K, Recall, MRR, nDCG), **generation** (Faithfulness, Answer Relevance, Context Precision/Recall) y **sistema** (latencia, errores, costo, CSAT).
- Mantén un **golden dataset** versionado de 50-500 triples `(query, respuesta_esperada, fuentes)` curado por expertos y refrescado trimestralmente.
- **RAGAS** es el estándar de facto para medir faithfulness y relevancia con LLM-as-judge; combinado con tu dataset dorado te da señal por commit.
- La **detección de alucinaciones** combina checks léxicos baratos (números, fechas, entidades) + un LLM-judge que valida frase por frase.
- Siempre que la validación falle, **degrada la respuesta**: mejor "no sé" que un número inventado con confianza.
- Usa el **LLM-as-judge con un modelo distinto** al generador y con `temperature=0`.
- Monitoreo en producción debe trackear calidad, no solo uptime: `flagged_rate`, `context_usage`, latencia p95, feedback del usuario.
- Cierra el loop: correlaciona `thumbs down` con las métricas internas para saber si tus métricas capturan lo que al usuario le importa.
- Sin baselines no hay progreso: compara siempre contra BM25 + un LLM barato.
- Versiona el prompt, el modelo, el chunking y el golden dataset — reproducibilidad es parte de la calidad.
