# LLM-as-a-Judge

## ¿Qué es?

**LLM-as-a-Judge** es el patrón de evaluación que usa un modelo de lenguaje como *evaluador* de las salidas de otro modelo (o del mismo). En vez de medir solapamiento léxico con una referencia, le pides a un LLM que **lea el output y lo califique** según una rúbrica estructurada: scores, justificaciones, flags y sugerencias.

Nació como una forma pragmática de aproximar la evaluación humana a escala. En 2023 el paper *"Judging LLM-as-a-Judge with MT-Bench and Chatbot Arena"* (Zheng et al.) mostró que GPT-4 como juez coincide con humanos expertos ~85% del tiempo, un nivel comparable al acuerdo entre dos humanos entrenados. Desde entonces es el estándar de facto para evaluar chatbots, agentes y pipelines RAG.

### Modalidades principales

| Modalidad | Qué hace el juez | Cuándo usarla |
|---|---|---|
| **Scoring directo (pointwise)** | Da score 1-5 (o 1-10) a cada output | Tareas con rúbrica estable; tracking longitudinal |
| **Pairwise comparison** | Dado A y B, elige el mejor (o empate) | Comparar modelos, A/B tests, construir Elo rankings |
| **Reference-based** | Compara output contra una referencia ideal | Tienes golden answers y quieres medir fidelidad |
| **Reference-free** | Juzga sin referencia | Preguntas abiertas, generación creativa |
| **Chain-of-thought judge** | Razona antes de dar score | Tareas complejas; mejora calibración ~10-15% |

## ¿Por qué importa?

Las métricas tradicionales (lección 1) son ciegas a dimensiones que a los usuarios sí les importan: empatía, pertinencia, seguridad, factualidad en respuestas abiertas, tono de marca. Contratar humanos para evaluar 10,000 respuestas de un chatbot cuesta semanas y miles de dólares; un LLM judge lo hace en minutos por centavos.

**Casos típicos donde LLM-as-a-judge brilla:**

- Chatbots de soporte: medir si la respuesta *resuelve* el problema, no sólo si suena parecida a una plantilla.
- RAG: evaluar *faithfulness* (¿se apega al contexto recuperado?) y *answer relevance*.
- Agentes: juzgar si la secuencia de acciones es correcta aunque la salida final varíe en forma.
- Fine-tuning / RLHF: generar señales de preferencia a escala para entrenar reward models.
- Red-teaming: clasificar si una respuesta cruza una línea de seguridad.

### Comparación costo/calidad

| Enfoque | $ por 1k evals | Correlación con humano | Latencia |
|---|---|---|---|
| Exact match / regex | ~$0 | 0.3-0.5 (según tarea) | ms |
| BLEU / ROUGE | ~$0 | 0.4-0.6 | ms |
| Cosine (embeddings) | ~$0.05 | 0.5-0.7 | ms |
| **LLM judge (GPT-4 class)** | **~$5-20** | **0.75-0.90** | **1-5 s** |
| Humano experto | ~$500-2000 | 1.0 (por definición) | horas-días |

## ¿Cómo funciona?

El flujo canónico tiene cinco pasos:

```
1. Definir dimensiones y rúbrica (observable, medible)
2. Construir prompt del juez (rol + criterios + ejemplos + formato)
3. Correr sobre dataset (del golden set o de logs de producción)
4. Parsear salida estructurada (JSON)
5. Agregar + alertar + validar vs humano (calibración)
```

### Dimensiones típicas y qué miden

| Dimensión | Pregunta operativa |
|---|---|
| Accuracy / Correctness | ¿La información es factualmente correcta? |
| Relevance | ¿Responde a lo que se preguntó, sin desviarse? |
| Faithfulness (RAG) | ¿La respuesta está respaldada por el contexto recuperado? |
| Completeness | ¿Cubre todos los aspectos de la pregunta? |
| Helpfulness | ¿Ayuda al usuario a avanzar? |
| Clarity | ¿Es claro y bien estructurado? |
| Tone / Brand voice | ¿Suena como mi marca? |
| Safety | ¿Está libre de contenido dañino, sesgo o PII? |
| Format compliance | ¿Respeta el formato pedido (JSON, markdown, longitud)? |

