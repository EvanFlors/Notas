# Construir un MCP Client

## ¿Qué es?

Un **MCP client** es el componente que, desde dentro del host (Claude Desktop, Claude Code, tu propia app con un LLM), establece y mantiene una **sesión 1-a-1 con un server**. Su trabajo es:

1. Abrir el transport (lanzar el subproceso stdio o conectar al HTTP endpoint).
2. Negociar capacidades con `initialize`.
3. Descubrir qué tools, resources y prompts expone el server.
4. Traducir esas capacidades al formato que el LLM espera (p. ej. `tool_calls` de la API de Anthropic u OpenAI).
5. Rutear invocaciones del modelo al server correcto, capturar errores y devolver resultados.

Si tu app conecta a varios servers, usas un **client manager**: un objeto que mantiene N sesiones y agrega las capacidades de todas en una sola lista de tools que presenta al modelo.

### Dónde vive el client

| Contexto | Quién implementa el client |
|---|---|
| Usas **Claude Desktop** | Ya está hecho; solo configuras `claude_desktop_config.json` |
| Usas **Claude Code** | Ya está hecho; configuras con `claude mcp add` |
| Construyes tu **propia app** con la API de Claude/GPT | Implementas el client con el SDK |

## ¿Por qué importa?

En producción, un agente serio no se conecta a un solo server. Un agente de code review necesita GitHub + escáner de seguridad + cobertura + Slack. Un agente de data analysis necesita Postgres + S3 + un vector store. Un agente de soporte necesita Zendesk + la base de conocimiento + Jira.

El **client manager** resuelve varios problemas duros a la vez:

- **Agregación:** una sola lista de tools para el LLM, aunque vengan de 5 servers distintos.
- **Ruteo:** cuando el modelo llama `scan_security`, el manager sabe que ese tool vive en el server `security`.
- **Resiliencia:** si un server se cae, el manager reconecta sin tumbar al agente completo.
- **Observabilidad:** registra qué tool llamó el modelo, en qué server, con qué latencia.

Un cliente bien hecho es la diferencia entre un demo bonito y un sistema que sobrevive un lunes por la mañana con tráfico real.

## ¿Cómo funciona?

### Ciclo de vida de la sesión

```
┌─ connect ───────────────────────────────────┐
│  1. abrir transport (stdio subprocess | HTTP)│
│  2. ClientSession(read, write)              │
│  3. await session.initialize()              │
└─────────────────────────────────────────────┘
            │
┌─ discovery ─────────────────────────────────┐
│  await session.list_tools()                 │
│  await session.list_resources()             │
│  await session.list_prompts()               │
└─────────────────────────────────────────────┘
            │
┌─ operation loop ────────────────────────────┐
│  while agente activo:                       │
│    - call_tool(name, args)                  │
│    - read_resource(uri)                     │
│    - get_prompt(name, args)                 │
└─────────────────────────────────────────────┘
            │
┌─ shutdown ──────────────────────────────────┐
│  cerrar context managers (SDK lo hace solo) │
└─────────────────────────────────────────────┘
```

### Traducción MCP → function calling

MCP define los tools con JSON Schema. Las APIs de los LLMs esperan tools en formatos propios (Anthropic, OpenAI, Gemini). El client traduce entre ambos:

```
MCP Tool                      Anthropic / OpenAI tool
─────────                     ───────────────────────
name:        "get_pr"      →  name:        "get_pr"
description: "..."         →  description: "..."
inputSchema: {...}         →  input_schema / parameters: {...}
```

La traducción suele ser 1-a-1; el único trabajo es renombrar `inputSchema` según el proveedor.

### Resiliencia

Las fallas típicas en producción:

| Falla | Síntoma | Mitigación |
|---|---|---|
| Server stdio crashea | Pipe cerrado | Reconectar (relanzar subproceso) |
| Server HTTP lento | Tool call cuelga | Timeout + cancelación |
| Rate limit API externa | Error estructurado del server | Backoff + reintento |
| Esquema de tool cambió | `validation_error` | Volver a hacer `list_tools` |

## Ejemplo con código

### Client manager completo

```python
# client_manager.py
import asyncio
import os
import json
from contextlib import AsyncExitStack
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

class MCPClientManager:
    def __init__(self):
        self.exit_stack = AsyncExitStack()
        self.sessions: dict[str, ClientSession] = {}
        self.tools: dict[str, dict] = {}  # tool_name -> {server, schema}

    async def connect_stdio(self, name: str, command: list[str], env: dict | None = None):
        params = StdioServerParameters(command=command[0], args=command[1:], env=env or {})
        read, write = await self.exit_stack.enter_async_context(stdio_client(params))
        session = await self.exit_stack.enter_async_context(ClientSession(read, write))
        await session.initialize()
        self.sessions[name] = session
        await self._discover(name, session)

    async def _discover(self, server_name: str, session: ClientSession):
        resp = await session.list_tools()
        for tool in resp.tools:
            if tool.name in self.tools:
                print(f"advertencia: tool duplicado {tool.name}; prevalece {server_name}")
            self.tools[tool.name] = {
                "server": server_name,
                "description": tool.description,
                "input_schema": tool.inputSchema,
            }

    def tools_for_anthropic(self) -> list[dict]:
        return [
            {
                "name": name,
                "description": meta["description"],
                "input_schema": meta["input_schema"],
            }
            for name, meta in self.tools.items()
        ]

    async def call(self, name: str, args: dict, timeout: float = 30.0) -> dict:
        if name not in self.tools:
            return {"ok": False, "error": f"tool desconocido: {name}"}
        server_name = self.tools[name]["server"]
        session = self.sessions[server_name]
        try:
            result = await asyncio.wait_for(session.call_tool(name, args), timeout=timeout)
            text = "".join(c.text for c in result.content if hasattr(c, "text"))
            return {"ok": True, "result": text, "server": server_name}
        except asyncio.TimeoutError:
            return {"ok": False, "error": "timeout", "server": server_name}
        except Exception as e:
            return {"ok": False, "error": str(e), "server": server_name}

    async def close(self):
        await self.exit_stack.aclose()
```

