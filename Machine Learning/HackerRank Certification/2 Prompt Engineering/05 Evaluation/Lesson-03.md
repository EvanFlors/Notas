# Diseño de Judge Prompts Efectivos

## ¿Qué es?

Un **judge prompt** es la instrucción completa que convierte un LLM en un evaluador consistente. No es un prompt cualquiera: su objetivo no es *generar* contenido sino *analizarlo* según criterios explícitos y producir una salida estructurada que un sistema downstream pueda parsear, agregar y auditar.

Un judge prompt bien diseñado tiene seis componentes:

1. **Rol experto definido** ("Eres un evaluador senior de documentación técnica con 10 años de experiencia").
2. **Criterios observables y medibles** (3-5 dimensiones, cada una con rúbrica numérica).
3. **Escala calibrada** (típicamente 1-5 con descripción textual de cada nivel).
4. **Ejemplos de calibración** (anchors de score 5, 3 y 1 con justificación explícita).
5. **Formato de salida estructurado** (JSON con campos obligatorios).
6. **Instrucciones de razonamiento** (chain-of-thought antes del score).

### Judge prompt vs prompt de generación

| Aspecto | Prompt de generación | Judge prompt |
|---|---|---|
| Objetivo | Crear contenido nuevo | Analizar contenido existente |
| Creatividad | Deseable | Prohibida (consistencia) |
| Temperatura | 0.3-1.0 | 0.0 |
| Formato de salida | Flexible | Estricto (JSON) |
| Criterio de éxito | Que guste al usuario | Que coincida con humano experto (κ ≥ 0.6) |
| Debe incluir ejemplos | A veces | Siempre (calibración) |

## ¿Por qué importa?

El prompt es el 90% del juez. Dos equipos pueden usar el mismo GPT-4o como juez y obtener resultados opuestos si uno tiene una rúbrica calibrada con 15 anchors y el otro escribe "evalúa la calidad del 1 al 5". El modelo es el mismo; la diferencia está en el prompt.

Un judge prompt mal diseñado se manifiesta como:

