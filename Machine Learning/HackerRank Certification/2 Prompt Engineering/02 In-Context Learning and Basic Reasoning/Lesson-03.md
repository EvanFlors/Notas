# Chain-of-Thought, Self-Consistency y Reasoning Models

## ¿Qué es?

**Chain-of-Thought (CoT) prompting** es la técnica de pedirle al modelo que **explicite los pasos intermedios de razonamiento** antes de dar la respuesta final. En vez de obtener directamente `y`, obtienes una secuencia `r₁ → r₂ → ... → rₙ → y`, donde cada `rᵢ` es un paso de pensamiento.

Introducida por **Wei et al. (2022)** en *"Chain-of-Thought Prompting Elicits Reasoning in Large Language Models"*, demostró que simplemente añadir `"Let's think step by step"` (Kojima et al., 2022, **zero-shot CoT**) o un ejemplo con razonamiento explícito dispara mejoras masivas en benchmarks como GSM8K (aritmética), MATH y commonsense reasoning.

### Técnicas de la familia "reasoning in prompt"

| Técnica | Idea | Autor / año |
|---|---|---|
| **CoT (few-shot)** | Ejemplos con razonamiento paso a paso | Wei et al., 2022 |
| **Zero-shot CoT** | Añadir "Let's think step by step" sin ejemplos | Kojima et al., 2022 |
| **Self-Consistency** | Muestrear N cadenas y votar la respuesta | Wang et al., 2022 |
| **Tree-of-Thought (ToT)** | Explorar múltiples ramas de razonamiento con búsqueda | Yao et al., 2023 |
| **ReAct** | Alternar razonamiento y acciones (herramientas) | Yao et al., 2022-23 |
| **Reflexion** | Autocrítica y revisión de la respuesta | Shinn et al., 2023 |
| **Reasoning models** | Modelo con cadenas de pensamiento internas entrenadas | OpenAI o1 (2024), Claude extended thinking (2025) |

## ¿Por qué importa?

Modelos tempranos fallaban en tareas aritméticas simples porque "saltaban" a la respuesta. El ejemplo famoso: *"¿cuántas r hay en strawberry?"* → respuestas "2" o "1". Al forzar al modelo a enumerar letra por letra, acierta. En producción, CoT importa porque:

- **Mejora accuracy** en tareas de razonamiento (matemáticas, lógica, planificación multi-paso).
- **Hace auditable** la decisión: puedes revisar los pasos y detectar errores lógicos.
- **Permite debugging del prompt:** ves exactamente dónde el modelo se equivoca.
- **Habilita herramientas** (ReAct): el modelo decide cuándo llamar a una API, buscar en la web o ejecutar código.
- **Es la base de los reasoning models** modernos (o1, o3, Claude extended thinking, DeepSeek-R1), que internalizan CoT durante entrenamiento con RL.

### CoT vs. respuesta directa

| Dimensión | Respuesta directa | Chain-of-Thought |
|---|---|---|
| Tokens de salida | Pocos | Muchos (razonamiento + respuesta) |
| Latencia | Baja | Alta |
| Costo | Bajo | Más alto |
| Accuracy en razonamiento | Baja | Significativamente mayor |
| Auditabilidad | Nula (caja negra) | Alta |
| Riesgo de alucinación | Alucinación directa | Alucinación "razonada" (puede sonar convincente) |

Regla práctica: usa CoT cuando el costo del error > el costo extra de tokens, o cuando necesitas explicar la decisión a un humano.

## ¿Cómo funciona?

### CoT por tipo

#### 1. Zero-shot CoT

Añadir frases disparadoras: `"Let's think step by step"`, `"Pensemos paso a paso"`, `"Razonemos primero y luego respondamos"`.

#### 2. Few-shot CoT

Ejemplos donde el output incluye razonamiento explícito antes de la respuesta final:

```
Pregunta: Si tengo 3 manzanas y compro el doble, ¿cuantas tengo?
Razonamiento: Inicio con 3. "El doble" significa 2 x 3 = 6 adicionales. Total = 3 + 6 = 9.
Respuesta: 9

Pregunta: {nueva_pregunta}
Razonamiento:
```

#### 3. Self-Consistency (Wang et al., 2022)

En vez de una sola cadena, muestrea `N` cadenas con `temperature > 0` y vota la respuesta más frecuente:

```
       Problema
          │
    ┌─────┼─────┬─────┐
    ▼     ▼     ▼     ▼
  CoT₁  CoT₂  CoT₃  CoT_N     (temperature=0.7, N=5..40)
    │     │     │     │
   y=9   y=9   y=12  y=9
          │
          ▼
   Mayoría → y_final = 9
```

Funciona porque **respuestas correctas convergen** por múltiples caminos, mientras que los errores tienden a ser idiosincráticos.

#### 4. Tree-of-Thought (Yao et al., 2023)

Generaliza CoT a una **búsqueda en árbol**: cada paso tiene varios "pensamientos" candidatos; se evalúan y se expanden los más prometedores (BFS / DFS). Útil en puzzles (Game of 24, crucigramas) donde se requiere backtracking.

#### 5. ReAct (Yao et al., 2022-23)

Alterna **Reasoning** (pensar) y **Acting** (llamar herramientas):

```
Thought: necesito saber la poblacion actual de Mexico.
Action: web_search("poblacion Mexico 2026")
Observation: 131 millones.
Thought: ahora necesito la de Canada...
Action: web_search("poblacion Canada 2026")
Observation: 40 millones.
Thought: puedo responder.
Answer: Mexico tiene ~3.3x la poblacion de Canada.
```

Base conceptual de los **agentes modernos** (LangGraph, OpenAI Agents SDK, Claude agent).

#### 6. Reasoning models (o1, Claude extended thinking, DeepSeek-R1)

Modelos entrenados con RL para producir cadenas de pensamiento **internas** (no visibles al usuario) antes de responder. Facturan **reasoning tokens** aparte. Características:

| Modelo | Reasoning tokens | API control |
|---|---|---|
| OpenAI o1 / o3 | Internos (ocultos) | `reasoning_effort = "low" / "medium" / "high"` |
| Claude extended thinking | Visibles como bloques `thinking` | `thinking: {type: "enabled", budget_tokens: N}` |
| DeepSeek-R1 | Visibles (`<think>...</think>`) | Open weights |

Con reasoning models, **CoT explícito en el prompt a menudo degrada el desempeño**: el modelo ya razona internamente y "guiarlo" interfiere con su proceso. En su lugar, da instrucciones de **alto nivel** y deja que el modelo decida los pasos.

## Ejemplo con código

### Zero-shot CoT

```python
from openai import OpenAI

client = OpenAI(api_key="API_KEY", base_url="BASE_URL")

def responder_cot(pregunta):
    prompt = f"""Pregunta: {pregunta}

Pensemos paso a paso antes de responder. Al final, en una linea aparte,
escribe "Respuesta final: <valor>".
"""
    r = client.chat.completions.create(
        model="gpt-5-mini",
        messages=[{"role": "user", "content": prompt}],
        temperature=0,
    )
    return r.choices[0].message.content

print(responder_cot(
    "Un carrito tiene 3 cajas con 12 manzanas cada una. "
    "Si vendo el 25% de las manzanas, ¿cuantas quedan?"
))
```

### Few-shot CoT para análisis de disputas de facturación

