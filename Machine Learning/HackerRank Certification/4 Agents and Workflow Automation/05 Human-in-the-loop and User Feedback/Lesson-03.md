# Recolección de feedback y mejora continua

## ¿Qué es?

**Feedback** es cualquier señal, explícita o implícita, que indica si una acción del agente fue útil, correcta o apropiada. Un sistema de recolección de feedback captura esas señales, las agrega, y las convierte en **mejoras concretas** del agente: refinamientos de prompt, ejemplos para fine-tuning, umbrales de confianza recalibrados o guías añadidas a la política.

> **Principio:** sin feedback accionable, un agente está congelado en su configuración inicial. Comete los mismos errores indefinidamente porque nada en su pipeline cierra el ciclo entre comportamiento y expectativa.

### Taxonomía de feedback

| Dimensión | Opciones |
|---|---|
| **Fuente** | Usuario final, aprobador humano, otro agente (LLM-as-judge), telemetría del sistema |
| **Modalidad** | Explícito (thumbs, rating, texto) vs. implícito (click, dwell time, aceptación) |
| **Estructura** | Binario (👍/👎), ordinal (1–5), categórico (helpful / incorrect / good catch), libre (texto) |
| **Momento** | Inline (en el punto de la acción), post-acción (survey), offline (annotation queue) |
| **Granularidad** | A nivel de respuesta completa, de span dentro de la respuesta, de step del agente |

### Explícito vs. implícito

| | Explícito | Implícito |
|---|---|---|
| **Qué es** | El usuario responde una pregunta directa | El sistema infiere satisfacción del comportamiento |
| **Ejemplo** | Click en 👍, rating 4/5, "esto está mal porque..." | Aceptar la sugerencia, modificarla, ignorarla, dismiss |
| **Volumen** | Bajo (friccional) | Alto (sin esfuerzo adicional) |
| **Señal/ruido** | Alta señal, bajo volumen | Alto volumen, señal más ruidosa |
| **Sesgo** | Sesgo de autoselección (quien responde está molesto o encantado) | Sesgo contextual (ignorar ≠ malo) |
| **Uso típico** | Casos ground-truth, dataset curado | Métricas agregadas, detección de drift |

Los dos son complementarios: usa el implícito para medir a escala, el explícito para calibrar y curar datasets de alta calidad.

### Formatos de feedback explícito

| Formato | Ventaja | Desventaja | Cuándo usar |
|---|---|---|---|
| **Thumbs (👍/👎)** | Fricción mínima, decisión binaria rápida | Pierde matices, no diferencia "regular" de "pésimo" | Alto volumen, respuesta rápida |
| **Rating 1–5 / estrellas** | Captura magnitud | Sesgo cultural (algunos nunca dan 5), ambigüedad del medio | Encuestas post-sesión |
| **Categorías (helpful / incorrect / good catch / off-topic)** | Diagnóstica causa raíz | Requiere diseñar categorías correctas | Agentes con fallas identificables |
| **Texto libre** | Captura razones, casos nuevos | Difícil de agregar, bajo volumen | Opcional al dar 👎 |
| **Comparación A/B (pairwise)** | Base de RLHF, muy robusta | Requiere mostrar dos respuestas | Entrenamiento de reward models |

## ¿Por qué importa?

El agente de code review que sugiere "añade manejo de errores extensivo" en archivos de test, es descartado por todos los developers y vuelve a sugerir lo mismo mañana. El patrón es visible en los logs pero el agente nunca lo "ve" porque no hay feedback loop. Resultado: pérdida de confianza del equipo en el agente, uso que decae con el tiempo, y eventualmente deprecación del sistema.

Feedback bien diseñado:

- **Cierra el gap** entre comportamiento del agente y expectativa humana.
- **Detecta regresiones** cuando cambias el modelo o el prompt (satisfacción cae de 0.82 a 0.61 → alerta).
- **Produce datasets curados** para fine-tuning y evaluación continua.
- **Calibra la confianza** del agente: si dice "95% confident" pero acierta solo 60% de las veces, hay que recalibrar.
- **Prioriza esfuerzo de ingeniería**: la categoría con más 👎 marca dónde invertir el próximo sprint.

