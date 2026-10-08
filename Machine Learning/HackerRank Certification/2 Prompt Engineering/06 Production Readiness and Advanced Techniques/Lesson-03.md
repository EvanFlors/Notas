# Técnicas Avanzadas: Meta-Prompting, Chaining, Optimización y Grounding

## ¿Qué es?

Las **técnicas avanzadas de prompt engineering** van más allá del par input-output. Permiten construir sistemas que:

- Se **evalúan a sí mismos** (meta-prompting, constitutional AI).
- **Encadenan múltiples llamadas** para descomponer problemas complejos (prompt chaining).
- **Exploran múltiples trayectorias** de razonamiento en paralelo (Tree-of-Thoughts, Graph-of-Thoughts).
- Se **auto-optimizan** midiendo contra ejemplos (DSPy, APE, OPRO).
- **Mitigan alucinaciones** anclando respuestas en fuentes (grounding + citation).

Esta lección reúne el núcleo técnico que convierte un prompt simple en un sistema de razonamiento auditable y mantenible.

### Panorama de técnicas

| Técnica | Qué resuelve | Costo típico |
|---|---|---|
| Meta-prompting / self-critique | Calidad y auto-evaluación | 2x calls |
| Recursive refinement | Tareas que mejoran con iteración | k calls (k=2-5) |
| Tree-of-Thoughts | Problemas con múltiples rutas | 5-20x calls |
| Graph-of-Thoughts | Problemas con dependencias cruzadas | 10-50x calls |
| Prompt chaining | Descomposición y pipelines | n calls (n=pasos) |
| DSPy / APE / OPRO | Optimización automática del prompt | Offline, miles de calls |
| Guardrails + grounding | Seguridad, precisión factual | +20-50% latencia |

## ¿Por qué importa?

Un modelo frontier (GPT-4o, Claude 3.7, Gemini 2.5) es poderoso pero sigue:

- **Alucinando** cuando no tiene el dato: inventa citas, números, APIs.
- **Comprometiendo** instrucciones contradictorias en el mismo prompt.
- **Fallando en tareas largas** que requieren varios pasos encadenados sin perder contexto.
- **Rindiendo peor que su potencial** porque el prompt fue "lo primero que funcionó" y nunca se optimizó sistemáticamente.

Las técnicas avanzadas atacan estos problemas con ingeniería, no con "más modelo". DSPy, por ejemplo, suele cerrar el gap entre un modelo pequeño con pipeline optimizado y un modelo grande con prompt artesanal, a 10x menos costo.

## ¿Cómo funciona?

### Meta-prompting (self-reflection, constitutional AI)

El modelo genera una respuesta, luego la critica contra una **rúbrica explícita**, luego sintetiza una versión mejorada. Variantes:

- **Self-Refine** (Madaan et al., 2023): generar → feedback → refinar.
- **Reflexion** (Shinn et al., 2023): mantener memoria de errores previos.
- **Constitutional AI** (Anthropic, 2022): la rúbrica incluye principios éticos/políticas organizacionales; el modelo reescribe para alinearse con ellos.

### Prompt chaining: patrones

| Patrón | Topología | Cuándo |
|---|---|---|
| **Sequential** | A → B → C | Pipeline con dependencias (extraer → clasificar → responder) |
| **Parallel** | A, B, C en paralelo → agregar | Mismas entradas, perspectivas distintas (crítica legal, financiera, UX) |
| **Map-Reduce** | split → map(f) → reduce | Documento largo → resumen por chunk → síntesis |
| **Router** | clasificar → despachar a sub-prompt | Multi-intent (billing vs. tech vs. sales) |
| **Reflection loop** | generate → critique → refine (hasta criterio) | Calidad > latencia |
| **Branch & synthesize** (ToT) | expandir N ramas → evaluar → elegir/combinar | Problemas con múltiples enfoques |

### Optimización automática del prompt

| Framework | Idea central | Cuándo |
|---|---|---|
| **DSPy** (Stanford) | Programas declarativos (Signatures, Modules) + optimizadores (BootstrapFewShot, MIPROv2) que compilan prompts contra métricas | Pipelines multi-step con dataset etiquetado |
| **APE** (Automatic Prompt Engineer, Zhou et al. 2022) | Modelo genera candidatos de prompt; evalúa; selecciona el mejor | Un solo prompt, baseline rápido |
| **OPRO** (Google, Yang et al. 2023) | LLM como optimizador itera prompts guiado por histórico de scores | Benchmarks con métrica clara |
| **TextGrad** (Stanford, 2024) | "Backprop" de feedback natural a prompts | Pipelines complejos |

