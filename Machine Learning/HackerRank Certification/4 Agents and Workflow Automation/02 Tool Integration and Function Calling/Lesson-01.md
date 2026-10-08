# Function Calling: El puente del pensamiento a la acción

## ¿Qué es?

**Function calling** (o **tool use** en terminología de Anthropic) es el mecanismo que transforma un modelo de lenguaje de un **generador de texto** en un **tomador de acciones**. En vez de solo producir prosa, el modelo emite **solicitudes estructuradas** (típicamente JSON) para ejecutar funciones específicas con parámetros tipados, que tu código ejecuta contra sistemas reales.

La idea clave es la **separación entre intención y ejecución**:

- El **modelo** decide qué función llamar y con qué parámetros (razonamiento).
- Tu **código** ejecuta la función y devuelve el resultado (acción).

Un LLM tradicional, ante la pregunta *"Revisa el PR #1247 por problemas de seguridad"*, produce texto describiendo lo que haría. Un LLM con function calling emite:

```json
{"name": "analyze_code_security", "arguments": {"pr_number": 1247, "focus": ["injection", "auth"]}}
```

Ese JSON es inequívoco, parseable y directamente ejecutable.

### Breve historia

| Fecha | Hito |
|---|---|
| Marzo 2023 | OpenAI lanza *plugins* para ChatGPT (precursor de tool use) |
| Junio 2023 | OpenAI introduce **function calling** en `gpt-3.5-turbo-0613` y `gpt-4-0613` |
| Nov 2023 | OpenAI renombra el parámetro `functions` a `tools` y añade **parallel tool calls** |
| Mayo 2024 | Anthropic lanza **tool use** en GA para Claude 3 (Haiku, Sonnet, Opus) |
| 2024 | Google habilita **function calling** en Gemini; Mistral, Llama 3.1 y Qwen suman soporte |
| 2024-2025 | **MCP (Model Context Protocol)** de Anthropic estandariza la exposición de herramientas |

### No es una sola feature: es un protocolo

Function calling no es un botón mágico. Es un **protocolo de tres pasos** entre tu aplicación y el LLM:

1. Tú **describes** las herramientas disponibles (nombre, descripción, schema de parámetros).
2. El modelo **selecciona y parametriza** una (o varias) herramientas.
3. Tú **ejecutas** la herramienta y le devuelves el resultado al modelo.

## ¿Por qué importa?

Antes de function calling nativo, construir un agente requería hacks frágiles:

- **Prompt-based parsing:** le pedías al modelo *"responde en JSON con este formato"* y rezabas. El modelo añadía backticks, prosa, comas sobrantes.
- **ReAct text parsing:** parseabas líneas tipo `Action: get_pr_diff(1247)` con regex. Un espacio extra y todo fallaba.
- **Few-shot con parsing manual:** cadenas de ejemplos para enseñar el formato, consumiendo tokens.

Function calling nativo resuelve esto porque el modelo está **entrenado** (fine-tuned) para emitir llamadas que validan contra tu schema. Ventajas:

| Dimensión | Prompt parsing | Function calling nativo |
|---|---|---|
| Fiabilidad del formato | ~85-95% | ~99%+ |
| Validación automática | Manual con try/except | API valida tipos y requeridos |
| Múltiples llamadas en paralelo | Muy difícil | Soportado nativamente |
| Separación prompt / herramientas | Mezcladas | Parámetros distintos |
| Reproducibilidad | Baja | Alta |

### Cuándo usar function calling

- **Acciones estructuradas:** interactuar con APIs, bases de datos, sistemas de archivos.
- **Salidas precisas:** necesitas un entero `1247`, no `"PR #1247"`.
- **Auditabilidad:** logs limpios de qué quiso hacer el modelo, útil para compliance.
- **Agentes multi-paso:** cada paso es una tool call registrada.

### Cuándo saltárselo

- **Conversación pura:** explicar, resumir, charlar. Añadir tools solo gasta tokens.
- **Transformaciones simples de texto:** extraer puntos clave de un párrafo no requiere tool.
- **Un solo call determinista:** si la respuesta siempre es la misma función, llámala tú directamente sin preguntarle al modelo.

## ¿Cómo funciona?

El workflow tiene cuatro fases bien delimitadas:

```
┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐
│  DEFINICIÓN │ → │  SELECCIÓN  │ → │  EJECUCIÓN  │ → │  RESPUESTA  │
│  (schemas)  │   │   (modelo)  │   │  (tu código)│   │ (modelo usa)│
└─────────────┘   └─────────────┘   └─────────────┘   └─────────────┘
       ↑                                                       │
       └───────────────── loop hasta terminar ─────────────────┘
```

