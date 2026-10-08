# Multi-Judge Systems y Evaluación Híbrida Humano-IA

## ¿Qué es?

Un **multi-judge system** es una arquitectura de evaluación que combina **varios jueces independientes** (modelos distintos, prompts distintos o ambos) y agrega sus veredictos con un mecanismo de consenso. La **evaluación híbrida humano-IA** integra, además, revisión humana enfocada en los casos donde los jueces discrepan o la confianza es baja.

En vez de confiar en un único juez (que tiene blind spots sistemáticos), se construye un *jurado* que:

- Reduce el error individual mediante **ensamble**.
- Hace explícito el desacuerdo (señal de caso difícil).
- Rutea casos ambiguos a humanos.
- Permite jueces **especializados** (safety, factualidad, estilo) con pesos distintos.

### Analogía

Es la diferencia entre pedirle a un revisor que apruebe un paper vs. convocar un panel con un metodólogo, un estadístico y un experto de dominio. Cada uno ve cosas distintas; su desacuerdo revela los puntos débiles.

### Patrones principales

| Patrón | Descripción | Cuándo usarlo |
|---|---|---|
| **Ensemble homogéneo** | Mismo modelo con prompts distintos | Reducir varianza de un prompt |
| **Ensemble heterogéneo** | Modelos distintos (GPT + Claude + Gemini) | Reducir sesgo correlacionado |
| **Jueces especializados** | Un juez por dimensión (safety, factualidad, tono) | Dominios con criterios muy distintos |
| **Jerárquico (cascada)** | Juez barato screena, caro escala sólo casos difíciles | Volúmenes grandes con presupuesto limitado |
| **Humano-in-the-loop** | Humanos revisan casos de bajo acuerdo o alta criticidad | Decisiones de alto stake (safety, legal, médico) |

## ¿Por qué importa?

Un juez único en producción es un punto único de fallo. Si GPT-4o tiene un blind spot con sarcasmo, **todo tu sistema de evaluación es ciego al sarcasmo**. No hay forma de detectarlo con un solo juez porque no tienes contra qué comparar.

Multi-judge resuelve tres problemas estructurales:

1. **Sesgos sistemáticos:** cada familia de modelos (OpenAI, Anthropic, Google, Meta) tiene preferencias estilísticas distintas. Ensamblar neutraliza.
2. **Varianza aleatoria:** un modelo con temperatura > 0 (o incluso 0, por implementaciones no deterministas) da scores ligeramente distintos. Promediar reduce ruido.
3. **Casos genuinamente difíciles:** si tres jueces diversos coinciden, estás ante un caso "fácil". Si discrepan fuerte, estás ante un caso que merece ojo humano.

### Resultado típico en producción

Un cambio de juez único → multi-judge heterogéneo (3 modelos) + ruteo humano suele:

- Reducir **falsos positivos** de safety 30-50%.
- Subir correlación con panel humano de κ ≈ 0.55 a κ ≈ 0.80.
- Costar 2-3× más por caso en promedio.
- Reducir cases que requieren revisión humana completa a 5-15% (vs. 100%).

## ¿Cómo funciona?

### Mecanismos de consenso

| Mecanismo | Cuándo usar | Fortaleza | Debilidad |
|---|---|---|---|
| **Majority voting** | Decisiones categóricas (pass/fail, A/B) | Simple, robusto | Pierde información cuando hay matiz |
| **Mean / median de scores** | Scores continuos (1-5) | Reduce ruido | Promedia señales legítimas (safety flags) |
| **Weighted average** | Jueces con confiabilidad conocida | Explota calibración histórica | Requiere trackear performance por juez |
| **Confidence-weighted** | Jueces reportan su confianza | Da más peso a juicios firmes | Depende de calibración de confianza |
| **Veto por dimensión** | Un juez especializado puede vetar | Protege contra blind spots | Puede ser demasiado estricto |
| **Elo rating** (pairwise) | Comparación entre modelos a gran escala | Produce ranking continuo | Requiere miles de comparaciones |

### Fórmula de agregación ponderada

Con jueces `j = 1..N`, scores `s_j` y pesos `w_j`:

```
score_consenso = Σ (w_j · s_j · c_j) / Σ (w_j · c_j)
```

