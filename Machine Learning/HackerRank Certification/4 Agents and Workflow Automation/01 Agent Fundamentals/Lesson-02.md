# El Patrón ReAct

## ¿Qué es?

**ReAct (Reasoning + Acting)** es un patrón de diseño de agentes publicado por Yao et al. en 2022 (*"ReAct: Synergizing Reasoning and Acting in Language Models"*, Princeton + Google Research) en el que el agente **alterna explícitamente entre pensar y actuar**. Antes de cada acción genera un **Thought** (razonamiento en lenguaje natural), ejecuta una **Action** (llamada a tool), y recibe una **Observation** (resultado) que alimenta el siguiente pensamiento.

```
Thought:     "Para revisar el PR, primero necesito el diff."
Action:      get_pr_details(pr_number=1247)
Observation: {"title": "Add password reset", "files": [...], "diff_lines": 139}

Thought:     "Es un cambio sensible a seguridad. Voy a escanear vulnerabilidades."
Action:      analyze_code_security(files=["password_reset.py"])
Observation: {"issue": "token predecible en línea 45"}

Thought:     "Tengo lo necesario para responder."
Action:      respond_to_user("Bloquear merge: token predecible...")
```

> **Idea clave del paper original:** forzar al LLM a *verbalizar su razonamiento* antes de cada acción mejora la calidad de las decisiones y, de paso, hace al agente **auditable**.

### ReAct vs otros patrones de razonamiento

| Patrón | Cómo razona | Cuándo brilla | Debilidad |
|---|---|---|---|
| **ReAct** | Thought → Action → Observation, iterativo | Tareas multi-paso con tools e incertidumbre | Overhead en tareas triviales |
| **Chain-of-Thought (CoT)** | Razona paso a paso **sin** ejecutar tools | Problemas de lógica/matemáticas puros | No puede interactuar con el mundo |
| **Plan-and-Execute** | Genera un **plan completo** y luego lo ejecuta | Flujos con pasos predecibles | Rígido ante observaciones inesperadas |
| **Reflexion** (Shinn 2023) | Al fallar, el agente **reflexiona** y reintenta con la lección aprendida | Recuperación de errores, auto-mejora | Más llamadas, más costo |
| **Tree of Thoughts (ToT)** | Explora varias ramas de razonamiento y elige la mejor | Problemas combinatorios | Costo exponencial |

En producción se **combinan**: `Plan` para la estrategia global, `ReAct` para ejecutar cada paso, `Reflexion` para recuperarse cuando algo falla.

## ¿Por qué importa?

Antes de ReAct, un agente era una caja negra: le dabas un goal, llamaba tools, devolvía algo. Si fallaba, no sabías por qué. ReAct resuelve tres problemas simultáneamente:

1. **Calidad de decisión.** Verbalizar el "por qué" obliga al modelo a construir una justificación antes de actuar, lo que reduce acciones impulsivas y aumenta accuracy en benchmarks como HotpotQA y ALFWorld.
2. **Debuggabilidad.** Si el agente aprueba un PR con un bug, puedes leer la traza y ver exactamente dónde se equivocó: ¿faltaba contexto?, ¿malinterpretó una observación?, ¿eligió la tool equivocada?
3. **Confianza del usuario.** Mostrar el razonamiento ("Bloqueo el merge porque la línea 45 usa `random.randint` para tokens") convierte un veredicto arbitrario en una recomendación evaluable.

**Trade-off:** forzar reasoning explícito en tareas triviales (ej. "¿cuánto es 2+2?") solo añade overhead. Usa ReAct cuando el razonamiento aporta valor real; para tareas simples, prompt directo.

## ¿Cómo funciona?

### Anatomía de un prompt ReAct

```
You are an agent helping with code review. Available tools:
- get_pr_details(pr_number): Returns PR title, files, diff stats.
- analyze_code_security(files): Scans files for vulnerabilities.
- respond_to_user(message): Final answer to the user.

You MUST follow this format:
Thought: [your reasoning about what to do next]
Action: [tool name]
Action Input: [JSON params]
Observation: [provided by system after the action runs]

Continue until you can respond to the user. Then output:
Thought: I have enough information.
Action: respond_to_user
Action Input: {"message": "..."}

User question: {user_question}
Begin!
```

El loop externo **parsea** la salida, extrae la acción, la ejecuta, inyecta la observation y vuelve a llamar al modelo.

### Planning: generar el plan antes de ejecutar

```
Plan:
1. get_pr_details(1247)
2. analyze_code_security(archivos del PR)
3. check_test_coverage(archivos del PR)
4. respond_to_user(resumen + recomendación)
```

