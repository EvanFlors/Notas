# JSON Mode y Diseño de Schemas

## ¿Qué es?

**Structured output generation** es la disciplina de obligar a un LLM a producir texto que cumple un **contrato de formato** verificable por máquina (JSON válido, XML con cierre correcto, CSV con el número exacto de columnas) y, además, un **contrato semántico** (los campos tienen los nombres, tipos y rangos esperados).

Hay dos niveles separados que la gente confunde:

| Nivel | Qué garantiza | Qué NO garantiza |
|---|---|---|
| **JSON mode** (`response_format={"type": "json_object"}`) | El string de salida parsea como JSON válido | Que los campos se llamen como quieres, ni que los tipos sean correctos |
| **Structured outputs nativos** (schema estricto) | Validez sintáctica **más** conformidad con un JSON Schema | Que los valores sean *correctos* respecto a la realidad |

En términos prácticos: un `json_object` puro puede devolverte `{"customer_name": "Juan"}` cuando esperabas `{"name": "Juan"}`. Un schema estricto (OpenAI `response_format={"type": "json_schema", ..., "strict": True}`, Anthropic *tool use*, grammars de llama.cpp, Outlines) **rechaza el token** siguiente si no cumple el esquema, forzando salidas 100 % conformes.

### Breve evolución histórica

| Año | Técnica dominante | Problema |
|---|---|---|
| 2020-2022 | **Regex parsing** del output natural | Frágil, fallos silenciosos al cambiar el prompt |
| 2023 | **JSON mode** (OpenAI, nov 2023) | Sintaxis sí, semántica no |
| 2023 | **Function calling / tool use** | Primera forma de forzar un schema concreto |
| 2024 | **Structured outputs nativos** con decoding constrained | Garantía dura; adoptado por OpenAI, Anthropic, Google |
| 2024-2025 | Librerías (**Pydantic**, **Instructor**, **Outlines**, **BAML**) estandarizan la DX |  |

## ¿Por qué importa?

Un chatbot de soporte extrae datos de un ticket. Hoy devuelve `{"priority": "high"}`, mañana `{"urgency": "critical"}` y pasado un texto en prosa. El sistema aguas abajo (base de datos, cola de prioridad, dashboard) **se rompe en producción** porque fue escrito contra un contrato que el modelo no respeta.

Structured outputs importa porque:

- **Integración con sistemas existentes**: APIs, bases de datos y colas esperan tipos estrictos, no prosa.
- **Observabilidad y evaluación**: evaluar `recall` sobre un campo `priority` es trivial si el campo existe siempre; imposible si el modelo lo omite el 15 % de las veces.
- **Costo**: cada reintento por salida malformada paga tokens de entrada **y** de salida. En volumen, el ahorro es enorme.
- **Seguridad**: validar antes de ejecutar previene inyección de datos arbitrarios en herramientas (SQL, shell, APIs).
- **Composición de agentes**: un agente que llama a otro agente necesita un canal tipado; prosa libre es ruido.

### Cuándo NO forzar schema

- **Generación creativa libre** (narrativa, brainstorming): el schema estrangula al modelo.
- **Chat conversacional** con humano final: la respuesta ya es el producto.
- **Modelos muy pequeños** sin soporte nativo: el prompt engineering puede ser más barato que montar grammars.

## ¿Cómo funciona?

### JSON mode

Es un flag que modifica el **decoder** del servidor del modelo: durante el muestreo, solo se permiten tokens que puedan continuar un JSON válido. Garantiza `json.loads()` sin excepción, pero **no** valida nombres de campos ni tipos. Siempre debes incluir la palabra `JSON` en el prompt y describir el schema deseado en texto.

### Structured outputs nativos (schema estricto)

Un paso más: el provider recibe un JSON Schema y aplica **constrained decoding** sobre él. Cada posición de la secuencia solo acepta tokens compatibles con el schema. Resultado: la salida **siempre** valida contra tu modelo. Costos: menor fluidez cuando el schema es muy restrictivo, y no todos los modelos lo soportan.

### Function calling / tool use