- **Alta varianza** del mismo caso evaluado múltiples veces (debería ser ≤ 0.3 puntos en escala 1-5).
- **Score drift**: la distribución de scores se desplaza semana a semana sin que cambie el sistema evaluado.
- **Correlación baja con humanos** (Cohen's κ < 0.4).
- **Modelos ganadores arbitrarios** en pairwise según el orden presentado (position bias no mitigado).
- **Fallos de parsing** del JSON en producción (>5% de llamadas).

Un prompt bien diseñado convierte un LLM en un instrumento de medición. Un prompt mal diseñado convierte al mismo LLM en un generador de ruido con apariencia de score.

## ¿Cómo funciona?

### Anatomía de un judge prompt completo

```
[ROL]        Eres un X con Y años de experiencia evaluando Z.
[CONTEXTO]   Se te presentará: pregunta, respuesta y referencia (si aplica).
[CRITERIOS]  Evalúa estas N dimensiones, cada una 1-5, según rúbrica abajo.
[RÚBRICA]    Dim1 - nivel 5: ...  nivel 3: ...  nivel 1: ...
             Dim2 - ...
[ANCHORS]    Ejemplo de score 5: ...  (con justificación)
             Ejemplo de score 1: ...  (con justificación)
[REASONING]  Primero describe fortalezas, luego debilidades, luego scores.
[FORMATO]    Devuelve JSON exactamente con este schema: {...}
[REGLAS]     - No inventes información que no esté en el input.
             - Si la respuesta rechaza responder, score=null.
             - Flagea para revisión humana si confidence < 0.6.
```

### Criterios observables, medibles, accionables (OMA)

El error #1 en judge prompts es la rúbrica vaga. Compara:

| Vago (malo) | OMA (bueno) |
|---|---|
| "Evalúa la calidad" | "Evalúa helpfulness: ¿provee pasos accionables que el usuario puede ejecutar sin pedir más información?" |
| "¿Es claro?" | "Evalúa clarity: ¿cada párrafo tiene una idea principal explícita, cada término técnico se define al usarlo, y la estructura va de lo general a lo específico?" |
| "¿Es correcto?" | "Evalúa accuracy: identifica cada afirmación factual y verifica contra el contexto provisto. Marca contradicciones como score ≤ 2." |

### Diseño de escala y anchors

**Escalas pares (1-4, 1-6) vs impares (1-5, 1-7):**

- Las **impares** permiten "punto medio neutro" (3/5). Útil para evaluaciones subjetivas donde "ni bien ni mal" es legítimo.
- Las **pares** fuerzan al juez a decidir. Reducen el sesgo de regresión al centro.

**Recomendación práctica:** 1-5 con anchors en 1, 3 y 5. Más resolución (1-10) parece dar más información pero suele añadir ruido sin señal; Cohen's κ típicamente baja con escalas largas.

Un **anchor** es un ejemplo concreto de qué luce como cada score, con justificación:

```markdown
### Anchor para "Helpfulness" en soporte técnico

**Score 5 — Resolutivo y accionable**
Usuario: "Mi API devuelve 429 intermitentemente."
Respuesta: "El 429 indica rate limit. Verifica tu plan en /account/usage.
Si estás bajo el límite, el problema puede ser bursting: implementa
exponential backoff con jitter. Ejemplo en Python:
```python
import time, random
for attempt in range(5):
    r = client.call()
    if r.status != 429: break
    time.sleep((2**attempt) + random.random())
```
Si persiste, abre un ticket con el request_id del header."
Justificación: diagnóstico correcto, verificación concreta, código ejecutable,
siguiente paso si falla.

**Score 1 — No resuelve**
Usuario: "Mi API devuelve 429 intermitentemente."
Respuesta: "Un 429 es un código de error HTTP. Revisa la documentación."
Justificación: no diagnostica causa, no propone acción, remite a documentación
genérica. El usuario queda igual que antes.
```

### Formato de salida: JSON schema estricto pero parsing tolerante

```json
{
  "scores": {
    "accuracy": {"score": 4, "reasoning": "...", "confidence": 0.9},
    "helpfulness": {"score": 5, "reasoning": "...", "confidence": 0.95},
    "clarity": {"score": 4, "reasoning": "...", "confidence": 0.85}
  },
  "overall": 4.3,
  "classification": "high_quality",
  "flags": ["requires_human_review": false, "contains_pii": false],
  "improvement_suggestions": ["...", "..."],
  "metadata": {
    "judge_model": "claude-sonnet-4-5",
    "prompt_version": "v2.3",
    "evaluated_at": "2026-10-07T14:22:00Z"
  }
}
```

**Regla:** pide formato estricto en el prompt, pero **parsea con tolerancia** (ignora whitespace extra, acepta trailing commas, extrae el primer bloque `{...}` válido). Herramientas como `instructor`, `pydantic`, o el modo `response_format={"type": "json_schema"}` de OpenAI/Anthropic eliminan esta clase de errores.

### Chain-of-thought estructurado

En vez de pedir "razona antes de responder" (vago), estructura el razonamiento:

```
Para cada dimensión:
  a) Lista 2-3 observaciones específicas (cita fragmentos del output).
  b) Clasifica cada observación como positiva, negativa o neutra.
  c) Pondera y asigna score según rúbrica.
Después:
  - Asigna score overall como promedio ponderado.
  - Decide si requiere revisión humana (confidence media < 0.6 o flags activos).
```

Esto produce mejor calibración y, de yapa, trazabilidad para auditoría.

### Calibración: cómo validar el prompt

1. **Golden set de calibración:** 100-300 ejemplos pre-etiquetados por 2+ humanos con consenso.
2. **Correr el juez** sobre ese set.
3. **Calcular**:
   - Cohen's κ entre juez y consenso humano.
   - Matriz de confusión por nivel (¿el juez confunde 3 con 4? ¿con 2?).
   - **F1 por nivel** si tratas cada score como clase:

```
F1 = 2 · (precision · recall) / (precision + recall)
```

4. **Iterar prompt** hasta κ ≥ 0.6 (idealmente 0.75+).
5. **Re-validar** cuando cambies modelo, versión del modelo o estructura del prompt.

### Comparación de frameworks para construir judge prompts

| Framework | Judge prompts prebuilt | Custom rubric | CoT integrado | Multi-judge |
|---|---|---|---|---|
| DeepEval (G-Eval) | Sí (14+) | Sí (steps) | Sí | Parcial |
| Ragas | Sí (RAG) | Limitado | Sí | No |
| Promptfoo (llm-rubric) | Básico | Sí (texto libre) | Si lo escribes | Sí (providers) |
| LangSmith evaluators | Sí | Sí | Sí | Sí |
| Braintrust autoevals | Sí (10+) | Sí | Sí | Sí |
| Rolls-your-own | No | Total | Total | Total |

## Ejemplo con código

### Judge prompt production-ready con Anthropic + Pydantic

```python
from __future__ import annotations
from pydantic import BaseModel, Field, confloat, conint
from anthropic import Anthropic
import json

client = Anthropic()

# ============================================================
# Schema de salida tipado
# ============================================================
class DimScore(BaseModel):
    score: conint(ge=1, le=5)
    reasoning: str = Field(min_length=20, max_length=400)
    confidence: confloat(ge=0.0, le=1.0)

class JudgeResult(BaseModel):
    accuracy: DimScore
    helpfulness: DimScore
    tone: DimScore
    overall: confloat(ge=1.0, le=5.0)
    classification: str  # "excellent" | "good" | "fair" | "poor"
    requires_human_review: bool
    improvement_suggestions: list[str] = Field(max_length=5)

# ============================================================
# Prompt del juez (v2.3)
# ============================================================
JUDGE_PROMPT = """Eres un evaluador senior de respuestas de atención al cliente
con 10 años en SaaS B2B. Evalúas con criterio consistente y defendible.

<customer_query>
{query}
</customer_query>

<ai_response>
{response}
</ai_response>

Evalúa en estas 3 dimensiones (escala 1-5 cada una):

ACCURACY — ¿La información es factualmente correcta y consistente con políticas?
  5: Todo correcto, cita políticas/datos específicos verificables.
  3: Mayoritariamente correcto, 1-2 imprecisiones menores.
  1: Contiene error factual que podría dañar al usuario.

HELPFULNESS — ¿Resuelve o avanza el caso del cliente con pasos accionables?
  5: Resuelve el problema con pasos concretos verificables. Cliente puede ejecutar sin más info.
  3: Encamina en dirección correcta, requiere 1 clarificación menor.
  1: No aborda el problema real o remite genéricamente a documentación.

TONE — ¿Profesional, empático, sin ser condescendiente?
  5: Reconoce emoción del cliente, mantiene calma, voz de marca consistente.
  3: Correcto pero neutro, sin empatía explícita cuando el cliente la necesita.
  1: Defensivo, condescendiente, culpabilizante o robótico.

<calibration_examples>
Query: "Mi factura muestra un cargo que no reconozco."
Respuesta HIGH (5/5/5): "Entiendo tu preocupación. Verifiqué tu cuenta #A-823:
el cargo de $29 corresponde a la renovación anual activada el 3/oct según
tu plan. Si deseas cancelar y recibir prorrateo, puedo iniciarlo ahora."

Respuesta LOW (1/2/1): "Los cargos aparecen según tu plan. Revisa tu contrato."
</calibration_examples>

Proceso de razonamiento:
1. Para cada dimensión, lista 1-2 observaciones específicas citando fragmentos.
2. Asigna score según rúbrica.
3. Calcula overall = media de las 3 dimensiones.
4. Clasifica: ≥4.5 excellent, ≥3.5 good, ≥2.5 fair, <2.5 poor.
5. Marca requires_human_review si: cualquier dim ≤ 2, confidence media < 0.6,
   o detectas política ambigua.

Devuelve EXACTAMENTE este JSON (sin markdown, sin texto antes/después):

{{
  "accuracy":    {{"score": N, "reasoning": "...", "confidence": 0.0-1.0}},
  "helpfulness": {{"score": N, "reasoning": "...", "confidence": 0.0-1.0}},
  "tone":        {{"score": N, "reasoning": "...", "confidence": 0.0-1.0}},
  "overall": N.N,
  "classification": "excellent"|"good"|"fair"|"poor",
  "requires_human_review": true|false,
  "improvement_suggestions": ["...", "..."]
}}
"""

def judge(query: str, response: str) -> JudgeResult:
    msg = client.messages.create(
        model="claude-sonnet-4-5",
        max_tokens=2048,
        temperature=0.0,
        messages=[{"role": "user",
                   "content": JUDGE_PROMPT.format(query=query, response=response)}],
    )
    raw = msg.content[0].text.strip()
    # Parsing tolerante: extraer primer bloque JSON
    start, end = raw.find("{"), raw.rfind("}") + 1
    data = json.loads(raw[start:end])
    return JudgeResult.model_validate(data)

# Uso
result = judge(
    query="Llevo 3 semanas esperando mi reembolso.",
    response="Lamento la demora. Verifiqué tu caso #R-9821: el reembolso de "
             "$149 se procesó el 2/oct y debería reflejarse en 3-5 días hábiles. "
             "Te envié confirmación por correo. ¿Necesitas algo más?",
)
print(result.model_dump_json(indent=2))
```

### Calibración contra humanos

```python
import json
from statistics import mean
from sklearn.metrics import cohen_kappa_score, confusion_matrix, f1_score

# Golden set con etiquetas humanas consensuadas
with open("data/judge_calibration_v1.jsonl") as f:
    gold = [json.loads(line) for line in f]

human_overall = []
judge_overall = []
for item in gold:
    r = judge(item["query"], item["response"])
    judge_overall.append(round(r.overall))
    human_overall.append(item["human_overall"])  # 1-5

kappa = cohen_kappa_score(human_overall, judge_overall, weights="quadratic")
cm = confusion_matrix(human_overall, judge_overall, labels=[1, 2, 3, 4, 5])
f1 = f1_score(human_overall, judge_overall, average="macro")

print(f"Cohen's κ (ponderada): {kappa:.3f}")
print(f"Macro F1: {f1:.3f}")
print(f"Matriz de confusión (filas=humano, cols=juez):\n{cm}")

if kappa < 0.6:
    print("⚠ Juez no suficientemente calibrado. Revisar rúbrica.")
```

**Interpretación:** si la matriz muestra que el juez confunde sistemáticamente 4 con 5 (regresión al centro), ajusta anchors y la descripción del nivel 5 para hacerla más exigente.

### Testing automatizado del prompt del juez

```python
import pytest

# El juez debe ser determinista con temp=0
def test_juez_determinista():
    r1 = judge("Hola", "Hola, ¿en qué puedo ayudarte hoy?")
    r2 = judge("Hola", "Hola, ¿en qué puedo ayudarte hoy?")
    assert r1.overall == r2.overall, "Juez no determinista con temp=0"

# El juez debe penalizar errores factuales explícitos
def test_juez_detecta_error_factual():
    r = judge(
        "¿Cuál es la capital de Francia?",
        "La capital de Francia es Berlín.",
    )
    assert r.accuracy.score <= 2, f"No detectó error factual: {r.accuracy.score}"
    assert r.requires_human_review or r.overall < 3

# El juez debe premiar empatía explícita en quejas
def test_juez_premia_empatia():
    r_frio = judge("Estoy harto, llevo 1 mes esperando.",
                   "Tu caso está en proceso. Espere.")
    r_empatico = judge("Estoy harto, llevo 1 mes esperando.",
                       "Entiendo tu frustración. Verifiqué tu caso y...")
    assert r_empatico.tone.score > r_frio.tone.score
```

### Versionado del prompt como artefacto

Trata el judge prompt como código:

```python
# prompts/judge_customer_service.py
PROMPT_VERSION = "v2.3"
PROMPT_SHA = "a7f3c21"  # hash del contenido

JUDGE_PROMPT = """..."""

# Cada evaluación en producción debe loguear PROMPT_VERSION + modelo + versión del modelo
# para que puedas correlacionar cambios de score con cambios de prompt.
```

## Errores comunes

- **Criterios vagos ("evalúa la calidad").** Produce varianza alta y κ bajo. Reescribe en formato OMA (observable, medible, accionable).
- **Rúbrica sin anchors.** Pedir "1-5 según calidad" sin ejemplos de cada nivel garantiza inconsistencia. Mínimo anchors en 1, 3 y 5.
- **Demasiadas dimensiones.** 7+ dimensiones degradan correlación con humano. Mantén 3-5 bien definidas.
- **Formato JSON sin schema estricto.** Causa 5-15% de fallos de parsing en producción. Usa `response_format` del proveedor o Pydantic + parsing tolerante.
- **Temperatura > 0.** Introduce ruido sin razón. `temperature=0` siempre.
- **Mismo modelo como generador y como juez.** Infla scores por preferencia estilística. Usa familia distinta (Claude juzga a GPT, o viceversa).
- **No versionar el prompt.** Comparar métricas de hoy con las de hace 2 meses sin saber qué prompt del juez corrió es inútil. Logs deben incluir `prompt_version` + `judge_model` + `judge_model_version`.
- **No re-calibrar al actualizar modelo.** `gpt-4o` del 1 de agosto y del 1 de octubre son modelos distintos. Re-corre calibración después de cualquier upgrade.
- **Pedir el score antes del razonamiento.** El modelo "ancla" en el score y racionaliza después. Pide razonamiento primero, score al final.
- **Ignorar confidence baja.** Si tu juez marca confidence < 0.6, no promedies ciegamente: encola para revisión humana.
- **Rúbricas copiadas sin dominio.** La rúbrica de MT-Bench no es tu rúbrica. Lo que es "helpful" en tu negocio depende de tus usuarios y políticas. Siempre adapta.

## Resumen

- Un judge prompt es un **instrumento de medición**: debe ser consistente, defendible, trazable y versionado.
- Seis componentes: **rol, criterios OMA, escala calibrada, anchors, formato estructurado, chain-of-thought**.
- **3-5 dimensiones** máximas; cada una con rúbrica textual por nivel y al menos 3 anchors (score 1, 3, 5).
- Escala 1-5 impar permite neutro; escala par fuerza decisión. Más de 5 niveles raramente mejora señal.
- Formato JSON estricto en el prompt + parsing tolerante en el código = cero fallos de parsing con máxima estructura.
- **Chain-of-thought estructurado** (observaciones → ponderación → score) mejora calibración 10-15 puntos.
- Valida contra humanos con **Cohen's κ ponderado**. Objetivo: κ ≥ 0.6; ideal κ ≥ 0.75.
- **Versiona el prompt** como código (SHA, changelog) y loguéalo con cada evaluación.
- Re-calibra ante cualquier cambio: versión del modelo juez, cambio de rúbrica, nuevo dominio.
- Trata el judge prompt como un contrato: ambiguo → humanos no se ponen de acuerdo → modelo tampoco.
