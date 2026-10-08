# Self-RAG, CRAG y Agentic RAG

## ¿Qué es?

**Self-RAG** (Self-Reflective Retrieval-Augmented Generation, Asai et al. 2023) es un patrón donde el LLM emite **reflection tokens** especiales que deciden, durante la generación, si recuperar documentos, si son relevantes, si la respuesta está soportada y si es útil. El modelo no solo genera: también **se evalúa a sí mismo** paso a paso.

**CRAG** (Corrective Retrieval-Augmented Generation, Yan et al. 2024) agrega una capa de **corrección**: un evaluador ligero clasifica cada chunk recuperado como `Correct` / `Incorrect` / `Ambiguous`, y en los dos últimos casos dispara una re-escritura de query o una búsqueda web de fallback.

**Agentic RAG** eleva el patrón a un **agente** con herramientas: el LLM planea, elige entre múltiples retrievers (vector, grafo, SQL, web), ejecuta sub-queries, verifica resultados y decide cuándo parar. Es RAG orquestado por un loop ReAct.

| Patrón | Decide retrieve? | Verifica relevancia? | Verifica soporte? | Re-query? | Multi-herramienta? |
|---|---|---|---|---|---|
| Naive RAG | No (siempre) | No | No | No | No |
| Self-RAG | Sí (reflection token) | Sí (ISREL) | Sí (ISSUP) | Opcional | No |
| CRAG | Sí | Sí (evaluador externo) | Sí | Sí (web fallback) | A veces |
| Agentic RAG | Sí (planner LLM) | Sí | Sí | Sí (loop) | Sí (vector + KG + API + SQL) |

### Reflection tokens de Self-RAG

| Token | Significado | Valores |
|---|---|---|
| `Retrieve` | ¿Necesito buscar? | `Yes` / `No` / `Continue` |
| `ISREL` | ¿Este pasaje es relevante? | `Relevant` / `Irrelevant` |
| `ISSUP` | ¿Mi respuesta está soportada? | `Fully` / `Partially` / `No support` |
| `ISUSE` | ¿La respuesta es útil al usuario? | `5` (muy útil) a `1` (inútil) |

## ¿Por qué importa?

El RAG clásico siempre recupera, aunque la pregunta sea "hola, ¿cómo estás?". Eso quema latencia (200-800 ms por retrieval), tokens (cada chunk cuesta) y, peor, **puede empeorar la respuesta** cuando el retrieval es ruidoso: el LLM se ancla en chunks irrelevantes y aluncina citas.

Los problemas que Self-RAG / CRAG / agentic RAG resuelven:

- **Over-retrieval:** preguntas de sentido común se responden mejor sin contexto.
- **Under-retrieval:** una sola pasada no basta para preguntas multi-hop ("¿Qué CEO de qué empresa dijo X en qué año?").
- **Alucinaciones silenciosas:** el LLM responde con confianza aunque el contexto no soporte la respuesta.
- **Degradación por ruido:** chunks irrelevantes en el prompt bajan la calidad.

Impacto medible: en el paper original de Self-RAG, mejoró **+10-20 puntos de factualidad** sobre RAG estándar en benchmarks de QA abierto. CRAG mostró ganancias similares con menor costo computacional al usar un evaluador T5 pequeño.

## ¿Cómo funciona?

### Self-RAG en 6 pasos

1. **Decisión de recuperar.** El modelo emite `[Retrieve=Yes/No]` tras leer la query.
2. **Recuperación** (si aplica): top-k chunks del índice vectorial/híbrido.
3. **Evaluación de relevancia** por chunk: `[ISREL=Relevant/Irrelevant]`.
4. **Generación** condicionada a los chunks relevantes.
5. **Evaluación de soporte**: `[ISSUP=Fully/Partially/No]` cotejando la respuesta contra los chunks.
6. **Evaluación de utilidad**: `[ISUSE=1..5]` sobre la respuesta final.

Si `ISSUP` es bajo → se re-escribe la query (pseudo-relevance feedback) y se repite.

