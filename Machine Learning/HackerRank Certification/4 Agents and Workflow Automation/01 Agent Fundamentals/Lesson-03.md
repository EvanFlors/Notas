# Diseño de Herramientas (Tools) para Agentes

## ¿Qué es?

Una **tool** (herramienta) es una función que el agente puede invocar: una API, una consulta a base de datos, un script, un cálculo. Técnicamente es un trío **(nombre, descripción, schema de parámetros)** que se le expone al LLM, más una **implementación real** en tu backend. Cuando el modelo decide usarla, devuelve un bloque estructurado (`tool_use` en Anthropic, `function_call` en OpenAI) con el nombre y los argumentos; tu runtime la ejecuta y devuelve el resultado como observation.

Las tools son **las manos y los ojos del agente**. Un reasoning engine brillante con tools mal diseñadas es como un cirujano experto con instrumentos oxidados: el conocimiento está, la ejecución falla.

### Niveles de abstracción

| Nivel | Ejemplo | Pros | Contras |
|---|---|---|---|
| **Bajo** | `github_api_call(endpoint, method, body)` | Flexibilidad máxima | El agente debe conocer la API; muchos errores |
| **Medio** | `get_pr_details(pr_number)`, `merge_pr(pr_number, method)` | Compone bien, mapea al dominio | Hay que diseñar varias |
| **Alto** | `merge_pr_if_approved(pr_number)` | Simple y seguro | Rígido ante casos nuevos |

La regla práctica: **apunta a abstracción media**. Mapea a operaciones de dominio significativas (equivalente a los endpoints REST que diseñarías para un humano) y deja que el agente las componga.

### El action space

El conjunto de tools disponibles es el **espacio de acción** del agente. Separarlo por nivel de riesgo es un principio de seguridad fundamental:

| Categoría | Ejemplo | Control |
|---|---|---|
| **Read-only** | `get_pr_details`, `check_test_coverage` | Libre |
| **Write bajo riesgo** | `add_pr_comment`, `add_label` | Rate-limited |
| **Write alto riesgo** | `merge_pr`, `delete_branch`, `deploy_production` | Requiere human-in-the-loop |

## ¿Por qué importa?

Un agente **no puede hacer lo que sus tools no le permiten**. El techo de capacidad de tu sistema es el catálogo que diseñas. Y los dos modos de falla más caros en producción vienen del toolset, no del modelo:

- **Agente que no puede completar tareas** porque le faltan tools (o están tan mal descritas que no sabe cuándo usarlas).
- **Agente que hace daño real** porque le diste `delete_database` sin permiso ni auditoría.

Buenas descripciones de tools suelen aportar **más mejora** que cambiar de modelo. La selección de tool es un problema de **retrieval** disfrazado: el LLM "busca" en tus descripciones la que mejor matchea su situación. Descripciones vagas = selección aleatoria.

## ¿Cómo funciona?

### Patrones de implementación

**Validation layer.** Antes de ejecutar, valida precondiciones de negocio (no solo tipos):

```python
def merge_pr(pr_number: int, method: str = "merge") -> dict:
    pr = get_pr(pr_number)
    if not pr:
        return {"success": False, "error": "PR no encontrado"}
    if pr["target_branch"] == "main" and not pr["has_approvals"]:
        return {"success": False, "error": "main requiere al menos una aprobación"}
    if pr["ci_status"] != "passing":
        return {"success": False, "error": "CI no está en verde"}
    return {"success": True, "sha": github_api.merge(pr_number, method)}
```

**Idempotencia.** Llamar dos veces debe ser seguro. `add_label(pr=1247, label="review")` llamado dos veces no crea duplicados ni falla.

**Errores estructurados.** Nunca lances excepciones hacia el loop: devuelve dicts que el modelo pueda razonar:

```python
{
  "success": False,
  "error_type": "permission_denied",
  "error_message": "no tienes acceso a producción",
  "suggested_action": "pide aprobación al admin o usa el read-replica"
}
```

**Rate limiting y cost caps.** Toda tool costosa debe tener su propio contador y rechazar llamadas una vez excedido el budget.

### Documentación que el agente realmente lee

Comparación:

| Pobre | Buena |
|---|---|
| `"Reviews code changes"` | `"Analiza cambios de código en un PR por vulnerabilidades, violaciones de estilo y bugs. Úsala tras get_pr_details. Requiere pr_number y opcionalmente lista de archivos. Devuelve lista de issues con severidad, línea y fix sugerido."` |

Incluye en la descripción: **qué hace, cuándo usarla, qué parámetros, qué devuelve, ejemplos de uso**.

### Versionado y evolución