Aunque nació para "llamar funciones", su mecanismo (describir un schema de argumentos y recibir un JSON conforme) es la forma **más portable** de obtener structured output. Anthropic recomienda explícitamente `tools` para esto; OpenAI expone ambos caminos.

### Constrained decoding con grammars

Librerías como **Outlines**, **llama.cpp (GBNF)**, **vLLM** y **SGLang** permiten imponer una **gramática libre de contexto** o una **expresión regular** sobre el muestreo. Esto es un superset de JSON Schema: puedes forzar un correo electrónico, un UUID, un código postal mexicano, o un dialecto propio.

### Comparativa de enfoques

| Enfoque | Garantía | Portabilidad | Overhead | Cuándo usarlo |
|---|---|---|---|---|
| Prompt + regex parsing | Ninguna | Total | Bajo | Prototipos, modelos sin API moderna |
| JSON mode | Sintaxis JSON | OpenAI, varios | Bajo | Cuando controlas el prompt y toleras post-validación |
| Tool use (Anthropic/OpenAI) | Schema completo | Alta entre providers top | Medio | Producción multi-provider |
| Structured outputs nativos | Schema completo | OpenAI, Google | Medio | Un solo provider, máxima garantía |
| Grammar-constrained (Outlines/llama.cpp) | Gramática arbitraria | Local / self-hosted | Alto | Modelos abiertos, formatos exóticos |

### Pydantic como lingua franca

**Pydantic v2** se ha convertido en el estándar de facto: defines una clase en Python, obtienes JSON Schema con `.model_json_schema()`, y validas con `Model.model_validate_json(texto)`. Las librerías modernas (**Instructor**, LangChain, LlamaIndex, OpenAI SDK ≥1.40) aceptan `BaseModel` directamente.

| Aspecto | JSON Schema crudo | Pydantic |
|---|---|---|
| Legibilidad | Verboso, anidado | Clases Python idiomáticas |
| Validación en runtime | Requiere `jsonschema` + código | Automática con mensajes claros |
| Documentación | `description` manual | Docstrings y `Field(description=...)` |
| Refactor | Buscar y reemplazar texto | Refactor del IDE |
| Interop | Universal | Exporta a JSON Schema trivialmente |

### Diseño de un schema robusto

1. **Especificidad progresiva**: empieza con enums amplios (`"technical" | "billing" | "account"`) y refina solo cuando los datos lo exijan.
2. **Agrupación semántica**: anida campos relacionados (`customer.email`, `customer.phone`) en vez de aplanar.
3. **Degradación elegante**: campos opcionales con `None` para la variabilidad del mundo real; los `required` solo para lo imprescindible.
4. **Profundidad máxima 3–4 niveles**: más allá, el modelo se confunde.
5. **`description` en TODOS los campos**: el modelo las lee como instrucciones.
6. **Indicadores de confianza**: incluye `confidence: float` o `_meta.uncertain: bool` para que el consumidor decida.
7. **Nombres consistentes**: `snake_case`, sin abreviaturas ambiguas.

## Ejemplo con código

### 1. JSON mode "clásico" (OpenAI)

```python
from openai import OpenAI
import json

client = OpenAI()

prompt = """Extrae los datos del ticket y devuelve SOLO JSON con las claves:
name (str), email (str|null), priority (uno de: low, medium, high).

Ticket: Hola, soy Sara Pérez (sara@acme.com), no puedo entrar a mi cuenta,
¡urgente, tengo demo mañana!"""

resp = client.chat.completions.create(
    model="gpt-4o-mini",
    messages=[{"role": "user", "content": prompt}],
    response_format={"type": "json_object"},  # garantiza JSON válido
)

data = json.loads(resp.choices[0].message.content)
print(data)  # {'name': 'Sara Pérez', 'email': 'sara@acme.com', 'priority': 'high'}
```

Problema: nada impide que el modelo devuelva `customer_name` en lugar de `name`.

### 2. Pydantic + schema estricto (OpenAI structured outputs)