### CRAG en 3 pasos

1. **Retrieve** inicial.
2. **Evaluate** cada chunk con un modelo liviano (T5-large o LLM barato) → acción:
   - `Correct` → *knowledge refinement* (descompone chunks en "strips", filtra irrelevantes).
   - `Incorrect` → *web search* como fallback (ej. Tavily, Serper).
   - `Ambiguous` → combina ambos.
3. **Generate** con el conocimiento refinado.

### Agentic RAG

Un agente ReAct con herramientas:

```
Thought: Esto requiere datos financieros y una política interna.
Action: query_sql(table="revenue", quarter="Q3-2024")
Observation: 12.4M USD
Thought: Ahora necesito el umbral de aprobación.
Action: vector_search(query="umbral aprobación capex", tenant="acme")
Observation: "Capex > 10M requiere aprobación del CFO..."
Thought: Puedo responder.
Final Answer: ...
```

### Pseudo-relevance feedback

Técnica de IR clásica (años 90) que vuelve a brillar en RAG: después de un primer retrieve, se asume que los top-k son relevantes, se extraen términos frecuentes nuevos y se expande la query original. Útil cuando la query inicial es corta o ambigua.

## Ejemplo con código

### Self-RAG con decision gates

```python
from __future__ import annotations
from dataclasses import dataclass, field
from enum import Enum
from typing import Protocol, List

class Retrieve(Enum):
    YES = "yes"; NO = "no"; CONTINUE = "continue"

class ISREL(Enum):
    RELEVANT = "relevant"; IRRELEVANT = "irrelevant"

class ISSUP(Enum):
    FULLY = "fully"; PARTIALLY = "partially"; NO = "no_support"

@dataclass
class Trace:
    query: str
    retrieve: Retrieve | None = None
    chunks: List[str] = field(default_factory=list)
    isrel: List[ISREL] = field(default_factory=list)
    answer: str = ""
    issup: ISSUP | None = None
    iterations: int = 0

class LLM(Protocol):
    def classify(self, system: str, user: str) -> str: ...
    def generate(self, prompt: str) -> str: ...
    def rewrite(self, query: str, hint: str) -> str: ...

def decide_retrieve(query: str, llm: LLM) -> Retrieve:
    label = llm.classify(
        system="Responde solo 'yes' o 'no'. ¿Esta pregunta requiere buscar en documentos?",
        user=query,
    )
    return Retrieve.YES if label.strip().lower() == "yes" else Retrieve.NO

def score_relevance(query: str, chunk: str, llm: LLM) -> ISREL:
    label = llm.classify(
        system="Responde solo 'relevant' o 'irrelevant'.",
        user=f"Pregunta: {query}\nPasaje: {chunk}",
    )
    return ISREL.RELEVANT if "relevant" in label.lower() else ISREL.IRRELEVANT

def score_support(answer: str, chunks: list[str], llm: LLM) -> ISSUP:
    label = llm.classify(
        system="Responde 'fully', 'partially' o 'no'.",
        user=f"Respuesta: {answer}\nContexto: {' '.join(chunks)}",
    )
    return {"fully": ISSUP.FULLY, "partially": ISSUP.PARTIALLY}.get(
        label.strip().lower(), ISSUP.NO
    )

def self_rag(query: str, retriever, llm: LLM, max_iter: int = 2) -> Trace:
    trace = Trace(query=query)
    trace.retrieve = decide_retrieve(query, llm)

    if trace.retrieve is Retrieve.NO:
        trace.answer = llm.generate(query)
        return trace

    current_query = query
    for i in range(max_iter):
        trace.iterations = i + 1
        raw = retriever.search(current_query, top_k=8)
        trace.isrel = [score_relevance(query, c.text, llm) for c in raw]
        trace.chunks = [c.text for c, r in zip(raw, trace.isrel) if r is ISREL.RELEVANT]

        if not trace.chunks:
            # Ningún chunk relevante → reescribe query
            current_query = llm.rewrite(query, hint="usa sinónimos y términos técnicos")
            continue

        prompt = f"Contexto:\n{chr(10).join(trace.chunks)}\n\nPregunta: {query}"
        trace.answer = llm.generate(prompt)
        trace.issup = score_support(trace.answer, trace.chunks, llm)

        if trace.issup is ISSUP.FULLY:
            return trace
        # Soporte parcial o ninguno → reescribe y reintenta
        current_query = llm.rewrite(query, hint=f"la respuesta anterior fue '{trace.answer[:80]}'")

    return trace
```