- **Añadir tools** suele ser seguro, pero puede confundir si solapa con existentes.
- **Modificar firmas** rompe prompts cacheados: versiona (`tool_v1`, `tool_v2`) y mantén backward compatibility.
- **Deprecar** gradualmente: la tool vieja devuelve `{"deprecated": True, "use_instead": "..."}` antes de retirarla.

### Seguridad y sandboxing

Toda tool corre en tu entorno con acceso real. Asume que **el agente puede comportarse mal** (prompt injection, bugs, usuarios maliciosos):

| Control | Qué hace |
|---|---|
| **Permission system** | Cada agent instance tiene un rol; la tool verifica antes de ejecutar |
| **Input sanitization** | Allowlist de nombres de tabla, parametrizar queries SQL, nunca `eval` |
| **Audit logging** | Cada tool call → log estructurado (quién, qué, cuándo, resultado) |
| **Sandboxing** | Tools que ejecutan código corren en Docker/microVM aislado |

### Herramientas del ecosistema

- **Anthropic SDK** (`tool_use` nativo + MCP server protocol).
- **OpenAI Function Calling** + Assistants API.
- **LangChain `@tool`** + **LangGraph** para el loop.
- **LlamaIndex Tool / FunctionTool** orientado a RAG.
- **CrewAI** para multi-agente con tools compartidas.

## Ejemplo con código

### Tool bien diseñada con validación, errores estructurados y rate limit

```python
from langchain_core.tools import tool
from pydantic import BaseModel, Field
from typing import Literal
import time

class MergeArgs(BaseModel):
    pr_number: int = Field(..., gt=0, description="ID del PR")
    method: Literal["merge", "squash", "rebase"] = Field(
        "squash", description="Método de merge. 'squash' recomendado para feature branches."
    )

class RateLimiter:
    def __init__(self, max_calls=5, window_s=60):
        self.max_calls, self.window_s, self.calls = max_calls, window_s, []
    def allow(self):
        now = time.time()
        self.calls = [t for t in self.calls if now - t < self.window_s]
        if len(self.calls) >= self.max_calls:
            return False
        self.calls.append(now)
        return True

merge_limiter = RateLimiter(max_calls=3, window_s=300)  # 3 merges / 5 min

@tool("merge_pr", args_schema=MergeArgs)
def merge_pr(pr_number: int, method: str = "squash") -> dict:
    """
    Mergea un PR en la rama destino.

    Cuándo usar: cuando el PR tiene al menos una aprobación y CI en verde.
    No usar en: PRs con conflicts, sin reviews, o apuntando a main sin 2 approvals.
    Devuelve: {"success": bool, "sha": str, "merged_at": str} o {"success": False, "error_type": str, ...}
    """
    if not merge_limiter.allow():
        return {"success": False, "error_type": "rate_limited",
                "suggested_action": "esperar 5 min antes de reintentar"}

    pr = fetch_pr(pr_number)
    if not pr:
        return {"success": False, "error_type": "not_found",
                "error_message": f"PR #{pr_number} no existe"}

    if pr["ci_status"] != "passing":
        return {"success": False, "error_type": "ci_failing",
                "error_message": "CI en rojo",
                "suggested_action": "pedirle al autor que arregle los tests"}

    if pr["target_branch"] == "main" and pr["approvals"] < 2:
        return {"success": False, "error_type": "insufficient_approvals",
                "error_message": "main requiere 2 approvals",
                "suggested_action": "solicitar segunda review"}

    result = github_api.merge(pr_number, method)
    audit_log.write(action="merge_pr", pr=pr_number, by="agent", result=result)
    return {"success": True, "sha": result["sha"], "merged_at": result["timestamp"]}
```

Nota qué incluye la docstring: *qué hace, cuándo usar, cuándo no, qué devuelve*. Eso es lo que el LLM lee para decidir.

### Tool registry dinámico con permisos

```python
class ToolRegistry:
    def __init__(self):
        self._tools = {}  # name -> (fn, required_permission, cost_usd)

    def register(self, name, fn, permission="read", cost=0.0):
        self._tools[name] = (fn, permission, cost)

    def available_for(self, agent_role: str) -> list[dict]:
        allowed = ROLE_PERMISSIONS[agent_role]
        return [
            {"name": name, "description": fn.__doc__, "cost": cost}
            for name, (fn, perm, cost) in self._tools.items()
            if perm in allowed
        ]

    def dispatch(self, name, args, agent_ctx):
        fn, required_perm, cost = self._tools[name]
        if required_perm not in agent_ctx.permissions:
            return {"success": False, "error_type": "permission_denied"}
        if agent_ctx.budget_remaining < cost:
            return {"success": False, "error_type": "budget_exceeded"}
        agent_ctx.budget_remaining -= cost
        return fn(**args)
```

El agente solo ve las tools permitidas para su rol: separación limpia entre capacidad y autorización.

