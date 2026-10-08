# Introducción al Model Context Protocol (MCP)

## ¿Qué es?

**Model Context Protocol (MCP)** es un **protocolo abierto** publicado por **Anthropic en noviembre de 2024** que estandariza la forma en que los modelos de lenguaje (y los agentes construidos sobre ellos) se conectan a **fuentes de datos** y **herramientas externas**. En lugar de que cada equipo escriba su propia integración ad hoc para GitHub, PostgreSQL, Slack o un sistema de tickets, MCP define un **lenguaje común** que servidores y clientes hablan entre sí.

La analogía oficial es la del **USB-C para IA**: un único conector físico/lógico que permite enchufar cualquier periférico (herramienta) a cualquier host (modelo). Antes de MCP cada aplicación LLM reinventaba la rueda; después de MCP un mismo servidor sirve a Claude Desktop, Cursor, Zed, VS Code, Cline, Continue y cualquier otro cliente compatible.

> **Definición formal:** MCP es un protocolo cliente/servidor basado en **JSON-RPC 2.0** que especifica tres primitivas (**tools**, **resources**, **prompts**), un mecanismo de **capability negotiation**, y varios **transports** (stdio, SSE, streamable HTTP) sobre los que viaja el intercambio de mensajes.

### ¿Por qué un nuevo protocolo?

Antes de MCP teníamos tres patrones principales para conectar un LLM al mundo exterior:

| Patrón | Año | Problema principal |
|---|---|---|
| **ChatGPT Plugins** | 2023 (deprecado 2024) | Propietario, atado a OpenAI, difícil de versionar |
| **Function calling** nativo | 2023+ | Específico de cada proveedor, cada herramienta se define a mano en el prompt |
| **Frameworks (LangChain, LlamaIndex)** | 2022+ | Integraciones hechas por la comunidad pero sin un protocolo común entre apps |

MCP no sustituye al function calling: lo **envuelve** y lo **estandariza** para que la misma herramienta pueda ser consumida por cualquier modelo o aplicación.

## ¿Por qué importa?

Imagina que construyes un **agente de code review**. Hoy necesitas conectarlo a GitHub (OAuth, paginación, rate limits), a un escáner de seguridad (API propietaria), a un servicio de cobertura de tests (otro SDK) y a Slack para notificar. Son cuatro integraciones custom, cada una con su propio ciclo de mantenimiento. Si mañana quieres añadir GitLab, repites el trabajo. Si otro equipo quiere reutilizar tu integración de GitHub, debe entender tu código concreto.

Este es el **problema de integración N×M**: `N` modelos (Claude, GPT, Gemini, Llama) multiplicados por `M` herramientas (GitHub, Slack, Postgres, Jira…) producen `N×M` integraciones distintas en el ecosistema. MCP lo convierte en `N+M`: cada modelo implementa un cliente MCP una vez, cada herramienta implementa un servidor MCP una vez.

### MCP vs. function calling vs. ChatGPT Plugins

| Dimensión | Function calling nativo | ChatGPT Plugins | **MCP** |
|---|---|---|---|
| Estándar | Propio de cada API (OpenAI, Anthropic, Google) | OpenAI, cerrado | Abierto, multi-vendor |
| Transport | HTTP del proveedor | HTTPS + OpenAPI | stdio, SSE, streamable HTTP |
| Descubrimiento de capacidades | Herramientas pasadas en cada request | `ai-plugin.json` + OpenAPI | `list_tools`, `list_resources`, `list_prompts` dinámicos |
| Primitivas | Solo tools | Solo endpoints HTTP | Tools, resources, prompts, sampling |
| Estado del proyecto | Vivo | **Deprecado** (abril 2024) | Vivo y creciendo (nov 2024+) |
| Mantiene quién | Cada proveedor | OpenAI (ya no) | Anthropic + comunidad |
| Lenguaje | JSON Schema | OpenAPI 3 | JSON-RPC 2.0 + JSON Schema |