### CRAG con evaluador y fallback web

```python
from typing import Literal

Verdict = Literal["correct", "incorrect", "ambiguous"]

def crag_evaluate(query: str, chunk: str, light_llm) -> Verdict:
    """Un modelo barato (T5-large, GPT-4o-mini) juzga cada chunk."""
    prompt = (
        f"Query: {query}\nPassage: {chunk}\n"
        "Classify as 'correct', 'incorrect' or 'ambiguous' (one word)."
    )
    out = light_llm.generate(prompt).strip().lower()
    return out if out in ("correct", "incorrect", "ambiguous") else "ambiguous"

def strip_knowledge(chunk: str) -> list[str]:
    """Descompone chunk en 'strips' (frases) para filtrado fino."""
    return [s.strip() for s in chunk.split(". ") if len(s.strip()) > 20]

def crag(query: str, retriever, web_search, llm, light_llm) -> str:
    chunks = retriever.search(query, top_k=5)
    verdicts = [crag_evaluate(query, c.text, light_llm) for c in chunks]

    corrects = [c for c, v in zip(chunks, verdicts) if v == "correct"]
    incorrects_count = sum(1 for v in verdicts if v == "incorrect")

    knowledge: list[str] = []
    if corrects:
        for c in corrects:
            # Refinamiento: strips relevantes solamente
            strips = strip_knowledge(c.text)
            knowledge.extend(s for s in strips if crag_evaluate(query, s, light_llm) == "correct")

    if incorrects_count >= len(chunks) // 2:
        # Mayoría ruidosa → busca en web
        web_results = web_search(query)
        knowledge.extend(web_results)

    context = "\n".join(knowledge) or "(sin contexto confiable)"
    return llm.generate(f"Contexto:\n{context}\n\nPregunta: {query}")
```

### Agentic RAG con herramientas múltiples

```python
from typing import Callable, Dict, Any

TOOLS: Dict[str, Callable[..., Any]] = {}

def tool(name: str):
    def deco(fn): TOOLS[name] = fn; return fn
    return deco

@tool("vector_search")
def vector_search(query: str, tenant_id: str, k: int = 5) -> list[dict]:
    return hybrid_retriever.search(query, tenant_id=tenant_id, top_k=k)

@tool("graph_search")
def graph_search(entities: list[str], tenant_id: str) -> list[dict]:
    return graphrag.local_search_raw(entities, tenant_id=tenant_id)

@tool("sql_query")
def sql_query(sql: str, tenant_id: str) -> list[dict]:
    # SIEMPRE con filtro de tenant inyectado por el adapter, no por el LLM
    return db.exec_safely(sql, tenant_id=tenant_id)

def agent_loop(query: str, tenant_id: str, llm, max_steps: int = 6) -> str:
    transcript = [f"User: {query}"]
    for step in range(max_steps):
        plan = llm.generate(
            "Decide una acción. Herramientas: " + ", ".join(TOOLS) +
            "\nFormato: Action: <name>(<json_args>) | FinalAnswer: <text>\n" +
            "\n".join(transcript)
        )
        if plan.startswith("FinalAnswer:"):
            return plan.removeprefix("FinalAnswer:").strip()

        name, args = parse_action(plan)      # tu parser
        args.setdefault("tenant_id", tenant_id)   # RBAC forzado
        obs = TOOLS[name](**args)
        transcript.append(f"Action: {name}({args})\nObservation: {obs}")

    return "No pude responder dentro del presupuesto de pasos."
```