### RLHF: feedback como fuente del alineamiento

**Reinforcement Learning from Human Feedback** entrena un *reward model* con comparaciones humanas pairwise (`respuesta A es mejor que B`), y usa ese reward model para fine-tunear el LLM base vía PPO. GPT-3.5/4, Claude y Llama están alineados con variantes de RLHF. En aplicaciones downstream, el feedback que recolectas puede alimentar el mismo pipeline (DPO, Constitutional AI, RLAIF).

## ¿Cómo funciona?

### Diseño de la UX de feedback

Reglas prácticas:

- **Baja fricción.** Un click, no un formulario. Opciones por default, texto opcional.
- **Contextual.** En el punto de la acción, no en una página aparte.
- **Reversible.** Permitir cambiar el feedback (ocurre que algo parecía 👎 y luego se entiende por qué fue útil).
- **Específico.** Si el agente produce tres sugerencias, feedback por sugerencia, no por respuesta completa.
- **Transparente.** Comunicar qué se hace con el feedback ("tus respuestas se usan para mejorar el modelo").

### Señales implícitas y sus pesos

| Señal | Interpretación | Peso típico |
|---|---|---|
| `suggestion_applied` | Positivo fuerte | +1.0 |
| `suggestion_modified` | Positivo débil (útil pero imperfecta) | +0.5 |
| `suggestion_ignored` | Negativo débil (puede ser por tiempo) | −0.3 |
| `suggestion_dismissed` | Negativo fuerte | −0.8 |
| `review_disputed` | Negativo fuerte explícito | −0.9 |
| `copy_to_clipboard` | Positivo (reutiliza la salida) | +0.6 |
| `quick_merge_after_review` | Positivo | +0.7 |

### Detección de patrones

Agregar feedback por dimensiones (tipo de archivo, categoría de sugerencia, autor del PR, tamaño del cambio) revela problemas sistemáticos:

- Precisión < 30% en archivos `*.test.ts` → el agente aplica criterios de producción a tests.
- Tasa de rechazo > 70% para sugerencias de tipo "refactor" → prompt sobre-indexado a refactorings.
- Satisfacción < 0.6 para PRs > 500 líneas → el agente pierde contexto en diffs grandes.

### Herramientas del ecosistema

| Herramienta | Uso principal |
|---|---|
| **Langfuse** | Tracing + feedback scores + evaluaciones + datasets |
| **LangSmith** | Traces + annotation queues + datasets + experiments |
| **Humanloop** | Prompt management + feedback + evaluaciones humanas |
| **Argilla** | Annotation UI para NLP, curación de datasets |
| **Label Studio** | Annotation genérica (texto, imagen, audio) |
| **Prodigy** | Active learning + annotation (de spaCy) |

### Active learning: elegir qué anotar

Si tienes capacidad de anotar 100 ejemplos a la semana, no los elijas al azar. Prioriza los que más mejorarán el modelo:

- **Baja confianza del modelo** (el modelo "duda").
- **Alta discrepancia entre múltiples muestras** (inconsistencia).
- **Cerca de la frontera de decisión** (margen pequeño).
- **Fuera de distribución** respecto al dataset actual.

## Ejemplo con código

### Captura de feedback inline (modelo de datos)

```python
import uuid
from dataclasses import dataclass
from datetime import datetime
from enum import Enum

class FeedbackType(str, Enum):
    HELPFUL = "helpful"
    NOT_HELPFUL = "not_helpful"
    INCORRECT = "incorrect"
    GOOD_CATCH = "good_catch"

@dataclass
class FeedbackItem:
    feedback_id: str
    action_id: str
    feedback_type: FeedbackType
    user: str
    timestamp: datetime
    reason: str | None = None  # texto libre opcional
    tags: list[str] | None = None

class FeedbackCollector:
    def __init__(self, storage):
        self.storage = storage

    async def record(self, action_id: str, ftype: str, user: str,
                      reason: str | None = None) -> FeedbackItem:
        item = FeedbackItem(
            feedback_id=str(uuid.uuid4()),
            action_id=action_id,
            feedback_type=FeedbackType(ftype),
            user=user,
            timestamp=datetime.utcnow(),
            reason=reason,
        )
        await self.storage.save_feedback(item)
        if ftype in ("not_helpful", "incorrect"):
            await self._queue_for_review(item)
        return item
```