### Hallucination mitigation y grounding

| Técnica | Qué hace |
|---|---|
| **RAG** | Inyecta fuentes recuperadas en el contexto |
| **Citation forzada** | Prompt exige `[fuente_id]` tras cada afirmación; valida que exista |
| **Faithfulness scoring** | Métrica (RAGAS, DeepEval) que mide % de afirmaciones soportadas por fuentes |
| **Self-consistency** | Muestrea N respuestas, elige la mayoritaria |
| **Chain-of-Verification** (CoVe, Dhuliawala 2023) | Modelo genera preguntas de verificación sobre su propia respuesta, las responde, corrige |
| **Abstention** | Prompt instruye *"responde 'no sé' si no está en las fuentes"* y se refuerza con validador |

## Ejemplo con código

### 1. Meta-prompting con criterio de parada

```python
from openai import OpenAI
client = OpenAI()

def self_refine(task: str, rubric: str, max_iters=3, min_gain=0.05):
    answer = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{"role": "user", "content": task}]
    ).choices[0].message.content

    history, last_score = [], 0.0
    for i in range(max_iters):
        crit = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[{"role": "user", "content":
                f"Evalúa esta respuesta contra la rúbrica.\n"
                f"RÚBRICA:\n{rubric}\n\nRESPUESTA:\n{answer}\n\n"
                f"Devuelve JSON: {{\"score\":0..1,\"gaps\":[...],\"suggestions\":[...]}}."
            }],
            response_format={"type": "json_object"},
        ).choices[0].message.content
        import json; data = json.loads(crit)
        score, gaps = data["score"], data["gaps"]
        history.append({"iter": i, "score": score, "answer": answer})
        if score - last_score < min_gain and i > 0:
            break                        # ganancia marginal, parar
        last_score = score
        answer = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[{"role": "user", "content":
                f"Mejora la siguiente respuesta atendiendo los gaps.\n"
                f"GAPS:\n{gaps}\n\nRESPUESTA ACTUAL:\n{answer}"}]
        ).choices[0].message.content
    return answer, history
```

### 2. Prompt chaining map-reduce para documentos largos

```python
from concurrent.futures import ThreadPoolExecutor

def chunk(text, size=4000, overlap=200):
    for i in range(0, len(text), size - overlap):
        yield text[i:i + size]

def map_summarize(chunk_text):
    return client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{"role": "user", "content":
            f"Resume en 5 bullets factuales. Si falta contexto, "
            f"escribe '[contexto insuficiente]'.\n\n{chunk_text}"}],
        temperature=0,
    ).choices[0].message.content

def reduce_merge(partials):
    joined = "\n\n---\n\n".join(partials)
    return client.chat.completions.create(
        model="gpt-4o",
        messages=[{"role": "user", "content":
            f"Sintetiza estos resúmenes parciales en uno coherente, "
            f"eliminando repeticiones y conservando toda cifra concreta.\n\n{joined}"}],
        temperature=0,
    ).choices[0].message.content

def summarize_long(doc):
    chunks = list(chunk(doc))
    with ThreadPoolExecutor(max_workers=8) as ex:
        partials = list(ex.map(map_summarize, chunks))
    return reduce_merge(partials)
```

### 3. Router + chaining con LangChain-style composición manual

```python
def classify(query: str) -> str:
    r = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{"role": "user", "content":
            f"Clasifica la intención en una de: billing, tech, sales, other. "
            f"Devuelve solo la etiqueta.\n\nQuery: {query}"}],
        temperature=0,
    )
    return r.choices[0].message.content.strip().lower()

HANDLERS = {
    "billing": "Eres experto en facturación. Pide número de factura.",
    "tech":    "Eres soporte técnico. Pide error exacto y pasos.",
    "sales":   "Eres consultor comercial. Pregunta por caso de uso.",
    "other":   "Deriva amablemente a soporte general.",
}

def route_and_respond(query):
    intent = classify(query)
    system = HANDLERS.get(intent, HANDLERS["other"])
    return client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{"role": "system", "content": system},
                  {"role": "user", "content": query}],
    ).choices[0].message.content
```

### 4. DSPy: Chain-of-Thought compilado contra una métrica