```python
EJEMPLOS_COT = [
    {
        "input": "Cliente dice que le cobraron 50 USD extra por soporte premium.",
        "razonamiento": (
            "1. El cargo disputado es 'soporte premium' = 50 USD.\n"
            "2. Reviso historial: aparece el cargo el 10/03.\n"
            "3. No hay registro de activacion por el cliente.\n"
            "4. Procede reembolso."
        ),
        "respuesta": "REEMBOLSAR 50 USD",
    },
    # ...
]

def analizar_disputa(caso):
    partes = [
        "Analiza disputas de facturacion siguiendo el patron de los ejemplos.\n"
    ]
    for e in EJEMPLOS_COT:
        partes.append(f"Caso: {e['input']}")
        partes.append(f"Razonamiento:\n{e['razonamiento']}")
        partes.append(f"Decision: {e['respuesta']}\n")
    partes.append(f"Caso: {caso}")
    partes.append("Razonamiento:")
    r = client.chat.completions.create(
        model="gpt-5-mini",
        messages=[{"role": "user", "content": "\n".join(partes)}],
        temperature=0,
    )
    return r.choices[0].message.content

print(analizar_disputa("Cliente dice que no reconoce cargo de 30 USD del 22/02."))
```

### Self-Consistency con voto mayoritario

```python
import re
from collections import Counter

def extraer_respuesta(texto):
    m = re.search(r"[Rr]espuesta final[:\s]+(-?\d+(?:\.\d+)?)", texto)
    return m.group(1) if m else None

def self_consistency(pregunta, n=7, temperature=0.7):
    respuestas = []
    for _ in range(n):
        r = client.chat.completions.create(
            model="gpt-5-mini",
            messages=[{"role": "user", "content":
                f"{pregunta}\n\nPensemos paso a paso. Termina con "
                f"'Respuesta final: <valor>'."}],
            temperature=temperature,
        )
        resp = extraer_respuesta(r.choices[0].message.content)
        if resp is not None:
            respuestas.append(resp)
    conteo = Counter(respuestas)
    ganadora, votos = conteo.most_common(1)[0]
    return {
        "respuesta": ganadora,
        "confianza": votos / len(respuestas),
        "distribucion": dict(conteo),
    }

print(self_consistency(
    "Juan tiene 48 canicas. Regala 1/3 a Ana y 1/4 del resto a Luis. "
    "¿Cuantas le quedan?",
    n=7,
))
```

### Reasoning model: OpenAI o-series

```python
r = client.chat.completions.create(
    model="o3-mini",
    reasoning_effort="high",  # "low" | "medium" | "high"
    messages=[{"role": "user", "content":
        "Demuestra que la suma de los primeros n impares es n^2."}],
)
print(r.choices[0].message.content)
print("Tokens de razonamiento:", r.usage.completion_tokens_details.reasoning_tokens)
```

### Claude extended thinking (reasoning visible)

```python
import anthropic

client_a = anthropic.Anthropic(api_key="API_KEY")

r = client_a.messages.create(
    model="claude-sonnet-4-5",
    max_tokens=4096,
    thinking={"type": "enabled", "budget_tokens": 2048},
    messages=[{"role": "user", "content":
        "Un tren sale a 60 km/h desde A, otro a 90 km/h desde B. "
        "Estan a 300 km. ¿En cuanto se cruzan?"}],
)
for bloque in r.content:
    if bloque.type == "thinking":
        print("[THINKING]", bloque.thinking[:400], "...")
    elif bloque.type == "text":
        print("[RESPUESTA]", bloque.text)
```

### ReAct minimal (loop razonar-actuar)

```python
HERRAMIENTAS = {
    "sumar": lambda a, b: a + b,
    "multiplicar": lambda a, b: a * b,
}

def react_loop(pregunta, max_pasos=5):
    historial = [f"Pregunta: {pregunta}"]
    for _ in range(max_pasos):
        prompt = "\n".join(historial) + "\nThought:"
        r = client.chat.completions.create(
            model="gpt-5-mini",
            messages=[{"role": "user", "content": prompt}],
            stop=["Observation:"],
            temperature=0,
        )
        salida = r.choices[0].message.content
        historial.append("Thought:" + salida)
        if "Answer:" in salida:
            return salida.split("Answer:")[-1].strip()
        # (parser simplificado: en real usarias JSON o tool calling nativo)
    return "sin respuesta"
```