### Integración con la API de Anthropic

```python
# agent.py
import anthropic
from client_manager import MCPClientManager

async def run_agent(user_prompt: str):
    mcp = MCPClientManager()
    await mcp.connect_stdio(
        "github",
        ["npx", "-y", "@modelcontextprotocol/server-github"],
        env={"GITHUB_PERSONAL_ACCESS_TOKEN": os.environ["GITHUB_TOKEN"]},
    )
    await mcp.connect_stdio("filesystem",
        ["npx", "-y", "@modelcontextprotocol/server-filesystem", "/tmp/workdir"])

    client = anthropic.Anthropic()
    messages = [{"role": "user", "content": user_prompt}]
    tools = mcp.tools_for_anthropic()

    for _ in range(10):  # max 10 iteraciones
        resp = client.messages.create(
            model="claude-sonnet-4-5",
            max_tokens=4096,
            tools=tools,
            messages=messages,
        )

        if resp.stop_reason == "tool_use":
            # añadir la respuesta del asistente
            messages.append({"role": "assistant", "content": resp.content})
            tool_results = []
            for block in resp.content:
                if block.type == "tool_use":
                    out = await mcp.call(block.name, block.input)
                    tool_results.append({
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": json.dumps(out),
                    })
            messages.append({"role": "user", "content": tool_results})
        else:
            await mcp.close()
            return "".join(b.text for b in resp.content if b.type == "text")
```

### Reconexión con reintento

```python
async def call_with_retry(mgr: MCPClientManager, name: str, args: dict, retries: int = 3):
    for i in range(retries):
        result = await mgr.call(name, args)
        if result["ok"]:
            return result
        if "timeout" in result.get("error", "") or "connection" in result.get("error", ""):
            await asyncio.sleep(2 ** i)  # backoff exponencial
            continue
        return result  # error no transitorio: no reintentar
    return {"ok": False, "error": "max retries exceeded"}
```

### Configurar servers en Claude Code (sin escribir client)

```bash
# añadir el server de filesystem a Claude Code
claude mcp add filesystem npx -y @modelcontextprotocol/server-filesystem ~/Documents

# añadir el de GitHub con token
claude mcp add github --env GITHUB_PERSONAL_ACCESS_TOKEN=ghp_xxx \
  npx -y @modelcontextprotocol/server-github

# listar servers conectados
claude mcp list
```

En Claude Code, el client está integrado: tú solo declaras los servers y Claude ya puede llamarlos.

## Errores comunes

- **No manejar fallos en el discovery.** Si `list_tools` lanza excepción, tu agente arranca sin herramientas y empieza a alucinar. Loguea el fallo y degrada explícitamente.
- **Normalizar mal los errores entre servers.** Cada server devuelve errores con su propia forma. Normaliza a `{ok: bool, error: str, server: str}` en el manager; el agente no debería ver cuatro formatos distintos.
- **Operaciones bloqueantes en el loop.** `requests.get` dentro de un handler async congela todo. Usa `asyncio` y clientes async (`httpx`, `aiohttp`).
- **Olvidar qué server provee cada tool.** Cuando un tool falla necesitas saber dónde. Mantén el mapping `tool_name → server_name` siempre.
- **No usar timeouts.** Un server que cuelga 10 minutos consume el context de tu agente y bloquea al usuario. Aplica `asyncio.wait_for` siempre.
- **Reconectar en bucle sin backoff.** Si el server crashea por un bug, intentar reconectar 1000 veces por segundo lo empeora. Usa backoff exponencial y un máximo de intentos.
- **Pasar demasiados tools al LLM.** Más de 20-30 tools degrada la calidad de function calling. Filtra por categoría o deja que el usuario active/desactive servers.
- **No cerrar las sesiones.** Si no usas `AsyncExitStack` o `async with`, dejas subprocesos zombies y file descriptors abiertos.
- **Confiar en el orden de las respuestas.** Si llamas tools en paralelo con `asyncio.gather`, no asumas orden; usa `tool_use_id` para correlacionar.
- **No cachear `list_tools`.** Llamarlo en cada iteración añade latencia; hazlo una sola vez al conectar (y re-hacerlo si el server lo anuncia por `tools/list_changed`).

## Resumen

- Un **MCP client** mantiene una sesión 1-a-1 con un server: handshake, descubrimiento, invocación y shutdown.
- Un **client manager** agrega capacidades de múltiples servers, presenta una lista unificada de tools al LLM y rutea cada llamada al server correcto.
- Si usas **Claude Desktop** o **Claude Code** no necesitas escribir client: configuras `claude_desktop_config.json` o `claude mcp add` y listo.
- Para apps propias usas el SDK (`mcp.ClientSession` + `stdio_client` o `streamablehttp_client`).
- El client traduce **MCP tools → function calling** del proveedor (Anthropic, OpenAI, Gemini) renombrando `inputSchema`.
- **Resiliencia obligatoria**: timeouts, reintentos con backoff, reconexión, errores normalizados, degradación cuando un server se cae.
- Usa `asyncio.gather` para llamadas paralelas independientes; usa `AsyncExitStack` para cerrar sesiones limpiamente.
- No pases 50 tools al modelo: filtra por tarea; más tools no es mejor function calling.
- Observa latencia por server y por tool; ese dato guía decisiones de optimización reales en producción.