```python
import dspy

lm = dspy.LM("openai/gpt-4o-mini")
dspy.configure(lm=lm)

class ClassifyIntent(dspy.Signature):
    """Clasifica la intención de un ticket de soporte."""
    ticket: str = dspy.InputField()
    intent: str = dspy.OutputField(desc="billing | tech | sales | other")

class Pipeline(dspy.Module):
    def __init__(self):
        self.cot = dspy.ChainOfThought(ClassifyIntent)

    def forward(self, ticket):
        return self.cot(ticket=ticket)

# Dataset etiquetado
train = [dspy.Example(ticket="no me llegó la factura de marzo",   intent="billing").with_inputs("ticket"),
         dspy.Example(ticket="la API devuelve 500 al llamar /x",  intent="tech").with_inputs("ticket"),
         dspy.Example(ticket="quiero una demo del plan Pro",       intent="sales").with_inputs("ticket")]

def accuracy(ex, pred, trace=None):
    return ex.intent.lower() == pred.intent.lower()

optimizer = dspy.BootstrapFewShotWithRandomSearch(
    metric=accuracy, max_bootstrapped_demos=4, num_candidate_programs=8
)
compiled = optimizer.compile(Pipeline(), trainset=train)
print(compiled(ticket="no puedo entrar a mi cuenta").intent)
```

DSPy **genera y optimiza el prompt automáticamente** incluyendo demos few-shot que maximizan la métrica. Cambiar `BootstrapFewShotWithRandomSearch` por `MIPROv2` usa un optimizador bayesiano más potente.

### 5. Tree-of-Thoughts simplificado

```python
def tot(problem, branches: dict, k_best=1):
    scores = {}
    for name, strategy in branches.items():
        r = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[{"role": "user", "content":
                f"Problema: {problem}\nEstrategia: {strategy}\n"
                f"Desarrolla la solución y auto-asigna un score 0-10. "
                f"Devuelve JSON {{\"solution\":...,\"score\":...}}."}],
            response_format={"type": "json_object"},
            temperature=0.7,
        )
        import json; d = json.loads(r.choices[0].message.content)
        scores[name] = d
    best = sorted(scores.items(), key=lambda kv: -kv[1]["score"])[:k_best]
    return best, scores
```

### 6. Hallucination detection con faithfulness (RAGAS)

```python
# pip install ragas datasets
from ragas import evaluate
from ragas.metrics import faithfulness, answer_relevancy, context_precision
from datasets import Dataset

sample = Dataset.from_dict({
    "question":      ["¿Cuántos empleados tiene Acme en 2024?"],
    "answer":        ["Acme tiene 1,250 empleados a cierre de 2024."],
    "contexts":      [["Al 31 dic 2024, Acme reportó 1,250 empleados totales."]],
    "ground_truth":  ["1,250 empleados"],
})
report = evaluate(sample, metrics=[faithfulness, answer_relevancy, context_precision])
print(report)
```

`faithfulness` baja si la respuesta contiene afirmaciones no soportadas por `contexts`. Úsalo como gate en CI y como monitor en producción (sampleando respuestas).

### 7. Chain-of-Verification para reducir alucinación

```python
def cove(question):
    draft = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{"role": "user", "content": question}]
    ).choices[0].message.content

    # 1) El modelo propone preguntas de verificación sobre su propia respuesta
    verify_qs = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{"role": "user", "content":
            f"Dada esta respuesta:\n{draft}\n\n"
            f"Lista 5 preguntas de verificación atómicas y falsables."}],
    ).choices[0].message.content

    # 2) Las responde independientemente
    answers = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{"role": "user", "content":
            f"Responde cada pregunta de forma breve y conservadora. "
            f"Si no estás seguro, di 'no sé'.\n\n{verify_qs}"}],
    ).choices[0].message.content

    # 3) Revisa la respuesta inicial a la luz de las verificaciones
    final = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{"role": "user", "content":
            f"Pregunta original: {question}\n"
            f"Borrador: {draft}\n"
            f"Verificaciones: {answers}\n\n"
            f"Reescribe el borrador eliminando toda afirmación no verificada."}]
    ).choices[0].message.content
    return final
```

### 8. Grounding con citas forzadas y validación

```python
import re

SYSTEM = """Responde ÚNICAMENTE con información de las fuentes.
Cada afirmación factual debe terminar con [S<id>]. Si no hay fuente
que respalde una afirmación, no la incluyas. Si no puedes responder,
di literalmente: 'No tengo información suficiente'."""

def answer_with_citations(question, sources):
    ctx = "\n".join(f"[S{i}] {s}" for i, s in enumerate(sources))
    r = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{"role": "system", "content": SYSTEM},
                  {"role": "user", "content": f"Fuentes:\n{ctx}\n\nPregunta: {question}"}],
        temperature=0,
    ).choices[0].message.content

    # Validar que toda cita referencie una fuente existente
    used = set(int(x) for x in re.findall(r"\[S(\d+)\]", r))
    if any(i >= len(sources) for i in used):
        raise ValueError("El modelo citó una fuente inexistente")
    return r
```