Regla práctica: **3-5 dimensiones bien definidas superan a rúbricas de 10+**. Más dimensiones degradan la consistencia del juez.

### Scoring directo vs pairwise

El scoring directo es intuitivo pero sufre de **sesgo de calibración**: distintos jueces (o el mismo juez con prompts ligeramente distintos) distribuyen scores de forma diferente. Un GPT-4o puede dar media 4.2/5 mientras Claude Sonnet da 3.8/5 por los mismos outputs.

El pairwise es más robusto porque sólo pide **un orden relativo**. Combinando miles de comparaciones se construye un ranking Elo (como en Chatbot Arena). Precio: necesitas N·(N-1)/2 comparaciones para N candidatos, aunque sampling inteligente lo reduce.

### Chain-of-thought en el juez

Pedir al juez que **razone antes de puntuar** mejora consistencia:

```
Primero describe qué hace bien la respuesta.
Luego describe qué hace mal.
Luego da un score 1-5 justificado por los puntos anteriores.
```

Esto reduce el sesgo de "primera impresión" y suele subir correlación con humanos 10-15 puntos.

### Cohen's kappa para validar al juez

Antes de confiar en un juez, **mídelo contra humanos** sobre una muestra de 100-300 casos. Calcula Cohen's κ:

```
κ = (p_o − p_e) / (1 − p_e)
```

Si κ ≥ 0.6 entre el juez LLM y el humano consenso, puedes escalarlo. Si κ < 0.4, la rúbrica es ambigua o el juez no entiende la tarea; **no despliegues**.

### Rúbrica bien diseñada (ejemplo escala 1-5)

**Helpfulness para soporte técnico:**

| Nivel | Descripción operacional |
|---|---|
| 5 | Resuelve el problema con pasos específicos y verificables. El usuario puede ejecutar la solución sin pedir más info. |
| 4 | Resuelve el problema pero omite un paso menor o requiere que el usuario infiera un detalle. |
| 3 | Direcciona el problema en la dirección correcta, pero faltan 2+ pasos o requiere clarificación significativa. |
| 2 | Toca el tema correcto pero no provee una ruta accionable. |
| 1 | No aborda el problema del usuario o lo malinterpreta por completo. |

Cada nivel es **observable** (puedes mirar la respuesta y clasificarla) y **medible** (das el mismo score ante el mismo output).

### Jueces y herramientas del ecosistema

| Herramienta | Enfoque | Fortaleza |
|---|---|---|
| **Promptfoo** | YAML declarativo + CI | Rápido para arrancar, asserts mezcla deterministas + LLM judge |
| **DeepEval** | pytest-first para LLMs | 14+ métricas prebuilt (G-Eval, hallucination, bias) |
| **Ragas** | Especializado en RAG | Faithfulness, answer relevance, context precision/recall |
| **LangSmith evaluators** | Trazabilidad + evals | Integración nativa con LangChain |
| **OpenAI evals** | Framework open source | Compatible con registros de OpenAI; útil para fine-tuning |
| **Braintrust** | SaaS para eval + experiment tracking | UI pulida, buena para equipos |
| **Inspect** (UK AI Safety) | Evals de seguridad | Red-teaming, jailbreaks |

## Ejemplo con código

### Juez pairwise con Anthropic Claude

