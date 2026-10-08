# Anatomía de un Tool Schema

## ¿Qué es?

Un **tool schema** es el **contrato** entre tu agente y una capacidad. Describe, en formato estructurado (JSON Schema), qué hace una función, qué recibe y qué devuelve. No es solo documentación técnica: es la **instrucción** que guía el comportamiento del modelo. El LLM decide **qué** herramienta usar y **con qué parámetros** basándose casi exclusivamente en el schema.

Todo schema tiene tres componentes esenciales:

1. **`name`**: identificador único, action-oriented (`get_pr_details`, no `process_data`).
2. **`description`**: el componente más importante; explica qué hace, cuándo usarse, qué devuelve y limitaciones.
3. **`parameters`** (o `input_schema` en Anthropic): JSON Schema con tipos, descripciones, enums y requeridos.

![Componentes de un tool schema](https://hrcdn.net/ai-engineering/module-4/light/tool-integration-lesson02-schema-anatomy.svg)

## ¿Por qué importa?

Un error muy frecuente al construir agentes: *"mi agente tiene 20 herramientas y siempre llama la equivocada"*. En el 90% de los casos **el problema no son las herramientas, es el schema**.

Descripciones vagas, nombres ambiguos y parámetros mal tipados producen:

- **Selección errónea de tools:** confusión entre `analyze_security` y `analyze_quality`.
- **Alucinación de parámetros:** el modelo inventa valores porque no sabe qué enums aceptas.
- **Loops:** el modelo reintenta porque no entiende qué devolvió la función.
- **Deuda técnica invisible:** cada nuevo tool mal descrito empeora al resto por **tool explosion**.

Un schema bien escrito **reduce costos** (menos iteraciones), **mejora reliability** y es más barato que hacer fine-tuning.

### Lo que la industria aprendió

- **OpenAI function calling** (jun 2023) usa JSON Schema estándar.
- **Anthropic tool use** (may 2024) también adopta JSON Schema bajo la clave `input_schema`.
- **Pydantic** se volvió el estándar de facto en Python para generar schemas automáticamente (`model.model_json_schema()`).
- **LangChain**, **LlamaIndex** y **MCP** proveen abstracciones que convierten funciones Python en schemas con decoradores.

## ¿Cómo funciona?

### Nombres descriptivos

Elige una convención y mantenla:

- **`verb_noun`** (`get_pr_details`, `check_test_coverage`, `post_review_comment`).
- Evita palabras vacías: `process`, `handle`, `do_action`, `manage`.
- Snake_case consistente (OpenAI y Anthropic lo esperan).
- Prefijos por dominio si tienes muchas tools (`github_get_pr`, `jira_create_ticket`).

| Nombre pobre | Nombre bueno |
|---|---|
| `data` | `fetch_customer_record` |
| `check` | `check_test_coverage` |
| `send` | `send_email_to_user` |
| `getStuff` | `get_pending_orders` |

### Descripciones efectivas

La descripción debe responder cuatro preguntas:

1. **Qué hace** la función en términos concretos.
2. **Cuándo usarla** (y cuándo no).
3. **Qué devuelve** (formato y campos).
4. **Limitaciones** y constraints.

Compara:

> **Mala:** "Escanea código buscando problemas."
>
> **Buena:** "Analiza archivos de código fuente en busca de vulnerabilidades de seguridad incluyendo SQL injection, XSS y fallas de autenticación. Úsala después de `get_pr_details` para identificar issues que deberían bloquear el merge. Devuelve una lista de vulnerabilidades con `severity`, `file`, `line` y `remediation`. Solo escanea archivos Python y JavaScript, máximo 50 archivos por llamada."

### JSON Schema para parámetros

El estándar que usan los tres providers es **JSON Schema Draft-7** (OpenAI, Anthropic) o un subset tipo OpenAPI (Gemini). Tipos soportados:

| Tipo | Uso | Ejemplo |
|---|---|---|
| `string` | Texto | `"CDMX"` |
| `integer` | Enteros | `1247` |
| `number` | Float | `0.8` |
| `boolean` | True/False | `true` |
| `array` | Lista con `items` | `["a.py", "b.py"]` |
| `object` | Diccionario con `properties` | `{"k": "v"}` |
| `enum` | Valores restringidos | `["low", "med", "high"]` |

Ejemplo completo:

```json
{
  "name": "search_db",
  "description": "Busca registros en la base de datos de clientes...",
  "parameters": {
    "type": "object",
    "properties": {
      "query": {
        "type": "string",
        "description": "Término de búsqueda. Mínimo 3 caracteres."
      },
      "limit": {
        "type": "integer",
        "description": "Máximo de resultados. Default: 10, máximo: 100.",
        "minimum": 1,
        "maximum": 100
      },
      "status": {
        "type": "string",
        "enum": ["active", "inactive", "pending"],
        "description": "Filtra por estado. Default: active."
      }
    },
    "required": ["query"]
  }
}
```

### Patrones de diseño de parámetros

- **Usa `enum` para valores restringidos.** Evita que el modelo invente `"HIGH"` cuando esperas `"high"`.
- **Minimiza `required`.** Solo exige lo que no puedes defaultear; el modelo llama más fácilmente cuando puede omitir campos.
- **Documenta defaults en la description** (JSON Schema no tiene un campo `default` que el modelo siempre respete).
- **Un tipo claro por parámetro.** `pr_number` debe ser `integer`, nunca `string` ambiguo que acepte `"PR-1247"` o `"#1247"`.
- **Nested objects para configuración compleja**, en vez de 15 flags planos.
- **Arrays con `items` tipados** para listas.

![Patrones de diseño de parámetros](https://hrcdn.net/ai-engineering/module-4/light/tool-integration-lesson02-param-patterns.svg)

### Return format consistente

El modelo también lee los resultados. Mantén la **misma forma** para todas tus tools:

```python
def tool_result(success: bool, data=None, error=None, summary=None):
    return {
        "success": success,
        "data": data,
        "error": error,
        "summary": summary,  # breve, para que el modelo no reprocese todo
    }
```

Así el modelo aprende el patrón y navega los resultados con mucha menos fricción.

### Composición y reuso

Define parámetros comunes como constantes y compón schemas:

```python
PR_NUMBER_PARAM = {"type": "integer", "description": "Número del pull request"}

SEVERITY_PARAM = {
    "type": "string",
    "enum": ["low", "medium", "high", "critical"],
    "description": "Umbral mínimo de severidad. Default: medium.",
}

def make_tool(name, description, params, required):
    return {
        "name": name,
        "description": description,
        "parameters": {"type": "object", "properties": params, "required": required},
    }
```

## Ejemplo con código

### Definir tres herramientas (get_weather, search_db, send_email)

```python
tools = [
    {
        "name": "get_weather",
        "description": (
            "Obtiene el clima actual para una ciudad. Devuelve un objeto "
            "con 'temp_c' (float), 'condition' (string) y 'humidity' (int 0-100). "
            "Úsala cuando el usuario pregunte por clima, temperatura o lluvia. "
            "No soporta pronósticos a más de 24h."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "city": {
                    "type": "string",
                    "description": "Nombre de la ciudad en inglés, ej. 'Mexico City'",
                },
                "units": {
                    "type": "string",
                    "enum": ["celsius", "fahrenheit"],
                    "description": "Unidades. Default: celsius",
                },
            },
            "required": ["city"],
        },
    },
    {
        "name": "search_db",
        "description": (
            "Busca clientes en la base de datos interna por nombre, email o ID. "
            "Devuelve una lista de objetos cliente con 'id', 'name', 'email', 'tier'. "
            "Úsala antes de operaciones que requieran el customer_id. Máximo 50 resultados."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Término de búsqueda (min 3 chars)"},
                "field": {
                    "type": "string",
                    "enum": ["name", "email", "id"],
                    "description": "Campo donde buscar. Default: name",
                },
                "limit": {
                    "type": "integer",
                    "description": "Máx. resultados (1-50). Default: 10",
                },
            },
            "required": ["query"],
        },
    },
    {
        "name": "send_email",
        "description": (
            "Envía un email transaccional a un cliente. Devuelve "
            "{'sent': bool, 'message_id': str}. Úsala solo tras confirmar "
            "la acción con el usuario; tiene efectos externos irreversibles."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "to": {"type": "string", "description": "Email del destinatario"},
                "subject": {"type": "string", "description": "Asunto, máx. 120 chars"},
                "body": {"type": "string", "description": "Cuerpo en Markdown"},
                "priority": {
                    "type": "string",
                    "enum": ["low", "normal", "high"],
                    "description": "Prioridad. Default: normal",
                },
            },
            "required": ["to", "subject", "body"],
        },
    },
]
```

### Generar schemas desde Pydantic

Escribir JSON a mano es tedioso y propenso a errores. **Pydantic** convierte modelos Python en JSON Schema:

```python
from pydantic import BaseModel, Field
from typing import Literal

class GetWeatherArgs(BaseModel):
    """Obtiene el clima para una ciudad."""
    city: str = Field(..., description="Nombre en inglés, ej. 'Mexico City'")
    units: Literal["celsius", "fahrenheit"] = Field(
        "celsius", description="Unidades. Default: celsius"
    )

schema = {
    "name": "get_weather",
    "description": GetWeatherArgs.__doc__.strip(),
    "input_schema": GetWeatherArgs.model_json_schema(),
}
```

Librerías como **LangChain** (`@tool` decorator), **Instructor** o **Marvin** automatizan esto.

### Validación de schemas y argumentos

```python
import jsonschema

def validate_tool_schema(schema):
    meta = {
        "type": "object",
        "required": ["name", "description", "input_schema"],
        "properties": {
            "name": {"type": "string", "pattern": "^[a-z][a-z0-9_]*$"},
            "description": {"type": "string", "minLength": 20},
            "input_schema": {"type": "object"},
        },
    }
    jsonschema.validate(schema, meta)
    jsonschema.Draft7Validator.check_schema(schema["input_schema"])

def execute_tool(name, args, schemas, impls):
    try:
        jsonschema.validate(args, schemas[name]["input_schema"])
    except jsonschema.ValidationError as e:
        return {"success": False, "error": f"Invalid arguments: {e.message}"}
    return impls[name](**args)
```

### Registro central de tools

```python
class ToolRegistry:
    def __init__(self):
        self.tools: dict[str, dict] = {}
        self.impls: dict[str, callable] = {}

    def register(self, schema: dict, impl: callable):
        validate_tool_schema(schema)
        self.tools[schema["name"]] = schema
        self.impls[schema["name"]] = impl

    def for_task(self, task: str) -> list[dict]:
        presets = {
            "review": ["get_pr_details", "analyze_code_security", "post_review_comment"],
            "support": ["search_db", "send_email"],
        }
        return [self.tools[n] for n in presets.get(task, self.tools.keys())]
```

Exponer **menos tools por sesión** reduce la tasa de errores de selección drásticamente.

## Errores comunes

- **Descripciones vagas.** `"Maneja operaciones de PR"` no le dice nada al modelo. Sé específico: qué, cuándo, qué devuelve, límites.
- **No validar argumentos (type coercion).** Confiar en que el modelo mandó un `int` y crashear cuando mandó `"1247"`. Siempre valida con JSON Schema o Pydantic.
- **Tools con side effects sin confirmación.** `delete_user`, `send_email`, `charge_payment` no deberían ejecutarse sin un paso explícito de confirmación humana (human-in-the-loop) o guardrails.
- **Tool explosion.** 40 herramientas confunden al modelo. Agrupa por tareas y expón subconjuntos relevantes.
- **Nombres inconsistentes.** `pr_number` en una tool y `pull_request_id` en otra para el mismo concepto. El modelo no detecta equivalencia.
- **Faltan `enum` donde los valores son fijos.** El modelo inventará `"HIGH"`, `"H"`, `"severe"` si no restringes.
- **Defaults no documentados.** Si `limit` default es 10, dilo en la description; JSON Schema `default` no siempre llega al modelo.
- **No describir el formato de retorno.** Si no documentas que `search_db` devuelve `[{"id", "name"}, ...]`, el modelo adivinará campos.
- **Descripciones que repiten el nombre.** `"get_weather: gets the weather"` no agrega valor. Describe el comportamiento, no reempaquetes el identificador.
- **Over-specification.** No conviertas la description en una novela de 1000 tokens; cada tool compite por atención y tokens de system prompt.

## Resumen

- Un **tool schema** es el contrato que guía al modelo en la selección y parametrización de herramientas.
- Los tres componentes clave son **name** (claro, action-oriented), **description** (lo más importante) y **parameters** (JSON Schema).
- La **description** debe cubrir qué hace, cuándo usarse, qué devuelve y limitaciones; es la variable con mayor impacto en reliability.
- Diseña parámetros con **enums** para valores restringidos, **defaults documentados** y **tipos sin ambigüedad**; mantén los `required` al mínimo.
- Usa **Pydantic** o `@tool` decorators de LangChain para generar schemas automáticamente desde Python.
- Mantén un **return format consistente** (`{"success", "data", "error", "summary"}`) para que el modelo aprenda el patrón.
- Centraliza en un **ToolRegistry** y expón **subconjuntos por tarea** para evitar tool explosion.
- Valida **estructuralmente** los schemas (con `jsonschema`) y **runtime** los argumentos antes de ejecutar.
- Los errores de selección casi siempre se arreglan mejorando descripciones, no reentrenando modelos.