## Errores comunes

### Meta-prompting sin criterio de parada ⇒ loops infinitos

El bucle "crítica → refina → crítica" puede oscilar sin converger o incluso degradar. Mitigaciones:

- `max_iters` duro (3-5).
- Tracking de score con parada por **ganancia marginal < umbral**.
- Validación de que la versión N no sea peor que N-1 (si lo es, quédate con N-1).

### Chains sin manejo de errores por paso

Un chain de 5 pasos tiene 5 puntos de fallo. Sin try/retry/fallback por paso, un timeout rompe todo. Usa:

- Retry exponencial por llamada.
- Fallback a modelo más barato o respuesta por defecto.
- Logging estructurado del output intermedio para debuggear.

### Prompt chaining cuando bastaba un solo prompt

Partir un prompt en 5 llamadas multiplica latencia y costo. Antes de encadenar, prueba que un prompt bien estructurado no resuelva el problema. Encadena solo cuando:

- Hay descomposición natural con dependencias.
- Los pasos intermedios necesitan tools distintos.
- Necesitas control fino de un paso (p.ej. clasificación con alta precisión).

### DSPy sin dataset de calidad

DSPy optimiza contra la **métrica que le des**. Si tu dataset es ruidoso o la métrica es `exact_match` cuando el problema es generativo, el optimizado será basura con confianza. Invierte en 50-200 ejemplos limpios antes de compilar.

### Tree-of-Thoughts aplicado a problemas simples

ToT multiplica el costo por 5-20x. Para clasificación o Q&A directo, es desperdicio. Reserva ToT para planeación, diseño, debugging de problemas donde "la primera idea" históricamente falla.

### No separar razonamiento de respuesta en citation

Si el modelo responde libre y luego "le pides citas", inventa. La citation efectiva **exige** que cada afirmación nazca con su `[fuente_id]` y valida programáticamente que las fuentes existen.

### Confiar en self-consistency sin diversidad

Muestrear 10 respuestas con `temperature=0` da 10 respuestas idénticas. Self-consistency requiere `temperature >= 0.7` y suficiente varianza para que el voto mayoritario tenga sentido.

### No medir faithfulness en producción

Un sistema RAG puede verse bien en demos y alucinar en 15% de queries reales. Muestrea 1-5% del tráfico, pásalo por `faithfulness` (RAGAS, DeepEval, Ragas) y alerta si baja de un umbral.

### Grounding sin control de abstención

Prompts que dicen *"responde con las fuentes"* pero no refuerzan *"di 'no sé' si no están"* producen respuestas inventadas cuando el retrieval falla. La abstención debe ser:

- Instruida en el prompt.
- Validada post-hoc (si no hay citas, rechazar o devolver "no sé").
- Medida como KPI (tasa de abstención sana ~5-15% en RAG real).

### Compilar DSPy una vez y nunca más

Datos y modelos cambian. Recompila periódicamente contra un conjunto de evaluación actualizado, con la misma disciplina que reentrenas un modelo ML tradicional.

## Resumen

- **Meta-prompting / self-refine** mejora calidad vía auto-crítica; limita iteraciones y mide ganancia marginal para evitar loops.
- **Prompt chaining** descompone problemas: patrones sequential, parallel, map-reduce, router, reflection, branch-and-synthesize.
- **Tree/Graph-of-Thoughts** explora múltiples trayectorias cuando el problema lo justifica (costo 5-50x).
- **DSPy** convierte prompts en programas declarativos (Signatures, Modules) y **compila** contra una métrica con optimizadores (BootstrapFewShot, MIPROv2).
- **APE / OPRO / TextGrad** son alternativas de optimización automática del prompt mismo.
- **Alucinación** se mitiga con: grounding (RAG), citas forzadas y validadas, Chain-of-Verification, self-consistency, abstención instruida, faithfulness scoring (RAGAS/DeepEval).
- **Constitutional AI** (Anthropic) extiende meta-prompting embebiendo principios de valor en la auto-evaluación.
- Técnicas avanzadas no son gratis: miden en latencia, dólares y complejidad. Úsalas solo cuando el costo se justifica contra el valor.
- Combinadas con las defensas de la Lección 2 (guardrails, PII, injection) y la rigor estadístico de la Lección 1 (A/B tests), forman la base de un sistema de LLM listo para producción.