```python
import json
from anthropic import Anthropic

client = Anthropic()

JUDGE_SYSTEM = """Eres un evaluador experto de respuestas de IA. Dado una pregunta
y dos respuestas (A y B), eliges cuál es mejor según los criterios dados.
Sé imparcial: ignora el orden en que te presentan A y B."""

JUDGE_USER = """Pregunta del usuario:
<question>{question}</question>

Respuesta A:
<a>{answer_a}</a>

Respuesta B:
<b>{answer_b}</b>

Criterios de evaluación:
1. Correctness: ¿Es factualmente correcta?
2. Helpfulness: ¿Resuelve lo que el usuario preguntó?
3. Clarity: ¿Es clara y bien estructurada?

Razona paso a paso en <reasoning>...</reasoning>, luego responde en JSON:
{{"winner": "A" | "B" | "tie", "confidence": 0.0-1.0, "reasoning_summary": "..."}}
"""

def judge_pairwise(question: str, answer_a: str, answer_b: str) -> dict:
    # Mitigación de position bias: evaluar en ambos órdenes y agregar
    def _one_call(a, b):
        msg = client.messages.create(
            model="claude-sonnet-4-5",
            max_tokens=1024,
            temperature=0.0,
            system=JUDGE_SYSTEM,
            messages=[{
                "role": "user",
                "content": JUDGE_USER.format(question=question, answer_a=a, answer_b=b)
            }],
        )
        text = msg.content[0].text
        json_part = text.split("{", 1)[1].rsplit("}", 1)[0]
        return json.loads("{" + json_part + "}")

    r1 = _one_call(answer_a, answer_b)
    r2 = _one_call(answer_b, answer_a)  # orden invertido

    # Normalizar: r2.winner="A" en realidad vota por answer_b
    swap = {"A": "B", "B": "A", "tie": "tie"}
    votes = [r1["winner"], swap[r2["winner"]]]

    if votes[0] == votes[1]:
        final = votes[0]
    else:
        final = "tie"  # posición importó → inconclusivo

    return {
        "winner": final,
        "confidence": (r1["confidence"] + r2["confidence"]) / 2,
        "position_bias_detected": votes[0] != votes[1],
    }
```

Siempre que uses pairwise, **evalúa en ambos órdenes** y marca como *tie* cuando el juez cambia su veredicto al voltear la posición. Es el único control barato contra position bias.

### Juez pointwise con rúbrica estricta usando DeepEval

```python
from deepeval import evaluate
from deepeval.metrics import GEval
from deepeval.test_case import LLMTestCase, LLMTestCaseParams

correctness = GEval(
    name="Correctness",
    criteria=(
        "Determina si la respuesta actual (actual_output) es factualmente "
        "correcta y consistente con la respuesta esperada (expected_output)."
    ),
    evaluation_steps=[
        "Compara los hechos clave del output actual con los del esperado.",
        "Penaliza fuertemente contradicciones factuales (score ≤ 2).",
        "Permite paráfrasis y reordenamientos si preservan el significado.",
        "Da 5 si todos los hechos coinciden y no hay información inventada.",
    ],
    evaluation_params=[LLMTestCaseParams.INPUT, LLMTestCaseParams.ACTUAL_OUTPUT,
                       LLMTestCaseParams.EXPECTED_OUTPUT],
    threshold=0.7,
    model="gpt-4o",
)

test_cases = [
    LLMTestCase(
        input="¿En qué año se fundó la ONU?",
        actual_output="La ONU se fundó en 1945, tras la Segunda Guerra Mundial.",
        expected_output="1945",
    ),
    LLMTestCase(
        input="¿Cuál es la capital de Australia?",
        actual_output="Sídney es la capital de Australia.",  # error factual
        expected_output="Canberra",
    ),
]

results = evaluate(test_cases=test_cases, metrics=[correctness])
```

DeepEval orquesta las llamadas al juez, calcula umbrales, genera reportes y se integra como fixtures de pytest.

### Evaluación de RAG con Ragas

Para pipelines RAG, Ragas provee las métricas canónicas:

```python
from ragas import evaluate
from ragas.metrics import faithfulness, answer_relevancy, context_precision, context_recall
from datasets import Dataset

data = {
    "question": ["¿Qué es un embedding?"],
    "answer": ["Un embedding es un vector denso que representa un texto en un espacio continuo."],
    "contexts": [[
        "Un embedding es una representación numérica densa de datos como texto o imágenes.",
        "Los modelos de embeddings mapean entradas a vectores de alta dimensión."
    ]],
    "ground_truth": ["Un embedding es una representación vectorial densa de datos."],
}

result = evaluate(
    Dataset.from_dict(data),
    metrics=[faithfulness, answer_relevancy, context_precision, context_recall],
)
print(result)
# {'faithfulness': 1.0, 'answer_relevancy': 0.94,
#  'context_precision': 1.0, 'context_recall': 1.0}
```