El valor de MCP es la **portabilidad**: el mismo servidor de Postgres funciona hoy con Claude Desktop y mañana con Cursor sin tocar nada.

### Ecosistema actual

- **Servers oficiales de Anthropic:** `filesystem`, `github`, `gitlab`, `google-drive`, `postgres`, `sqlite`, `slack`, `brave-search`, `fetch`, `git`, `memory`, `puppeteer`, `everart`, `sentry`.
- **Servers de la comunidad:** cientos ya en GitHub (Linear, Notion, AWS, Cloudflare, Stripe, YouTube, etc.).
- **Clientes compatibles:** Claude Desktop, Claude Code, Cursor, Zed, Cline, Continue, Windsurf, LibreChat, Sourcegraph Cody.
- **SDKs oficiales:** Python (`mcp`), TypeScript (`@modelcontextprotocol/sdk`), Kotlin, Swift, C#.

## ¿Cómo funciona?

### Arquitectura host → client → server

```
┌───────────────────────────────────────────────────────────────┐
│  HOST (Claude Desktop, Claude Code, Cursor, tu app…)          │
│                                                               │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐          │
│  │ MCP Client  │   │ MCP Client  │   │ MCP Client  │          │
│  └──────┬──────┘   └──────┬──────┘   └──────┬──────┘          │
└─────────┼─────────────────┼─────────────────┼─────────────────┘
          │ stdio           │ SSE             │ streamable HTTP
┌─────────▼──────┐   ┌──────▼───────┐   ┌─────▼────────┐
│ Filesystem     │   │ GitHub       │   │ Postgres     │
│ MCP Server     │   │ MCP Server   │   │ MCP Server   │
└────────────────┘   └──────────────┘   └──────────────┘
```

- **Host:** la aplicación que el usuario ve (Claude Desktop, Claude Code, un IDE). Contiene al modelo y coordina múltiples clients.
- **Client:** un conector 1-a-1 con un server. El host puede tener muchos clients activos a la vez.
- **Server:** un proceso independiente que expone capacidades (tools, resources, prompts). Puede ser local (subproceso) o remoto (HTTP).

Esta separación es clave: el modelo nunca habla directamente con GitHub o Postgres, siempre pasa por el server. Esto permite **sandboxing**, **auditoría** y **control de permisos** centralizado.

### Las primitivas de MCP

MCP define cuatro primitivas que un server puede exponer:

| Primitiva | Qué es | Quién decide usarla | Ejemplo |
|---|---|---|---|
| **Tools** | Funciones ejecutables con efectos secundarios | El **modelo** (como function calling) | `create_issue`, `run_sql`, `send_slack_message` |
| **Resources** | Datos de solo lectura identificados por URI | La **aplicación** (host) carga y pasa al contexto | `file:///README.md`, `postgres://db/schema` |
| **Prompts** | Plantillas de interacción parametrizadas | El **usuario** las invoca (ej. slash commands) | `/security-review`, `/explain-schema` |
| **Sampling** | El server pide al host hacer una llamada al LLM | El **server** (inversión de control) | Un server que necesita resumir texto grande |

Esta separación es más rica que el simple "function calling". **Tools** son acciones; **resources** son contexto; **prompts** son flujos guiados. Un buen server de GitHub expone `get_pr_details` como tool, `github://repo/pulls/123/diff` como resource, y `/review-pr` como prompt.

### Transports

MCP viaja sobre tres transports estandarizados:

| Transport | Cuándo usarlo | Pros | Contras |
|---|---|---|---|
| **stdio** | Servers locales lanzados por el host (subproceso) | Simple, sin red, cero config | Solo local, un proceso por client |
| **SSE** (Server-Sent Events) | Servers remotos legacy | Streaming simple sobre HTTP | Marcado como legacy en spec reciente |
| **Streamable HTTP** | Servers remotos modernos (2025+) | Bidireccional, resumible, escalable | Más complejo de implementar |