Donde `c_j` es la confidence que reporta el juez `j`. Los pesos `w_j` se derivan de calibración histórica (ej. qué juez tiene mejor Cohen's κ contra humanos en esta tarea).

### Detección de desacuerdo

Varianza entre jueces como señal operacional:

```python
import statistics

def disagreement_score(scores: list[float]) -> float:
    """Desviación estándar normalizada en escala 1-5 → [0, 1]."""
    sd = statistics.stdev(scores) if len(scores) > 1 else 0
    return min(sd / 2.0, 1.0)  # 2.0 es sd máxima posible en 1-5

def routing_decision(scores: list[float], threshold: float = 0.4) -> str:
    d = disagreement_score(scores)
    if d < 0.15: return "auto_accept"       # jueces alineados
    if d < threshold: return "auto_with_log" # desacuerdo moderado
    return "human_review"                    # discrepancia fuerte
```

Casos con desacuerdo alto son los más valiosos para enviar a humano: enseñan al sistema y revelan ambigüedad en la rúbrica.

### Comparación: single-judge vs multi-judge vs híbrido

| Dimensión | Single judge | Multi-judge homogéneo | Multi-judge heterogéneo | Hybrid humano-IA |
|---|---|---|---|---|
| Costo relativo por caso | 1× | 2-3× | 3-5× | 5-20× (según % humano) |
| Latencia | ~2s | ~2s (paralelo) | ~5s (modelo más lento) | minutos-horas |
| Reduce ruido | No | Sí | Sí | Sí |
| Reduce sesgo | No | No | Sí | Sí |
| Correlación con humanos | 0.55-0.75 | 0.65-0.80 | 0.75-0.90 | ~1.0 (en muestra humana) |
| Escalable a 1M evals/día | Sí | Sí | Caro | Imposible 100% |

### Jerarquía (cascada) para controlar costo

```
                 ┌──────────────────┐
Input ──────────▶│ Juez rápido/barato│  (ej. GPT-4o-mini)
                 │  score + conf     │
                 └────────┬──────────┘
                          │
            ┌─────────────┴─────────────┐
            │                           │
     conf ≥ 0.85                 conf < 0.85
     score claro                 o score ambiguo
            │                           │
            ▼                           ▼
     [Auto-accept]           ┌───────────────────┐
                             │ Panel multi-judge │  (GPT-4o + Claude + Gemini)
                             │ especializado     │
                             └────────┬──────────┘
                                      │
                       ┌──────────────┴──────────────┐
                 agreement > 0.8              agreement < 0.5
                       │                             │
                       ▼                             ▼
                [Auto con log]              [Revisión humana]
```

En producción típica: 70-80% de casos se resuelven en el juez rápido, 15-25% en el panel, 2-10% llegan a humano. Costo total ~0.3× el de usar panel para todo.

### Cohen's kappa para calibrar un juez contra el panel

Para integrar un nuevo juez al ensemble, mídelo contra el consenso del panel sobre 300+ casos:

```
κ = (p_o − p_e) / (1 − p_e)
```

Si κ ≥ 0.7 contra el panel actual, incorpora al ensemble. Si κ < 0.5, el juez está mal calibrado o pertenece a una familia con blind spots irreconciliables.

### Human-in-the-loop: dónde invertir las horas

Los humanos son el recurso más caro y más valioso. Reglas de ruteo típicas:

1. **Alto stake:** safety, legal, médico, financiero → siempre humano en loop.
2. **Alto desacuerdo:** jueces con sd ≥ 0.5 sobre escala 1-5.
3. **Baja confianza agregada:** `mean(confidence) < 0.6`.
4. **Edge cases nuevos:** inputs que no se parecen a nada en el golden set (detectar con distancia de embeddings).
5. **Active learning:** 1-5% aleatorio para calibración continua.
6. **Feedback de usuarios negativos:** si un usuario reporta un output malo, aunque los jueces lo aprobaran, revisión humana.

Los humanos **no** deberían revisar outputs que todos los jueces aprueban con alta confianza; eso es desperdicio.

## Ejemplo con código

### Panel heterogéneo con mitigación de position bias

```python
import asyncio
import statistics
from dataclasses import dataclass
from anthropic import Anthropic
from openai import OpenAI

anthropic = Anthropic()
openai = OpenAI()

JUDGE_PROMPT = """Evalúa esta respuesta de soporte al cliente.
<query>{query}</query>
<response>{response}</response>

Devuelve JSON: {{"accuracy":1-5, "helpfulness":1-5, "tone":1-5, "confidence":0-1}}
"""

@dataclass
class JudgeVerdict:
    judge_id: str
    accuracy: int
    helpfulness: int
    tone: int
    confidence: float

async def claude_judge(query, response) -> JudgeVerdict:
    msg = await asyncio.to_thread(
        anthropic.messages.create,
        model="claude-sonnet-4-5", max_tokens=512, temperature=0.0,
        messages=[{"role": "user", "content": JUDGE_PROMPT.format(query=query, response=response)}],
    )
    import json; d = json.loads(_extract_json(msg.content[0].text))
    return JudgeVerdict("claude", d["accuracy"], d["helpfulness"], d["tone"], d["confidence"])

async def gpt_judge(query, response) -> JudgeVerdict:
    msg = await asyncio.to_thread(
        openai.chat.completions.create,
        model="gpt-4o", temperature=0.0,
        messages=[{"role": "user", "content": JUDGE_PROMPT.format(query=query, response=response)}],
        response_format={"type": "json_object"},
    )
    import json; d = json.loads(msg.choices[0].message.content)
    return JudgeVerdict("gpt", d["accuracy"], d["helpfulness"], d["tone"], d["confidence"])

async def gemini_judge(query, response) -> JudgeVerdict:
    # ... similar, usando google-generativeai
    ...

def _extract_json(text: str) -> str:
    return text[text.find("{"): text.rfind("}") + 1]


async def panel_evaluate(query: str, response: str) -> dict:
    verdicts = await asyncio.gather(
        claude_judge(query, response),
        gpt_judge(query, response),
        gemini_judge(query, response),
    )

    # Pesos derivados de calibración histórica contra humanos
    weights = {"claude": 1.0, "gpt": 1.0, "gemini": 0.9}

    def weighted(dim: str) -> float:
        num = sum(getattr(v, dim) * weights[v.judge_id] * v.confidence for v in verdicts)
        den = sum(weights[v.judge_id] * v.confidence for v in verdicts)
        return num / den

    consensus = {d: weighted(d) for d in ("accuracy", "helpfulness", "tone")}

    # Desacuerdo por dimensión
    disagreement = {
        d: statistics.stdev([getattr(v, d) for v in verdicts]) / 2.0
        for d in ("accuracy", "helpfulness", "tone")
    }

    needs_human = (
        max(disagreement.values()) > 0.3
        or statistics.mean(v.confidence for v in verdicts) < 0.6
        or min(consensus.values()) < 2.5
    )

    return {
        "individual": [v.__dict__ for v in verdicts],
        "consensus": consensus,
        "disagreement": disagreement,
        "overall": statistics.mean(consensus.values()),
        "requires_human_review": needs_human,
    }
```

### Jueces especializados con veto de safety

```python
async def specialized_panel(query: str, response: str) -> dict:
    """Safety tiene poder de veto; otras dimensiones se promedian."""
    safety, accuracy, style = await asyncio.gather(
        safety_judge.evaluate(query, response),      # modelo fine-tuned en seguridad
        accuracy_judge.evaluate(query, response),    # modelo con buena factualidad
        style_judge.evaluate(query, response),       # evalúa tono y claridad
    )

    # Veto de safety
    if safety.score <= 2:
        return {
            "verdict": "REJECT",
            "reason": f"Safety veto: {safety.reasoning}",
            "requires_human_review": True,
            "scores": {"safety": safety.score, "accuracy": accuracy.score, "style": style.score},
        }

    overall = statistics.mean([accuracy.score, style.score])
    return {
        "verdict": "ACCEPT" if overall >= 3.5 else "REVIEW",
        "scores": {"safety": safety.score, "accuracy": accuracy.score, "style": style.score},
        "overall": overall,
        "requires_human_review": overall < 3.5,
    }
```

### Cascada jerárquica para controlar costo

```python
async def cascaded_eval(query: str, response: str) -> dict:
    # Nivel 1: juez barato
    quick = await gpt_mini_judge(query, response)
    if quick.confidence >= 0.85 and quick.overall >= 4.0:
        return {"path": "quick_accept", "cost_usd": 0.001, **quick.__dict__}
    if quick.confidence >= 0.85 and quick.overall <= 2.0:
        return {"path": "quick_reject", "cost_usd": 0.001, **quick.__dict__}

    # Nivel 2: panel heterogéneo
    panel = await panel_evaluate(query, response)
    if not panel["requires_human_review"]:
        return {"path": "panel_resolved", "cost_usd": 0.015, **panel}

    # Nivel 3: encolar para revisión humana
    human_queue.enqueue(query=query, response=response, panel_result=panel)
    return {"path": "escalated_to_human", "cost_usd": 0.015, **panel}
```

### A/B testing con usuarios reales (evaluación online)

Las evaluaciones offline (golden sets, judges) son necesarias pero no suficientes. La prueba final es el comportamiento con usuarios reales:

```python
# Pseudocódigo de A/B con GrowthBook / LaunchDarkly / propio
def serve_response(user_id: str, query: str) -> str:
    variant = experiment.get_variant(user_id, "prompt_v3_vs_v4")

    if variant == "v3":
        response = model.generate(PROMPT_V3.format(query=query))
    else:
        response = model.generate(PROMPT_V4.format(query=query))

    log_event("ai_response", user_id=user_id, variant=variant,
              query=query, response=response, timestamp=now())
    return response

# Métricas online que importan (no son juez LLM):
# - CSAT / thumbs up/down
# - task_completion_rate (¿el usuario resolvió su problema?)
# - handoff_to_human_rate (¿el chatbot escaló?)
# - time_to_resolution
# - retention_7d (¿volvió el usuario?)
```

Las métricas offline predicen; las online deciden. Una mejora de +0.3 en LLM-judge que **no mueve** CSAT es una mejora cosmética. Una métrica offline que correlaciona 0.9 con CSAT a lo largo de 20 experimentos es tu "north-star eval".

### Offline vs online: comparación

| Dimensión | Offline (golden set + judges) | Online (A/B con usuarios) |
|---|---|---|
| Velocidad de iteración | Minutos | Días-semanas (power estadístico) |
| Costo | Bajo (compute) | Alto (riesgo de servir variante mala) |
| Realismo | Depende del golden set | 100% real |
| Reproducible | Sí | No |
| Detecta regresiones antes de prod | Sí | No (ya está en prod) |
| Decisión final | No | Sí |

Flujo recomendado: **todo cambio pasa offline primero** (CI con golden set + judges), **los que pasan corren A/B con 1-5% del tráfico**, **sólo los que ganan en online se promueven al 100%**.

## Errores comunes

- **Correlación sin diversidad.** Tres instancias del mismo modelo con el mismo prompt no son un ensemble: comparten blind spots. Varía modelo *o* prompt *o* ambos.
- **Promediar señales de safety.** Si un juez especializado en safety flaguea y el promedio diluye la señal, puedes servir contenido dañino. Da poder de veto a los jueces especializados.
- **Costo descontrolado.** Panel de 3 modelos frontier sobre 1M casos/día = cuentas de miles de dólares. Usa cascada: juez barato primero, panel sólo cuando sea necesario.
- **No cerrar el loop con humanos.** Revisión humana sin feedback al sistema desperdicia la señal más valiosa. Cada override humano debe loguearse y disparar: (a) análisis de por qué los jueces fallaron, (b) actualización de prompts o anchors, (c) adición al golden set.
- **Confundir desacuerdo con error.** Alto desacuerdo entre jueces diversos a menudo refleja un caso genuinamente ambiguo, no un fallo técnico. Esos son los casos de oro para revisar y afinar la rúbrica.
- **Position bias en pairwise multi-judge.** Si tus jueces siempre reciben A antes que B, ensamblar sólo amplifica el sesgo. Rota orden o evalúa en ambos y marca ties.
- **Desplegar sin A/B online.** Métricas offline mejoradas pero producto que empeora es un patrón clásico. Siempre valida con usuarios antes de rollout al 100%.
- **A/B tests sin power estadístico.** 100 usuarios por variante no detectan cambios reales en CSAT. Calcula tamaño muestral antes de correr. Reglas de parada tempranas sin corrección inflan falsos positivos.
- **Jueces especializados sin dominio real.** Un "safety judge" que es sólo GPT-4o con un prompt de safety no es especializado; es GPT-4o. Especialización real implica fine-tuning o modelos distintos de los que hiciste el panel generalista.
- **No versionar la configuración del panel.** El consenso de hoy no es el consenso de hace 3 meses si cambiaron modelos o pesos. Loguea versión del panel con cada evaluación.

## Resumen

- **Multi-judge** reduce varianza (ensemble) y sesgo (jueces heterogéneos); **híbrido humano-IA** añade juicio experto en los casos que realmente lo necesitan.
- Diversidad real = modelos distintos **y/o** prompts distintos **y/o** especialización por dimensión. Tres GPT-4o idénticos no son un ensemble.
- Mecanismos de consenso: **majority voting, weighted average, confidence-weighted, veto por dimensión, Elo**. Elige según tipo de decisión.
- **Desacuerdo entre jueces es señal, no ruido**: usa varianza para rutear a humano.
- **Arquitectura jerárquica (cascada)** controla el costo: juez barato para el 70-80% de casos, panel caro para el 15-25%, humano para el 2-10%.
- Da **poder de veto** a jueces especializados (safety, legal, medical) para evitar que el promedio diluya alertas críticas.
- Mide cada juez contra el panel con **Cohen's κ**; incorpora sólo los que suman (κ ≥ 0.7).
- **Offline (golden + judges) para iterar rápido**; **online (A/B con usuarios reales) para decidir**. Las métricas online son las que mandan.
- Cierra el loop: cada override humano actualiza prompts, anchors, golden set y pesos del panel. Sin feedback loop, el sistema no mejora.
- Versiona la configuración del panel (modelos, versiones, pesos, prompts) y logéala con cada evaluación.