```python
from pydantic import BaseModel, Field
from typing import Literal, Optional
from openai import OpenAI

client = OpenAI()

class Ticket(BaseModel):
    """Datos extraídos de un ticket de soporte."""
    name: str = Field(description="Nombre completo del cliente")
    email: Optional[str] = Field(default=None, description="Correo si aparece")
    phone: Optional[str] = Field(default=None, description="Teléfono si aparece")
    priority: Literal["low", "medium", "high"] = Field(
        description="Urgencia inferida del tono y contenido"
    )
    sentiment: float = Field(ge=-1.0, le=1.0, description="Sentimiento en [-1, 1]")

resp = client.chat.completions.parse(   # método tipado del SDK
    model="gpt-4o-2024-08-06",
    messages=[
        {"role": "system", "content": "Extrae datos del ticket."},
        {"role": "user", "content": "Soy Sara (sara@acme.com). ¡URGENTE!"},
    ],
    response_format=Ticket,              # Pydantic directo
)

ticket: Ticket = resp.choices[0].message.parsed
print(ticket.priority, ticket.sentiment)
```

El SDK convierte `Ticket` a JSON Schema, pasa `strict=True` y devuelve una instancia validada. Si el modelo intenta producir un `priority` fuera del `Literal`, el decoder lo bloquea.

### 3. Anthropic con tool use (patrón portable)

```python
import anthropic
from pydantic import BaseModel, Field
from typing import Literal

class Ticket(BaseModel):
    name: str
    priority: Literal["low", "medium", "high"]

client = anthropic.Anthropic()

msg = client.messages.create(
    model="claude-sonnet-4-5",
    max_tokens=1024,
    tools=[{
        "name": "save_ticket",
        "description": "Guarda el ticket estructurado.",
        "input_schema": Ticket.model_json_schema(),
    }],
    tool_choice={"type": "tool", "name": "save_ticket"},  # fuerza la llamada
    messages=[{"role": "user", "content": "Soy Sara, URGENTE no entro"}],
)

# El bloque con tipo "tool_use" contiene el JSON validado contra el schema
tool_block = next(b for b in msg.content if b.type == "tool_use")
ticket = Ticket.model_validate(tool_block.input)
```

`tool_choice` obligatorio es el truco: Anthropic no tiene un `response_format` genérico, pero forzar una herramienta produce el mismo efecto.

### 4. Instructor: la misma idea, un solo decorador

```python
import instructor
from openai import OpenAI
from pydantic import BaseModel

client = instructor.from_openai(OpenAI())

class Ticket(BaseModel):
    name: str
    priority: str

ticket = client.chat.completions.create(
    model="gpt-4o-mini",
    response_model=Ticket,
    max_retries=3,                       # reintenta con el error como feedback
    messages=[{"role": "user", "content": "Soy Sara, urgente"}],
)
```

Instructor envuelve el flujo *schema → prompt → parse → validate → retry* en una sola llamada. Soporta OpenAI, Anthropic, Groq, Ollama, etc.

### 5. Outlines (constrained decoding sobre modelos abiertos)

```python
import outlines
from pydantic import BaseModel

class Ticket(BaseModel):
    name: str
    priority: str

model = outlines.models.transformers("meta-llama/Llama-3.1-8B-Instruct")
generator = outlines.generate.json(model, Ticket)

ticket = generator("Soy Sara, urgente, no puedo entrar")
# `ticket` ES ya una instancia de Ticket; imposible que falle el parse
```

Outlines compila el schema a un **FSM** sobre el vocabulario del modelo, por lo que la garantía es dura incluso con un Llama local sin API de structured outputs.

### 6. JSON Schema crudo vs. Pydantic (el mismo contrato)

```json
{
  "type": "object",
  "properties": {
    "name":     {"type": "string", "description": "Nombre completo"},
    "email":    {"type": ["string", "null"], "format": "email"},
    "priority": {"type": "string", "enum": ["low", "medium", "high"]},
    "sentiment":{"type": "number", "minimum": -1, "maximum": 1}
  },
  "required": ["name", "priority", "sentiment"],
  "additionalProperties": false
}
```

```python
from pydantic import BaseModel, Field, EmailStr
from typing import Literal, Optional

class Ticket(BaseModel):
    model_config = {"extra": "forbid"}   # == additionalProperties: false
    name: str = Field(description="Nombre completo")
    email: Optional[EmailStr] = None
    priority: Literal["low", "medium", "high"]
    sentiment: float = Field(ge=-1, le=1)
```

