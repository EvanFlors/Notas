# La Capa de Ejecución

## ¿Qué es?

La **capa de ejecución** (execution layer) es el componente que **convierte las tool calls del modelo en acciones reales**. Cuando el LLM emite `analyze_code_security(pr_number=1247)`, es esta capa la que:

1. **Parsea** la solicitud estructurada.
2. **Enruta** al implementación correcta.
3. **Valida** parámetros contra el schema.
4. **Ejecuta** la función (API call, DB query, subprocess, etc.).
5. **Formatea** el resultado para que el modelo lo consuma.
6. **Maneja errores** y devuelve una respuesta estructurada.

Es el puente entre el razonamiento del LLM y los efectos en sistemas reales (GitHub, Stripe, PostgreSQL, Slack).

![Flujo de ejecución](https://hrcdn.net/ai-engineering/module-4/light/tool-integration-lesson03-execution-flow.svg)

## ¿Por qué importa?

Un schema perfecto no sirve de nada si la capa de ejecución es frágil. Los agentes de producción fallan aquí mucho más que en el prompt:

- **APIs con rate limits** (GitHub: 5000/hora autenticado) que tumban el agente al tercer PR.
- **Respuestas gigantes** que explotan el context window (un diff de 50k líneas).
- **Timeouts, errores de red, 500s** que no están contemplados.
- **Side effects irreversibles** sin confirmación (borrar, pagar, enviar).
- **Ejecución secuencial** cuando podría ser paralela, con latencia inaceptable.
- **Logs pobres** que vuelven imposible el debugging.

Una capa de ejecución bien diseñada es la diferencia entre un **demo que funciona** y un **sistema de producción confiable**.

## ¿Cómo funciona?

### Estructura básica

```
Tool call (JSON)
      ↓
[Router: name → impl]
      ↓
[Validador: args contra schema]
      ↓
[Executor: con timeouts + retry]
      ↓
[Formatter: resultado para el modelo]
      ↓
tool_result (JSON) → vuelve al LLM
```

Separa **routing**, **validación**, **ejecución** y **formatting** en responsabilidades distintas; cada una se testea y evoluciona por separado.

### Ejecución paralela con asyncio

Cuando el modelo emite varias tool calls en una sola respuesta (OpenAI y Anthropic lo soportan nativamente), ejecutarlas **en serie desperdicia latencia**. Usa `asyncio.gather`:

```python
import asyncio

async def execute_all(tool_calls, executor):
    tasks = [executor.execute(c.name, c.args) for c in tool_calls]
    return await asyncio.gather(*tasks, return_exceptions=True)
```

Latencia pasa de `sum(ti)` a `max(ti)`.

### Retry y backoff exponencial

Las APIs externas fallan transitoriamente. Reintenta con **backoff exponencial** solo para errores retryables (timeouts, 429, 503):

```python
async def with_retry(op, max_attempts=3, base=1.0):
    for i in range(max_attempts):
        try:
            return await op()
        except (TimeoutError, RateLimitError) as e:
            if i == max_attempts - 1:
                raise
            await asyncio.sleep(base * (2 ** i))
```

**Nunca** reintentes errores no retryables (400 bad request, 404 not found, 401 unauthorized).

### Circuit breaker

Si una API falla 5 veces en 60s, abre el circuito: siguientes llamadas fallan inmediatamente por N segundos. Protege tanto a tu agente como al servicio en degradación.

### Formatting de resultados

El modelo paga tokens por cada carácter que le devuelves. Reglas:

- **Resumen primero**, detalle después (o paginado).
- **Trunca listas largas** y adjunta `truncated: true, total: N`.
- **Formato consistente** entre tools: `{"success", "data", "error", "summary"}`.
- Incluye **recomendaciones accionables** cuando aplique.

### Safe code execution: sandboxes

Si el modelo escribe código (ej. `run_python(code=...)`), **nunca** lo ejecutes en tu proceso. Opciones:

| Sandbox | Caso de uso |
|---|---|
| **Jupyter kernel aislado** (jupyter-client) | Data analysis, interactivo |
| **Docker/gVisor** | Cualquier código, aislamiento fuerte |
| **Firecracker microVMs** (E2B, Modal, Daytona) | SaaS listo para agentes |
| **WebAssembly / Pyodide** | Browser-side, limitado |
| **restrictedpython / RestrictedPython** | Sandboxing a nivel AST (débil) |

Reglas: timeouts duros, sin red salvo whitelist, sin acceso a filesystem del host, sin credenciales montadas, kill del contenedor al terminar.

### Contexto de ejecución

Las tools suelen necesitar información ambiente: en qué repo estamos, qué usuario, qué permisos tiene, qué llamadas se hicieron antes. Pásalo como `ExecutionContext` inyectado:

```python
from dataclasses import dataclass, field

@dataclass
class ExecutionContext:
    user_id: str
    permissions: list[str]
    session_id: str
    tool_history: list[dict] = field(default_factory=list)
    token_budget: int = 50_000
```

Esto habilita permisos, caching, deduplicación y auditoría.

## Ejemplo con código

### Executor con validación, retry y formatting

```python
import asyncio
import json
import jsonschema
from typing import Any, Callable

class ToolExecutor:
    def __init__(self):
        self.schemas: dict[str, dict] = {}
        self.impls: dict[str, Callable] = {}

    def register(self, schema: dict, impl: Callable):
        self.schemas[schema["name"]] = schema
        self.impls[schema["name"]] = impl

    async def execute(self, name: str, args: dict) -> dict:
        if name not in self.impls:
            return self._err("unknown_tool", f"Herramienta '{name}' no registrada")

        # Validación de argumentos
        try:
            jsonschema.validate(args, self.schemas[name]["input_schema"])
        except jsonschema.ValidationError as e:
            return self._err("validation_error", e.message)

        # Ejecución con retry y timeout
        try:
            result = await asyncio.wait_for(
                self._with_retry(lambda: self.impls[name](**args)),
                timeout=30.0,
            )
            return {"success": True, "data": result}
        except asyncio.TimeoutError:
            return self._err("timeout", "La herramienta tardó más de 30s", retryable=True)
        except Exception as e:
            return self._err(type(e).__name__, str(e))

    async def _with_retry(self, op, attempts=3):
        for i in range(attempts):
            try:
                res = op() if not asyncio.iscoroutinefunction(op) else await op()
                return res
            except (TimeoutError, ConnectionError) as e:
                if i == attempts - 1:
                    raise
                await asyncio.sleep(2 ** i)

    def _err(self, type_: str, msg: str, retryable: bool = False) -> dict:
        return {
            "success": False,
            "error": {"type": type_, "message": msg, "retryable": retryable},
        }
```

### Implementaciones: get_weather, search_db, send_email

```python
import httpx

async def get_weather(city: str, units: str = "celsius") -> dict:
    async with httpx.AsyncClient(timeout=10) as c:
        r = await c.get(
            "https://api.openweathermap.org/data/2.5/weather",
            params={"q": city, "units": "metric" if units == "celsius" else "imperial"},
        )
        r.raise_for_status()
        data = r.json()
        return {
            "temp": data["main"]["temp"],
            "units": units,
            "condition": data["weather"][0]["main"],
        }

async def search_db(query: str, field: str = "name", limit: int = 10) -> list[dict]:
    # Pseudo: en producción, async DB driver (asyncpg, motor, etc.)
    rows = await db.fetch(
        f"SELECT id, name, email FROM customers WHERE {field} ILIKE $1 LIMIT $2",
        f"%{query}%", limit,
    )
    return [dict(r) for r in rows]

async def send_email(to: str, subject: str, body: str, priority: str = "normal") -> dict:
    # Human-in-the-loop recomendado para side effects
    msg_id = await mail_client.send(to=to, subject=subject, body=body, priority=priority)
    return {"sent": True, "message_id": msg_id}
```

### Ejecución paralela con asyncio.gather

```python
async def run_parallel(executor: ToolExecutor, calls: list[dict]) -> list[dict]:
    tasks = [executor.execute(c["name"], c["args"]) for c in calls]
    return await asyncio.gather(*tasks)

# Ejemplo: el modelo pidió clima de dos ciudades a la vez
calls = [
    {"name": "get_weather", "args": {"city": "Mexico City"}},
    {"name": "get_weather", "args": {"city": "Buenos Aires"}},
]
# asyncio.run(run_parallel(executor, calls))
```

### Retry on tool error (loop del agente)

Cuando una tool falla con `retryable: true`, el agente debe reintentar o pedir ayuda. Devuelve el error al modelo para que decida:

```python
async def agent_turn(client, messages, tools, executor, max_iters=10):
    for _ in range(max_iters):
        resp = await client.messages.create(
            model="claude-sonnet-4-5",
            max_tokens=2048,
            tools=tools,
            messages=messages,
        )
        messages.append({"role": "assistant", "content": resp.content})
        if resp.stop_reason != "tool_use":
            return resp

        tool_use_blocks = [b for b in resp.content if b.type == "tool_use"]
        results = await asyncio.gather(*[
            executor.execute(b.name, b.input) for b in tool_use_blocks
        ])

        messages.append({
            "role": "user",
            "content": [
                {
                    "type": "tool_result",
                    "tool_use_id": b.id,
                    "content": json.dumps(r),
                    "is_error": not r["success"],
                }
                for b, r in zip(tool_use_blocks, results)
            ],
        })
    raise RuntimeError("Max iteraciones alcanzado")
```

`is_error: true` le indica al modelo que puede reintentar con otros argumentos o cambiar de estrategia.

### Sandbox para ejecutar código (E2B)

```python
# pip install e2b-code-interpreter
from e2b_code_interpreter import Sandbox

async def run_python(code: str) -> dict:
    with Sandbox() as sbx:
        exec_ = sbx.run_code(code, timeout=15)
        return {
            "stdout": exec_.logs.stdout,
            "stderr": exec_.logs.stderr,
            "results": [r.text for r in exec_.results],
            "error": exec_.error.name if exec_.error else None,
        }
```

E2B ejecuta en un microVM Firecracker aislado, con filesystem y red controlados.

### Formatting de resultados grandes

```python
def truncate_result(data: str, max_chars: int = 4000) -> dict:
    if len(data) <= max_chars:
        return {"content": data, "truncated": False}
    return {
        "content": data[:max_chars],
        "truncated": True,
        "total_chars": len(data),
        "hint": "Usa get_file_chunk(path, start, end) para pedir una sección específica",
    }
```

## Errores comunes

- **No validar args antes de ejecutar.** El modelo manda `pr_number="1247"` (string) y tu función crashea esperando int. Usa `jsonschema` o Pydantic.
- **Reintentar errores no retryables.** Reintentar un 401 Unauthorized tres veces solo retrasa el fallo. Clasifica errores primero.
- **Ejecutar tools con side effects sin confirmación.** `send_email`, `delete_user`, `charge_card` deben requerir un approval explícito (human-in-the-loop) o un flag `dry_run`.
- **Devolver respuestas crudas gigantes.** 50k líneas de diff destruyen el contexto. Trunca, resume o pagina.
- **Logs pobres.** Sin logs estructurados por tool call (name, args, duration, outcome) es imposible debuggear producción.
- **No manejar tool errors de forma estructurada.** Devolver `None` o lanzar excepción no entendida deja al agente ciego. Devuelve siempre `{"success": False, "error": {...}}` con `type` y `retryable`.
- **Hardcodear credenciales en el impl.** Usa `ExecutionContext` o un secret manager (Vault, AWS Secrets Manager, env vars).
- **Ejecución secuencial cuando podría ser paralela.** Si el modelo emite 5 tool calls independientes, no las corras en for loop.
- **Olvidar timeouts.** Una API que cuelga indefinidamente congela al agente. Siempre `asyncio.wait_for` o equivalente.
- **Correr código del LLM sin sandbox.** Un `exec(code)` directo es RCE total. Usa Jupyter aislado, Docker, Firecracker.
- **No invalidar cache.** Devolver datos cacheados sin notar que la fuente cambió lleva a decisiones basadas en información obsoleta.

## Resumen

- La **capa de ejecución** enruta tool calls a implementaciones, valida argumentos, ejecuta y formatea resultados.
- Separa responsabilidades: **router + validador + executor + formatter**; cada pieza se testea aislada.
- Integra APIs externas con **rate limiting**, **timeouts** y **retry con backoff exponencial** solo para errores retryables.
- Usa **`asyncio.gather`** para ejecutar tool calls paralelas que el modelo emite en una sola respuesta.
- Devuelve **errores estructurados** (`type`, `message`, `retryable`, `recovery_options`) para que el agente pueda reaccionar.
- Formatea resultados **concisos, consistentes y accionables**; trunca o pagina lo grande.
- Para code execution usa **sandboxes aislados** (Jupyter aislado, Docker, Firecracker, E2B); nunca `exec()` directo.
- Mantén un **ExecutionContext** con permisos, historial y token budget para habilitar auditoría y caching.
- **Circuit breakers** y **graceful degradation** evitan que un servicio caído tumbe todo el agente.
- Testea con **mocks** (unit) y **servicios reales** (integration); incluye casos de error (timeouts, rate limits, respuestas inválidas).