En producción, usa el **tool calling nativo** del SDK (OpenAI `tools=`, Anthropic `tools=`) en vez de parsear texto a mano.

## Errores comunes

- **CoT que alucina pasos.** El razonamiento suena lógico pero parte de hechos falsos. Mitigación: validación en checkpoints (recalcular aritmética con una herramienta, verificar hechos con RAG).
- **Pasos contradictorios.** El modelo asume `X=5` en el paso 2 y `X=7` en el paso 4. Pide al modelo que **enumere y rastree** supuestos.
- **Razonamiento verboso que pierde el foco.** Da plantillas con pasos numerados y límites de longitud por paso.
- **Usar CoT en reasoning models.** Añadir "think step by step" a o3 o Claude thinking suele **degradar** el desempeño; el modelo ya razona internamente.
- **Self-consistency con `temperature=0`.** Sin diversidad, las N muestras son idénticas y el voto no aporta nada. Usa `temperature=0.5-0.8`.
- **Costo descontrolado.** CoT y especialmente self-consistency pueden multiplicar costo y latencia 5-10x. Usa solo donde el valor lo justifica.
- **Ignorar los reasoning tokens.** En o-series, pueden ser el 80% del costo del request; monitoréalos y ajusta `reasoning_effort`.
- **Confundir CoT con few-shot.** CoT = pasos de razonamiento; few-shot = ejemplos. Son ortogonales: puedes hacer *few-shot CoT* (ejemplos con razonamiento) o *zero-shot CoT* (sin ejemplos).
- **Exponer el razonamiento al usuario final.** El razonamiento intermedio puede filtrar información sensible, contener errores embarazosos o ser inconsistente con la respuesta. Mostrar solo la respuesta, loggear el razonamiento.
- **No cuantizar la confianza.** En self-consistency, el **grado de consenso** (ej. 7/7 vs 4/7) es una señal valiosa para enrutar casos difíciles a revisión humana.

## Herramientas y ecosistema

| Herramienta | Rol |
|---|---|
| **OpenAI o1/o3/o4** | Reasoning models con `reasoning_effort` |
| **Anthropic Claude extended thinking** | Reasoning con `thinking` visible y `budget_tokens` |
| **DeepSeek-R1 / Qwen QwQ** | Reasoning models open-weights |
| **LangGraph / OpenAI Agents SDK** | Orquestar ReAct y árboles de pensamiento |
| **DSPy `ChainOfThought`, `ProgramOfThought`** | CoT programable y optimizable |
| **Guidance / Outlines** | Forzar formato en salidas CoT |

## Resumen

- **CoT** = pedir al modelo que explicite los pasos antes de responder. Introducido por **Wei et al. (2022)**.
- **Zero-shot CoT** se activa con "pensemos paso a paso" (Kojima et al., 2022); **few-shot CoT** usa ejemplos con razonamiento.
- **Self-Consistency** (Wang et al., 2022): muestrea N cadenas y vota la mayoría; el consenso cuantifica la confianza.
- **Tree-of-Thought** (Yao et al., 2023): búsqueda explícita sobre ramas de razonamiento.
- **ReAct** (Yao et al., 2022-23): alterna razonar y usar herramientas; base de los agentes.
- **Reasoning models** (o1 2024, Claude extended thinking, DeepSeek-R1): razonamiento internalizado durante RL; no requieren CoT explícito y lo pueden deteriorar.
- Riesgos: alucinaciones "razonadas", contradicciones entre pasos, costo multiplicado, exposición de reasoning al usuario.
- Regla: usa CoT cuando necesites **accuracy en razonamiento** o **auditabilidad**; usa reasoning models cuando el presupuesto lo permita y la tarea sea de alta dificultad; usa self-consistency en decisiones críticas donde el consenso vale el 5-10x de costo.