### 7. Retry con validación como feedback

```python
from pydantic import ValidationError

def extract_with_retry(client, prompt: str, schema: type[BaseModel], n: int = 3):
    messages = [{"role": "user", "content": prompt}]
    for intento in range(n):
        resp = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=messages,
            response_format={"type": "json_object"},
        )
        raw = resp.choices[0].message.content
        try:
            return schema.model_validate_json(raw)
        except ValidationError as e:
            # Inyecta el error como mensaje para que el modelo se autocorrija
            messages.append({"role": "assistant", "content": raw})
            messages.append({"role": "user",
                             "content": f"La salida es inválida: {e}. Corrige y responde SOLO JSON."})
    raise RuntimeError("No se obtuvo salida válida tras N intentos")
```

## Errores comunes

- **Schema demasiado profundo o enorme**. Más de 4 niveles o 40 campos y el modelo confunde posiciones. Divide en varias llamadas o aplana.
- **Olvidar `description` en los `Field`**. El modelo las usa como mini-prompts por campo; sin ellas, inventa.
- **Enums mal definidos**. `["high", "High", "HIGH"]` o traducciones (`"alta"`) mezcladas → inconsistencia. Mantén un único canon.
- **Floats vs ints**. Si pides `rating: int` y el modelo escribe `4.0`, un schema no estricto lo aceptará; uno estricto lo rechazará. Decide y documenta.
- **No manejar `null`**. En JSON Schema debes usar `"type": ["string", "null"]`; en Pydantic `Optional[str] = None`. Omitirlo fuerza al modelo a inventar valores vacíos (`""`) o alucinar.
- **Comentarios estilo Python en la salida** (`// esto es...`). JSON no los admite. Pide explícitamente "sin comentarios".
- **Truncamiento por `max_tokens`**. El JSON queda cortado a la mitad. Monitorea `finish_reason == "length"` y sube el límite o pide una respuesta más corta.
- **Confiar en JSON mode como si fuese structured output estricto**. Garantiza sintaxis, no semántica: siempre valida con Pydantic/JSON Schema aguas abajo.
- **Mezclar documentación y datos en el mismo campo** (`"notes": "ver nota al pie..."`). Separa en subobjetos.
- **No versionar el schema**. Un cambio silencioso (renombrar `priority` → `urgency`) rompe consumidores sin que lo notes. Versiona (`schema_version: "1.2"`) y haz pruebas de contrato.
- **Validar solo al parsear**. La validación es *multi-capa*: sintaxis → tipos → PII/seguridad → reglas de negocio → lógica semántica. No metas todo en un `try/except`.

## Resumen

- **JSON mode** garantiza sintaxis JSON; **structured outputs nativos** garantizan sintaxis **y** conformidad con un schema.
- Un schema bien diseñado es un **contrato**: nombres canónicos, enums limitados, campos con `description`, opcionales marcados explícitamente.
- **Pydantic** es la forma más limpia de expresar schemas en Python; se traduce a JSON Schema para enviarlo al modelo.
- Para **portabilidad entre providers**, el truco universal es **tool use / function calling** con `tool_choice` forzado.
- Para **modelos abiertos o formatos exóticos**, usa **Outlines** o grammars GBNF: constrained decoding duro.
- **Instructor** encapsula el patrón prompt + schema + parse + retry en una API minimal.
- La **validación es multi-capa**: sintaxis primero (barata), semántica después (cara). Nunca uses un `AI judge` para validar lo que una regex puede resolver.
- Diseña siempre pensando en el **fallo**: `max_tokens` truncado, enums ligeramente mal escritos, campos faltantes. Retry con el error como feedback es la táctica más efectiva.
- Prefiere **especificidad progresiva** y **agrupación semántica** antes que schemas gigantes y planos.
- Incluye **indicadores de confianza** (`confidence`, `_meta`) para que los consumidores decidan sin reparsear.
- Versiona tus schemas y escribe **pruebas de contrato** contra ejemplos reales antes de desplegar.