En la práctica, el 90% de los servers oficiales que hoy ves en Claude Desktop usan **stdio**: el host arranca `npx -y @modelcontextprotocol/server-filesystem /ruta` como subproceso y habla con él por stdin/stdout.

### Ciclo de vida de una sesión MCP

```
1. INITIALIZE          client → server:  "hola, hablo MCP v2024-11-05"
                       server → client:  "yo también, soporto tools+resources"
2. CAPABILITY NEGOTIATE ambos acuerdan qué features usar
3. DISCOVERY           client llama list_tools, list_resources, list_prompts
4. OPERATION           loop: call_tool, read_resource, get_prompt...
5. SHUTDOWN             cierre limpio del transport
```

El paso de **capability negotiation** es importante: no todos los servers soportan todas las primitivas, y las versiones del protocolo evolucionan. Si cliente y servidor no se ponen de acuerdo en la versión, deben fallar explícitamente, no silenciosamente.

### Authentication

MCP **no define autenticación en el protocolo mismo**; delega al transport:

- **stdio:** confía en el proceso padre; se pasan credenciales por variables de entorno (`GITHUB_TOKEN=...`).
- **HTTP/SSE:** se usa el estándar HTTP (Bearer tokens, mTLS). Desde 2025, la spec recomienda **OAuth 2.1** para servers remotos públicos.

Es responsabilidad del host **almacenar secretos de forma segura** (Keychain en macOS, variables de entorno, secret managers) y nunca enviarlos como parámetros de tool.

## Ejemplo con código

### 1. Un server mínimo con el SDK de Python

```python
# server_hello.py
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("hello-server")

# Un tool: el modelo puede invocarlo
@mcp.tool()
def saludar(nombre: str) -> str:
    """Devuelve un saludo personalizado."""
    return f"¡Hola, {nombre}! Bienvenido a MCP."

# Un resource: el host lo carga como contexto
@mcp.resource("config://ejemplo")
def config_ejemplo() -> str:
    """Configuración de ejemplo expuesta como recurso."""
    return '{"version": "1.0", "entorno": "desarrollo"}'

if __name__ == "__main__":
    mcp.run()  # por defecto, transport = stdio
```

Para usarlo desde Claude Desktop, se añade al archivo de configuración (`~/Library/Application Support/Claude/claude_desktop_config.json` en macOS):

```json
{
  "mcpServers": {
    "hello": {
      "command": "python",
      "args": ["/ruta/absoluta/a/server_hello.py"]
    }
  }
}
```

### 2. Configurar un server oficial (filesystem) en Claude Desktop

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "/Users/yo/Documents",
        "/Users/yo/Proyectos"
      ]
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_xxxxxxxxxxxxxxxxxxxx"
      }
    }
  }
}
```

Tras reiniciar Claude Desktop, el modelo puede listar directorios, leer archivos, crear issues en GitHub, etc., sin que escribas una sola línea de código adicional.

### 3. Un client mínimo que lista y llama tools

```python
# client_demo.py
import asyncio
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def main():
    params = StdioServerParameters(
        command="python",
        args=["server_hello.py"],
    )

    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            # 1. Handshake + negociación de capacidades
            await session.initialize()

            # 2. Discovery
            tools = await session.list_tools()
            for t in tools.tools:
                print(f"- {t.name}: {t.description}")

            resources = await session.list_resources()
            for r in resources.resources:
                print(f"- recurso {r.uri}")

            # 3. Invocación de tool
            resultado = await session.call_tool("saludar", {"nombre": "Ana"})
            print("Resultado:", resultado.content[0].text)

            # 4. Lectura de resource
            cfg = await session.read_resource("config://ejemplo")
            print("Config:", cfg.contents[0].text)

if __name__ == "__main__":
    asyncio.run(main())