![Workflow de function calling](https://hrcdn.net/ai-engineering/module-4/light/tool-integration-lesson01-workflow.svg)

### 1. Definición

Describes cada herramienta con **JSON Schema**. Mínimo necesitas:

- `name`: identificador snake_case único.
- `description`: qué hace, cuándo usarla, qué devuelve.
- `parameters`: tipos y requeridos siguiendo JSON Schema Draft-7.

### 2. Selección

El modelo lee el prompt del usuario y las descripciones de las tools, y decide. Puede:

- Llamar **una** herramienta.
- Llamar **varias en paralelo** (si el provider lo soporta).
- **No llamar ninguna** y responder directamente con texto.

### 3. Ejecución

Es tu responsabilidad. Tú:

1. Parseas los argumentos JSON.
2. Validas (ya sea con JSON Schema, Pydantic, o manual).
3. Ejecutas la función real (API call, DB query, etc.).
4. Capturas el resultado o el error.

### 4. Integración de respuesta

Devuelves el resultado al modelo con un rol especial (`tool` en OpenAI, bloque `tool_result` en Anthropic). El modelo lo lee y continúa razonando: puede llamar otra tool, o producir la respuesta final.

### Function calling vs enfoques tradicionales

![Comparación de enfoques](https://hrcdn.net/ai-engineering/module-4/light/tool-integration-lesson01-comparison.svg)

### Function calling en OpenAI, Anthropic y Gemini

Los tres grandes convergen en la idea pero difieren en sintaxis:

| Dimensión | OpenAI | Anthropic | Google Gemini |
|---|---|---|---|
| Parámetro | `tools=[{"type": "function", ...}]` | `tools=[{"name", "description", "input_schema"}]` | `tools=[{"function_declarations": [...]}]` |
| Schema de params | `parameters` (JSON Schema) | `input_schema` (JSON Schema) | `parameters` (OpenAPI subset) |
| Respuesta del modelo | `message.tool_calls[]` | `content` con bloques `tool_use` | `candidates[0].content.parts` con `function_call` |
| ID de llamada | `tool_call.id` | `tool_use.id` | implícito por orden |
| Resultado de vuelta | `role: "tool"` con `tool_call_id` | bloque `tool_result` con `tool_use_id` | `role: "function"` con `function_response` |
| Parallel calls | Sí (default) | Sí (configurable) | Sí |
| Forzar herramienta | `tool_choice={"type": "function", "function": {"name": ...}}` | `tool_choice={"type": "tool", "name": ...}` | `tool_config={"function_calling_config": {"mode": "ANY"}}` |
| Stop condition | `finish_reason: "tool_calls"` | `stop_reason: "tool_use"` | `finishReason: "STOP"` |

## Ejemplo con código

### OpenAI SDK

```python
import json
from openai import OpenAI

client = OpenAI()

# 1. Definir herramientas
tools = [
    {
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": (
                "Obtiene el clima actual para una ciudad. Devuelve "
                "temperatura en Celsius y condición (soleado, lluvia, etc.). "
                "Úsala cuando el usuario pregunte por clima o temperatura."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "city": {
                        "type": "string",
                        "description": "Nombre de la ciudad, ej. 'Buenos Aires'",
                    },
                    "units": {
                        "type": "string",
                        "enum": ["celsius", "fahrenheit"],
                        "description": "Unidades de temperatura. Default: celsius",
                    },
                },
                "required": ["city"],
            },
        },
    }
]

# 2. Primera llamada: el modelo decide
messages = [{"role": "user", "content": "¿Qué temperatura hace en CDMX?"}]
resp = client.chat.completions.create(
    model="gpt-4o",
    messages=messages,
    tools=tools,
)

msg = resp.choices[0].message
messages.append(msg)  # el assistant con tool_calls

# 3. Ejecutar las llamadas
def get_weather(city: str, units: str = "celsius") -> dict:
    # En producción: llamar a OpenWeather, etc.
    return {"city": city, "temp": 22, "units": units, "condition": "soleado"}

for call in msg.tool_calls:
    args = json.loads(call.function.arguments)
    result = get_weather(**args)
    messages.append(
        {
            "role": "tool",
            "tool_call_id": call.id,
            "content": json.dumps(result),
        }
    )

# 4. Segunda llamada: el modelo integra el resultado
final = client.chat.completions.create(model="gpt-4o", messages=messages, tools=tools)
print(final.choices[0].message.content)
```

### Anthropic SDK (tool use)

```python
import anthropic

client = anthropic.Anthropic()

tools = [
    {
        "name": "get_weather",
        "description": (
            "Obtiene el clima actual para una ciudad. Devuelve temperatura "
            "en Celsius y condición. Úsala cuando el usuario pregunte por clima."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "city": {"type": "string", "description": "Nombre de la ciudad"},
                "units": {
                    "type": "string",
                    "enum": ["celsius", "fahrenheit"],
                    "description": "Unidades. Default: celsius",
                },
            },
            "required": ["city"],
        },
    }
]

messages = [{"role": "user", "content": "¿Qué temperatura hace en CDMX?"}]

resp = client.messages.create(
    model="claude-sonnet-4-5",
    max_tokens=1024,
    tools=tools,
    messages=messages,
)

# resp.stop_reason == "tool_use"
# resp.content es una lista de bloques: text, tool_use, ...
tool_results = []
for block in resp.content:
    if block.type == "tool_use":
        args = block.input
        result = get_weather(**args)  # misma función
        tool_results.append(
            {
                "type": "tool_result",
                "tool_use_id": block.id,
                "content": json.dumps(result),
            }
        )

messages.append({"role": "assistant", "content": resp.content})
messages.append({"role": "user", "content": tool_results})

final = client.messages.create(
    model="claude-sonnet-4-5",
    max_tokens=1024,
    tools=tools,
    messages=messages,
)
print(final.content[0].text)
```

### Parallel tool calls

Cuando el usuario pregunta *"compara el clima de CDMX y Buenos Aires"*, un buen modelo emite **dos** tool calls en la misma respuesta. Ejecútalas concurrentemente:

```python
import asyncio

async def exec_call(call):
    args = json.loads(call.function.arguments)
    # cada tool puede ser I/O-bound (HTTP)
    return call.id, await get_weather_async(**args)

async def run_parallel(tool_calls):
    results = await asyncio.gather(*(exec_call(c) for c in tool_calls))
    return results
```

Esto reduce la latencia de `N * t` a `max(t)`.

### Forzar tool choice

A veces quieres **obligar** al modelo a llamar una herramienta específica:

```python
# OpenAI
client.chat.completions.create(
    model="gpt-4o",
    messages=messages,
    tools=tools,
    tool_choice={"type": "function", "function": {"name": "get_weather"}},
)

# Anthropic
client.messages.create(
    model="claude-sonnet-4-5",
    max_tokens=1024,
    tools=tools,
    tool_choice={"type": "tool", "name": "get_weather"},
    messages=messages,
)
```

Opciones adicionales:

- `"auto"` (default): el modelo decide.
- `"required"` / `"any"`: obliga a llamar alguna, pero el modelo elige cuál.
- `"none"`: desactiva tool calling para esta llamada.

## Errores comunes

- **Over-eager function calling.** Ante *"¿qué hace `get_weather`?"* el modelo invoca la función en vez de explicarla. Mitigación: añade al system prompt *"si el usuario pregunta por metadatos de una herramienta, descríbela en texto; no la invoques"*.
- **Alucinación de parámetros.** Ante *"revisa el último PR"* el modelo inventa `pr_number=1`. Mitigación: haz que el modelo pida clarificación (en la description) o valida contra valores conocidos antes de ejecutar.
- **Confundir dos tools similares.** `analyze_security` vs `analyze_quality` con descripciones vagas. Mitigación: descripciones distintivas, menos tools por sesión, nombres claros.
- **Loops infinitos.** El modelo llama `get_pr_diff(1247)` cinco veces esperando resultado distinto. Mitigación: `max_iterations` duro, detección de calls repetidos idénticos, logging.
- **Context overflow por resultados gigantes.** Un diff de 50k líneas destruye el contexto. Mitigación: trunca, pagina, resume antes de devolver.
- **Olvidar devolver el resultado.** Si no envías `tool_result` después de un `tool_use` en Anthropic, el API falla con `400 invalid_request_error`.
- **IDs desalineados.** En Anthropic cada `tool_result` debe referenciar el `tool_use_id` exacto. Mezclar IDs genera errores silenciosos de atribución.
- **Pensar que function calling ejecuta la función.** El modelo **no** ejecuta nada; solo emite JSON. Tú ejecutas.

## Resumen

- **Function calling** convierte LLMs en agentes capaces de accionar sistemas reales mediante solicitudes estructuradas.
- Separa **intención** (modelo) de **ejecución** (tu código), dándote control, seguridad y auditabilidad.
- El protocolo tiene cuatro fases: **definir → seleccionar → ejecutar → integrar**.
- **OpenAI** (jun 2023), **Anthropic tool use** (may 2024) y **Gemini** comparten la idea pero varían en sintaxis; conviene una capa de abstracción si soportas múltiples providers.
- Soporta **parallel tool calls** (varias funciones en una sola respuesta) y **forced tool choice** (obligar una herramienta).
- Usa function calling cuando necesitas **acciones estructuradas, salidas precisas o auditabilidad**; evítalo para conversación pura.
- Diseña contra los pitfalls clásicos: alucinación de parámetros, loops infinitos, context overflow y confusión entre tools similares.
- Es la base para construir **agentes autónomos**, orquestar **workflows** y conectar LLMs al mundo real.