### Observabilidad con LangSmith

```python
import os, uuid
from langsmith import Client, traceable

os.environ["LANGSMITH_PROJECT"] = "rag-prod"
ls = Client()

@traceable(run_type="chain", name="self_rag")
def answered(query: str, user_id: str, tenant_id: str) -> dict:
    trace = self_rag(query, retriever, llm)
    # Audit log mínimo (ver Lesson-03 para schema completo)
    ls.create_feedback(
        run_id=uuid.uuid4(),
        key="issup",
        value=trace.issup.value if trace.issup else "none",
    )
    return {"answer": trace.answer, "iterations": trace.iterations}
```

## Errores comunes

- **Reflection tokens de más.** Encadenar 7 evaluaciones por chunk multiplica latencia y costo sin mejorar precision. Empieza con `Retrieve + ISSUP`; añade `ISREL` solo si el retrieval es ruidoso.
- **Umbral de confianza arbitrario.** `confidence > 0.7` sin calibración empírica suele dar peores resultados que el baseline. Fija umbrales con el golden set y curvas ROC.
- **El LLM se auto-evalúa (sin segundo modelo).** El mismo modelo que generó la respuesta tiende a aprobarla. Usa un *judge* distinto (idealmente más grande o especializado) o un cross-encoder.
- **Loops infinitos de reescritura.** Sin `max_iter`, un agente puede entrar en bucle re-queryando para siempre. Pon tope duro de iteraciones y presupuesto de tokens.
- **Fallback web sin dominio allowlist.** CRAG con web search abierta trae ruido, SEO spam y posible prompt injection desde páginas atacantes. Filtra por dominios confiables (`stackoverflow.com`, docs oficiales, etc.).
- **Agente escribe el `tenant_id`.** NUNCA dejes que el LLM elija el filtro de tenant: inyéctalo en el adapter de la herramienta. De lo contrario, un prompt injection pide `tenant_id=*` y filtras datos.
- **Sin audit trail por paso.** Un agente ReAct hace 5-10 llamadas por query. Si no logueas cada `(action, args, observation)`, debuggear quejas es imposible y violas trazabilidad regulatoria.
- **No evaluar Self-RAG con Ragas.** Añadir reflexión *puede* empeorar las métricas si está mal implementado. Mide `faithfulness` y `answer_relevancy` antes/después.
- **Pseudo-relevance feedback expandiendo con stopwords.** Extraer "los", "de", "que" no ayuda. Filtra por POS (sustantivos, verbos) o por IDF alto.
- **Confundir Self-RAG con fine-tuning obligatorio.** El paper original fine-tunea Llama con tokens especiales, pero el patrón se puede *simular* con prompts estructurados sobre GPT-4o o Claude sin entrenar nada.

## Resumen

- **Self-RAG** (2023) introduce *reflection tokens* para decidir si recuperar, si los chunks son relevantes, si hay soporte y si la respuesta es útil.
- **CRAG** (2024) añade un evaluador externo que etiqueta chunks como `correct/incorrect/ambiguous` y dispara reescritura o búsqueda web.
- **Agentic RAG** convierte el pipeline en un agente ReAct con múltiples herramientas (vector, grafo, SQL, web); el LLM planea los pasos.
- **Pseudo-relevance feedback** reescribe la query usando términos de los top-k iniciales; útil para queries cortas o ambiguas.
- Beneficios demostrados: **menos alucinaciones, menos retrieval innecesario, +10-20 puntos de factualidad** en QA abierto.
- Costos: **más latencia, más tokens, más complejidad operacional**. Mide con Ragas / LangSmith antes y después.
- Reglas de oro: evaluador ≠ generador; `max_iter` siempre; **nunca** dejes que el LLM elija el `tenant_id`; audit log por cada acción del agente.
- En producción, Self-RAG y CRAG se combinan con la higiene empresarial de la Lesson-03: RBAC, PII redaction, encryption y rollback plan.