- **Faithfulness:** cada afirmación de la respuesta está respaldada por el contexto.
- **Answer relevancy:** la respuesta aborda la pregunta.
- **Context precision/recall:** ¿los chunks recuperados son relevantes y suficientes?

### Config declarativa con Promptfoo (LLM-rubric)

```yaml
prompts:
  - "Responde al cliente profesionalmente: {{query}}"

providers:
  - openai:gpt-4o-mini

tests:
  - vars:
      query: "Mi paquete lleva 3 semanas de retraso, estoy harto."
    assert:
      - type: llm-rubric
        provider: anthropic:claude-sonnet-4-5
        value: |
          La respuesta debe:
          1. Reconocer la frustración del cliente con empatía explícita
          2. Ofrecer un siguiente paso concreto (tracking, reembolso, escalamiento)
          3. Mantener tono profesional, no defensivo
          4. No prometer compensaciones específicas sin verificar
          Puntúa 1-5 y rechaza si score < 4.
```

## Errores comunes

- **Usar el mismo modelo como generador y como juez.** Un GPT-4o juzgando a GPT-4o infla scores: el juez tiende a preferir el estilo que él mismo produciría. Si puedes, usa un juez de familia distinta (Claude juzga a GPT, o viceversa).
- **No controlar position bias en pairwise.** Los LLMs tienen un sesgo medible a preferir "la primera opción". Siempre evalúa en ambos órdenes y promedia.
- **Rúbricas vagas ("evalúa la calidad").** Son el error #1. Si tus humanos no logran κ ≥ 0.6 con esa rúbrica, el juez LLM tampoco. Reescribe antes de culpar al modelo.
- **No validar al juez contra humanos.** Un juez descalibrado se convierte en un oráculo falso. Antes de desplegarlo en CI, compara con 100-300 anotaciones humanas y calcula κ.
- **Temperatura > 0 en el juez.** Introduce variabilidad gratuita. Usa `temperature=0` siempre que puedas (algunos modelos como Claude requieren un valor explícito).
- **Confiar en scores absolutos sin agregación.** Un score de 3.8 no significa nada en aislamiento; sí significa algo si subió de 3.5 la semana pasada. Trackea tendencias, no puntos.
- **Judge drift sin monitoreo.** El modelo del juez (ej. `gpt-4o`) recibe actualizaciones silenciosas. Un cambio de versión puede desplazar la distribución de scores. Fija versión (`gpt-4o-2024-11-20`) y re-calibra en cada upgrade.
- **Rúbricas de 10+ dimensiones.** La consistencia del juez degrada rápido. 3-5 es el sweet spot.
- **No capturar razonamiento.** Pedir sólo "score" sin "reasoning" pierde la señal más útil: *por qué* el juez bajó la nota. Siempre pide justificación breve.
- **Costo descontrolado.** Juzgar 100k outputs con GPT-4o cuesta cientos de dólares. Usa jueces baratos (Haiku, GPT-4o-mini) para screening y escala el juez caro sólo a casos ambiguos.

## Resumen

- **LLM-as-a-Judge** usa un LLM para calificar outputs de otro LLM contra una rúbrica estructurada; aproxima evaluación humana a 1-10% del costo.
- Modalidades: **pointwise** (score absoluto), **pairwise** (comparación A vs B, base de MT-Bench y Chatbot Arena), **reference-based** y **reference-free**.
- Rúbrica efectiva = **3-5 dimensiones** observables y medibles, cada nivel con descripción operacional.
- Mitiga sesgos: **temperatura 0**, **chain-of-thought** antes de scorear, **evaluación en ambos órdenes** para pairwise, **juez de familia distinta** al generador.
- Siempre **valida al juez contra humanos** con Cohen's κ ≥ 0.6 antes de confiar en él.
- Herramientas: **DeepEval** y **Ragas** (métricas prebuilt), **Promptfoo** (YAML declarativo), **Braintrust** y **LangSmith** (SaaS con tracking), **OpenAI evals** (open source).
- Combina con métricas tradicionales: deterministas para screening barato, LLM judge para casos que pasan screening.
- Capacita siempre la justificación textual: el *por qué* es más accionable que el score.