```

### 4. Instalación

```bash
# SDK de Python
pip install mcp

# SDK de TypeScript
npm install @modelcontextprotocol/sdk

# Server oficial de ejemplo
npx -y @modelcontextprotocol/server-filesystem ~/Documents

# CLI de debugging
npx -y @modelcontextprotocol/inspector python server_hello.py
```

El **MCP Inspector** es tu mejor amigo durante el desarrollo: abre una UI web donde puedes ver tools, invocarlos a mano y leer los logs del server.

## Errores comunes

- **Confundir MCP con un reemplazo de function calling.** MCP se apoya en function calling por debajo; no lo elimina. Es una capa de **estandarización y descubrimiento**, no una tecnología de inferencia.
- **No manejar el schema version mismatch.** Si tu client habla `2024-11-05` y el server `2025-03-26`, deben negociarlo en `initialize`. Ignorarlo produce errores silenciosos difíciles de depurar.
- **Exponer secretos como resources.** Un server que publica `secrets://api-keys/prod` como resource los filtra al contexto del modelo. Los secretos van en variables de entorno del proceso server, nunca como datos servidos.
- **Dar acceso de filesystem a `/` o `~`.** El server oficial de filesystem toma rutas permitidas como argumento (`npx ... /Users/yo/Proyectos`). Pasar `/` convierte al modelo en un `rm -rf` potencial.
- **Olvidar que los tools tienen efectos secundarios.** `delete_repo`, `send_email`, `run_sql` son irreversibles. Marca los destructivos y pide confirmación al usuario desde el host.
- **No implementar reinicio ante crash.** Un server que muere deja al host sin esa capacidad hasta reiniciar manualmente. Usa supervisores (systemd, pm2) o lógica de reconexión en el client.
- **Hard-codear rutas o credenciales en el server.** Usa `os.environ` y argumentos CLI. Facilita despliegues y testing.
- **Olvidar validar inputs de tools.** JSON Schema valida tipos pero no semántica. Si `pr_number` debe ser > 0, valídalo tú.
- **No usar el Inspector durante el desarrollo.** Depurar MCP sin verlo graficamente es doloroso. `npx @modelcontextprotocol/inspector` es gratis.
- **Asumir que todos los clientes soportan todas las primitivas.** Claude Desktop soporta tools, resources y prompts; otros clientes solo tools. Diseña tu server para degradarse si falta algo.

## Resumen

- **MCP** es un protocolo abierto de Anthropic (noviembre 2024) que estandariza la conexión entre LLMs y herramientas/datos externos, basado en **JSON-RPC 2.0**.
- Resuelve el problema **N×M** de integraciones: cada modelo implementa un client una vez, cada herramienta implementa un server una vez.
- Arquitectura **host → client → server**: el host (Claude Desktop, Cursor) coordina múltiples clients, cada uno conectado a un server independiente.
- Cuatro **primitivas**: tools (acciones), resources (datos de solo lectura), prompts (plantillas) y sampling (el server pide inferencia al host).
- Tres **transports**: stdio (local, lo más común), SSE (legacy), streamable HTTP (remoto moderno).
- Se compara favorablemente con **ChatGPT plugins** (deprecados) y es **complementario** al function calling nativo, al que envuelve con una capa de descubrimiento y portabilidad.
- Ecosistema vivo: decenas de servers oficiales (filesystem, github, postgres, slack…) y cientos de la comunidad.
- Herramientas clave: `mcp` (Python), `@modelcontextprotocol/sdk` (TS), **Claude Desktop**, **Claude Code**, **MCP Inspector**.
- La **autenticación** no está en el protocolo: viaja por el transport (env vars en stdio, OAuth 2.1 en HTTP remoto).
- Buenas prácticas: nunca exponer secretos como resources, limitar el scope del filesystem, validar inputs, planificar reinicios y usar el Inspector para depurar.