Ventaja: menos llamadas al LLM (planeas una vez). Desventaja: si el paso 2 revela algo inesperado, el plan queda obsoleto. Solución híbrida (**Plan-and-ReAct**): generas plan inicial pero re-evalúas después de cada observación.

### Reflection: aprender del fallo dentro del mismo run

```
Thought:     "Voy a buscar vulnerabilidades."
Action:      search_code(query="password")
Observation: "847 resultados, demasiado amplio."
Reflection:  "La búsqueda fue genérica. Debería acotar a archivos del PR."
Thought:     "Repetir con scope limitado a los archivos modificados."
Action:      analyze_code_security(files=["auth.py", "password_reset.py"])
```

Sin reflection, el agente podría quedar atascado repitiendo la búsqueda fallida. Con reflection, cambia de estrategia.

### Decomposition: dividir goals complejos

"Despliega el feature y notifica al equipo" se descompone en:

1. Desplegar.
2. Verificar que el deploy tuvo éxito.
3. Enviar la notificación.

Cada sub-tarea es su propio sub-loop ReAct. Si son independientes, puedes paralelizarlas.

### Modos de falla típicos

| Falla | Síntoma | Mitigación |
|---|---|---|
| **Reasoning error** | El Thought es lógicamente incorrecto | Dar contexto de dominio en el prompt, validar en execution layer |
| **Premature termination** | El agente responde sin investigar suficiente | Lista explícita de checks obligatorios, heurísticas de completitud |
| **Overthinking** | Hace 20 tool calls para un cambio trivial | Iteration cap, instrucción "aim for efficiency" |
| **Reasoning-action misalignment** | El Thought dice X pero la Action hace Y | Schemas JSON estrictos, ejemplos few-shot |
| **Loop sobre el mismo error** | Repite una tool que ya falló | Detección: si `last_3_actions` son iguales → romper |

## Ejemplo con código

### ReAct implementado manualmente (sin frameworks)

```python
import json, re
from anthropic import Anthropic

client = Anthropic()

TOOLS = {
    "get_pr_details": lambda pr_number: {
        "title": "Add password reset",
        "files": ["auth_service.py", "password_reset.py"],
        "diff_lines": 139,
    },
    "analyze_code_security": lambda files: {
        "issues": [{"file": "password_reset.py", "line": 45,
                    "msg": "token generado con random.randint (predecible)"}]
    },
    "check_test_coverage": lambda files: {
        "coverage": {"auth_service.py": 0.87, "password_reset.py": 0.34}
    },
}

SYSTEM = """Eres un agente de code review. Tools disponibles:
- get_pr_details(pr_number: int)
- analyze_code_security(files: list[str])
- check_test_coverage(files: list[str])
- respond_to_user(message: str)

RESPONDE SIEMPRE EN ESTE FORMATO ESTRICTO:

Thought: <razonamiento>
Action: <nombre_tool>
Action Input: <JSON válido con los parámetros>

Cuando tengas suficiente, usa Action: respond_to_user.
"""

ACTION_RE = re.compile(
    r"Thought:\s*(.*?)\nAction:\s*(\w+)\nAction Input:\s*(\{.*?\})",
    re.DOTALL,
)

def parse(text: str):
    m = ACTION_RE.search(text)
    if not m:
        raise ValueError(f"No parseable:\n{text}")
    thought, action, raw_input = m.group(1).strip(), m.group(2), m.group(3)
    return thought, action, json.loads(raw_input)

def react_loop(user_question: str, max_iter: int = 8):
    history = [f"Question: {user_question}"]

    for step in range(max_iter):
        prompt = "\n\n".join(history) + "\n\nThought:"
        resp = client.messages.create(
            model="claude-3-5-sonnet-latest",
            max_tokens=512,
            system=SYSTEM,
            messages=[{"role": "user", "content": prompt}],
        )
        text = "Thought:" + resp.content[0].text

        thought, action, args = parse(text)
        print(f"\n[Paso {step}] {thought}\n → {action}({args})")

        if action == "respond_to_user":
            return args["message"]

        # Detectar loops: misma acción + mismos args repetidos
        signature = f"{action}:{json.dumps(args, sort_keys=True)}"
        if history.count(signature) >= 2:
            return "Loop detectado: abortando."
        history.append(signature)

        try:
            observation = TOOLS[action](**args)
        except Exception as e:
            observation = {"error": str(e)}  # error → de vuelta al modelo

        history.append(text)
        history.append(f"Observation: {json.dumps(observation)}")

    return "Max iterations alcanzadas."


print(react_loop("Revisa el PR #1247 por problemas de seguridad y cobertura."))
```

Puntos clave:

- El **prompt fuerza el formato** `Thought/Action/Action Input`.
- El loop **parsea con regex** y maneja fallos de parseo.
- **Errores de tool se devuelven al modelo** como observation (no se lanzan como excepción).
- **Detección de loop** por firma de acción + args.

### Lo mismo con LangGraph (ReAct prebuilt)

```python
from langgraph.prebuilt import create_react_agent
from langchain_anthropic import ChatAnthropic
from langchain_core.tools import tool

@tool
def get_pr_details(pr_number: int) -> dict:
    """Devuelve título, archivos y stats del PR."""
    return {"title": "Add password reset", "files": ["auth.py", "password_reset.py"]}

@tool
def analyze_code_security(files: list[str]) -> dict:
    """Escanea vulnerabilidades."""
    return {"issues": [{"file": "password_reset.py", "line": 45, "msg": "token predecible"}]}

llm = ChatAnthropic(model="claude-3-5-sonnet-latest", temperature=0)
agent = create_react_agent(llm, tools=[get_pr_details, analyze_code_security])

for event in agent.stream({"messages": [("user", "Revisa el PR #1247")]}):
    print(event)
```

LangGraph te da **streaming de thoughts**, **checkpoints** por iteración y **resumabilidad** sin que escribas el parser.

### Reasoning con restricciones (cost/permission-aware)

```python
BUDGET = {"usd_remaining": 0.50, "calls_remaining": 10}

def guarded_tool_call(name, args, cost):
    if BUDGET["usd_remaining"] < cost:
        return {"error": "budget_exceeded", "suggestion": "usa una tool más barata"}
    if BUDGET["calls_remaining"] <= 0:
        return {"error": "rate_limited"}
    BUDGET["usd_remaining"] -= cost
    BUDGET["calls_remaining"] -= 1
    return TOOLS[name](**args)
```

Devolver el error como observation deja que el modelo **razone sobre la restricción** y busque alternativas, en lugar de crashear.

## Errores comunes

- **Parsing frágil.** El modelo genera "Thought" en vez de "Thought:" y tu regex rompe. Usa structured outputs (JSON mode, tool_use nativo) siempre que esté disponible.
- **Falta de condiciones de parada.** Si el único freno es `max_iterations=50`, cada run gasta 50 llamadas. Añade: detección de loops, criterio explícito de "done", budget de costo.
- **Prompt sin ejemplos.** El modelo infiere el formato de pocos ejemplos; sin few-shot, el formato se degrada en runs largos.
- **Confundir "razonamiento visible" con "razonamiento real".** El Thought es texto generado post-hoc que *racionaliza* la decisión; no es introspección genuina del modelo. Trátalo como explicación, no como garantía.
- **Reflection sin límite.** Si cada fallo dispara otra reflection, el agente puede entrar en un bucle de auto-crítica. Pon `max_reflections=2`.
- **Overthinking en tareas simples.** Para "¿cuánto es 2+2?" un prompt directo cuesta 1 llamada; ReAct cuesta 3. Elige el patrón según la complejidad real.
- **No loguear thoughts.** Si no persistes las trazas, pierdes la ventaja principal del patrón (auditabilidad). Guarda `thought/action/observation` por iteración en un store estructurado.
- **Mezclar reasoning con acción en el mismo bloque.** Si tu prompt no separa claramente *pensar* de *actuar*, el modelo responde texto que es a la vez explicación y resultado, y pierdes el control del flujo.

## Resumen

- **ReAct = Reasoning + Acting**: el agente alterna *Thought → Action → Observation* y verbaliza su razonamiento antes de cada paso (Yao et al., 2022).
- Mejora **calidad de decisión**, **debuggabilidad** y **confianza del usuario** frente a agentes "caja negra".
- Patrones avanzados que lo extienden: **Planning** (plan completo upfront), **Reflection** (aprender del fallo), **Decomposition** (dividir goals), **Tree of Thoughts** (explorar ramas).
- Implementar ReAct exige **prompt estricto con few-shot**, **parsing robusto** (o tool_use nativo) y **condiciones de parada** múltiples.
- Los modos de falla clásicos son **reasoning errors, premature termination, overthinking, misalignment entre thought y action, y loops**: cada uno tiene mitigación específica.
- **Constraint-aware reasoning** (costo, permisos, preferencias de usuario) hace a los agentes viables en producción.
- Evalúa calidad del razonamiento con **process-based evaluation**, **adversarial tests** y **LLM-as-judge sobre las trazas**.
- Las trazas de reasoning son **explicaciones, no garantías**: valídalas contra ground truth; el modelo puede sonar convincente y estar equivocado.