### UI mínima en Streamlit con buttons de feedback

```python
import streamlit as st

def render_agent_response(response_id: str, text: str):
    st.markdown(text)
    cols = st.columns([1, 1, 1, 1, 6])
    if cols[0].button("👍", key=f"up-{response_id}"):
        save_feedback(response_id, "helpful")
    if cols[1].button("👎", key=f"dn-{response_id}"):
        st.session_state[f"show-reason-{response_id}"] = True
    if cols[2].button("🎯", key=f"catch-{response_id}"):
        save_feedback(response_id, "good_catch")
    if cols[3].button("❌", key=f"wrong-{response_id}"):
        st.session_state[f"show-reason-{response_id}"] = True

    if st.session_state.get(f"show-reason-{response_id}"):
        reason = st.text_area("¿Qué estuvo mal?", key=f"txt-{response_id}")
        if st.button("Enviar", key=f"sub-{response_id}") and reason:
            save_feedback(response_id, "not_helpful", reason=reason)
            st.success("Gracias por la retroalimentación.")

def save_feedback(response_id: str, ftype: str, reason: str | None = None):
    # Enviar a backend / Langfuse / LangSmith
    import httpx
    httpx.post("https://api.ejemplo.com/feedback", json={
        "response_id": response_id, "type": ftype,
        "reason": reason, "user": st.session_state.get("user"),
    })
```

### Logging de feedback a Langfuse

```python
from langfuse import Langfuse

lf = Langfuse(public_key="pk-...", secret_key="sk-...", host="https://cloud.langfuse.com")

def log_generation_and_feedback(prompt: str, output: str, user: str):
    trace = lf.trace(name="code-review", user_id=user, input={"prompt": prompt})
    gen = trace.generation(name="draft", model="claude-sonnet-4-7",
                            input=prompt, output=output)
    return trace.id, gen.id

def submit_feedback(trace_id: str, score_value: float, comment: str | None = None):
    lf.score(
        trace_id=trace_id,
        name="user_rating",         # dimensión evaluada
        value=score_value,          # 1.0 = 👍, 0.0 = 👎, o continuo [0,1]
        data_type="NUMERIC",
        comment=comment,
    )
    lf.flush()
```

### Tracker de señales implícitas

```python
from collections import defaultdict

class ImplicitFeedbackTracker:
    WEIGHTS = {
        "suggestion_applied":    1.0,
        "suggestion_modified":   0.5,
        "suggestion_ignored":   -0.3,
        "suggestion_dismissed": -0.8,
        "review_disputed":      -0.9,
        "quick_merge":           0.7,
    }

    def __init__(self):
        self.scores: dict[str, float] = defaultdict(float)
        self.counts: dict[str, int] = defaultdict(int)

    def track(self, suggestion_id: str, outcome: str):
        weight = self.WEIGHTS.get(outcome, 0.0)
        self.scores[suggestion_id] += weight
        self.counts[suggestion_id] += 1

    def normalized_score(self, suggestion_id: str) -> float:
        n = self.counts[suggestion_id]
        return self.scores[suggestion_id] / n if n else 0.0
```

### Curar dataset de 👎 para re-training

```python
import json
from datetime import timedelta

async def build_training_set(feedback_store, trace_store, window_days: int = 30):
    """Convierte feedback negativo en ejemplos (prompt, respuesta_mala, correccion)."""
    cutoff = datetime.utcnow() - timedelta(days=window_days)
    negatives = await feedback_store.query(
        type_in=("not_helpful", "incorrect"),
        since=cutoff,
        has_reason=True,
    )

    dataset = []
    for fb in negatives:
        trace = await trace_store.get(fb.action_id)
        dataset.append({
            "prompt": trace.input,
            "rejected_output": trace.output,
            "feedback": fb.reason,
            "tags": fb.tags or [],
            "user": fb.user,
        })

    with open("negative_examples.jsonl", "w") as f:
        for row in dataset:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")

    print(f"Dataset curado: {len(dataset)} ejemplos")
    return dataset
```