### Testing: correctness + agent usability

```python
def test_merge_pr_blocks_without_approvals():
    r = merge_pr(pr_number=42)      # PR sin approvals
    assert r["success"] is False
    assert r["error_type"] == "insufficient_approvals"
    assert "suggested_action" in r   # el agente necesita la pista

def test_agent_recovers_on_ci_failure(monkeypatch):
    monkeypatch.setattr("tools.merge_pr", lambda **k: {
        "success": False, "error_type": "ci_failing",
        "suggested_action": "pedir al autor que arregle los tests"
    })
    agent = create_react_agent(llm, tools=[get_pr_details, merge_pr, add_pr_comment])
    r = agent.invoke({"messages": [("user", "Mergea el PR #99")]})
    # El agente debe haber comentado en vez de insistir en mergear
    assert any(call.tool == "add_pr_comment" for call in r["tool_calls"])
```

El segundo test valida **usabilidad por el agente**: ¿el mensaje de error es útil para que el modelo cambie de estrategia?

### Patrones de performance

```python
# 1) Caching de reads
from functools import lru_cache
@lru_cache(maxsize=256)
def get_pr_details_cached(pr_number: int): ...

# 2) Ejecución paralela de tools independientes
import asyncio
async def run_parallel(calls):
    return await asyncio.gather(*[dispatch_async(c) for c in calls])

# 3) Timeout por tool
import signal
def with_timeout(fn, seconds):
    def wrapper(*a, **kw):
        signal.alarm(seconds)
        try: return fn(*a, **kw)
        except TimeoutError:
            return {"success": False, "error_type": "timeout"}
        finally: signal.alarm(0)
    return wrapper
```

## Errores comunes

- **Tools demasiado bajas (API raw).** El agente se enreda con pagination, encoding y headers. Sube un nivel de abstracción.
- **Tools demasiado altas y rígidas.** `do_everything(goal)` esconde lógica compleja y es incapaz de manejar variantes. Divide en operaciones de dominio.
- **Descripciones pobres.** `"Gets data"` provoca selección aleatoria. Escribe docstrings ricas con *qué, cuándo, ejemplos*.
- **Lanzar excepciones hacia el loop.** El agente crashea. Devuelve siempre dicts estructurados con `success`, `error_type`, `suggested_action`.
- **Olvidar idempotencia.** Dos llamadas crean duplicados o fallan. Haz las writes idempotentes (clave única, upsert).
- **No separar read/write por riesgo.** Darle `delete_user` al mismo agente que `search_users` sin autorización humana es un incidente esperando a ocurrir.
- **Permisos solo en el prompt.** El modelo puede ignorarlos. Enforce en la execution layer, nunca "confiando" en el prompt.
- **Prompt injection vía observation.** Si una tool devuelve texto controlable por el usuario (contenido de un issue, mensaje de email) el atacante puede inyectar instrucciones. Sanitiza o encapsula las observations.
- **Tools sin tests.** Son código de producción; cóbralos con unit tests, integration tests y **agent-usability tests** (¿el agente las usa bien?).
- **Context explosion por outputs enormes.** Una tool que devuelve 50KB de JSON infla el contexto rápido. Devuelve resúmenes y un token/ID para pedir el detalle.
- **Falta de audit log.** Sin trazas, no puedes investigar incidentes ni cumplir compliance.
- **No versionar.** Cambias la firma y rompes todos los prompts/caches/agents en vuelo.

## Resumen

- Las tools son **(nombre, descripción, schema, implementación)**; el LLM las elige leyendo la descripción.
- Apunta a **abstracción media**: operaciones de dominio componibles, no API raw ni macro-helpers rígidos.
- Diseña el **action space** separando read (libre), write bajo riesgo (rate-limited) y write alto riesgo (human-in-the-loop).
- Patrones de implementación obligatorios: **validation layer, idempotencia, errores estructurados con suggested_action, rate limiting y cost caps**.
- La **descripción es el 80% del trabajo**: incluye qué, cuándo, parámetros, retorno y ejemplos. El modelo elige leyendo esto.
- Seguridad: **permission system, input sanitization, audit log, sandboxing**. Nunca confíes en que el agente "no va a hacer eso".
- Versiona tools (`v1`, `v2`), deprécalas gradualmente, y expón el catálogo dinámicamente para que el agente siempre vea el estado real.
- Testea tres niveles: **unit (correctness), integration (sistemas reales) y agent-usability (¿el modelo las usa bien y recupera de errores?)**.
- Performance: **caching de reads, ejecución paralela de calls independientes, lazy loading de outputs grandes, timeouts por tool**.
- Herramientas estándar: **Anthropic tool_use + MCP, OpenAI function calling, LangChain @tool, LangGraph, LlamaIndex, CrewAI**.