Este dataset puede alimentar:
- **Prompt engineering**: ejemplos negativos en el system prompt ("evita hacer X como en estos casos").
- **DPO / RLHF**: pares (prompt, chosen, rejected) donde el "chosen" es la corrección humana.
- **Evaluación continua**: suite de regresión que corre antes de cada deploy.

### Detección de patrones

```python
async def detect_patterns(feedback_store, window):
    rejection_by_type = await feedback_store.aggregate(
        group_by="suggestion_type",
        metric="rejection_rate",
        window=window,
    )
    issues = []
    for stype, rate in rejection_by_type.items():
        if rate > 0.7:
            issues.append({"pattern": "high_rejection", "type": stype, "rate": rate})

    accuracy_by_file = await feedback_store.aggregate(
        group_by="file_extension",
        metric="accuracy",
        window=window,
    )
    for ext, acc in accuracy_by_file.items():
        if acc < 0.3:
            issues.append({"pattern": "low_accuracy", "file_ext": ext, "acc": acc})

    return issues
```

## Errores comunes

- **Feedback no accionable sin razón.** Un 👎 sin texto libre no dice *por qué*. El agente no puede mejorar sin la causa. Habilita (y a veces exige) una razón para ratings negativos.
- **Feedback que solo alimenta dashboards.** Se grafica satisfacción semanal, pero nada retroalimenta prompt, modelo o políticas. Se vuelve teatro de métricas. Define el loop completo: colectar → analizar → modificar → medir efecto.
- **Pedir feedback en todo.** Al tercer prompt el usuario se harta y empieza a cerrar sin responder. Pide feedback *strategicamente* (al final de sesiones, en respuestas clave).
- **Sesgo de autoselección.** Solo responden los muy satisfechos o muy enojados. Combina explícito con implícito para tener una señal menos sesgada.
- **Tratar modificaciones como aprobaciones puras.** Si el humano aprueba *con 20 ediciones*, eso es casi un rechazo. Separa "approved as-is" de "approved with edits" en el análisis.
- **Un solo número agregado.** "Satisfacción = 0.78" no te dice dónde actuar. Desagrega por tipo de acción, cohorte de usuario, categoría de respuesta.
- **Ignorar el drift del evaluador.** Si lo que los usuarios consideran "útil" cambia con el tiempo (nuevos stacks, nuevas políticas internas), tu dataset de hace 6 meses deja de ser representativo. Reajusta el ground truth periódicamente.
- **No calibrar la confianza del modelo contra feedback real.** El modelo dice 0.95 pero la precisión histórica es 0.6. Usa el feedback para recalibrar (Platt scaling, isotonic regression).
- **Olvidar privacidad.** Las razones libres pueden contener PII. Anonimiza antes de usarlas en datasets o fine-tuning.
- **No cerrar el loop con el usuario.** El usuario reporta un problema pero nunca ve mejora ni acuse. Pierde incentivo para reportar. Muestra "fixed in v2.3" cuando aplique.

## Resumen

- **Feedback** cierra el ciclo entre comportamiento del agente y expectativa humana; sin él, el agente está congelado.
- Existen múltiples **modalidades**: explícito (thumbs, rating, categorías, texto) vs. implícito (aceptación, modificación, dismissal). Usa ambos: implícito a escala, explícito para calidad.
- Buena UX de feedback es **baja fricción, contextual, específica y transparente** sobre su uso.
- Las **señales implícitas** se ponderan según intensidad; agrégalas por dimensiones (tipo de archivo, categoría de sugerencia) para detectar patrones.
- Herramientas del ecosistema: **Langfuse, LangSmith, Humanloop, Argilla, Label Studio, Prodigy** cubren tracing, annotation y curación.
- **Active learning** prioriza qué anotar: ejemplos de baja confianza, cerca de la frontera o fuera de distribución.
- El feedback alimenta: refinamiento de prompts, ejemplos negativos en el system prompt, datasets para fine-tuning (DPO/RLHF), recalibración de confianza y suites de regresión.
- Errores clave: feedback sin razón, feedback que solo decora dashboards, pedirlo en todo (fatiga), tratar modificaciones como aprobaciones puras.
- La promesa de HITL se cumple solo si **el loop realmente retroalimenta al modelo**, no solo al humano que lo observa.
