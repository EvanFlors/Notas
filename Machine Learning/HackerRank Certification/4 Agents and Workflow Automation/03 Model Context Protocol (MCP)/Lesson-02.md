# Construir un MCP Server

## ¿Qué es?

Un **MCP server** es un proceso independiente que **expone capacidades** (tools, resources y/o prompts) a cualquier MCP client que se conecte, siguiendo las reglas del protocolo. En términos prácticos es la traducción de "tu API/base de datos/herramienta interna" al **idioma común de MCP**, para que Claude Desktop, Claude Code, Cursor u otro host puedan usarla sin saber nada de su API original.

Un server puede ser tan simple como 10 líneas de Python (un único tool que suma dos números) o tan complejo como el server oficial de GitHub que expone decenas de operaciones sobre repos, PRs e issues.

### Server stdio vs. server HTTP

| Tipo | Cuándo | Despliegue |
|---|---|---|
| **stdio** | Herramientas locales (filesystem, git, scripts) | El host lanza el proceso como subproceso |
| **SSE** | Legacy remoto | Un endpoint HTTP de larga duración |
| **Streamable HTTP** | Remoto moderno, multi-tenant | Server HTTP escalable (uvicorn, nginx, k8s) |

En este lesson construimos primero un server stdio con `FastMCP` (el helper de alto nivel del SDK) y después mostramos el equivalente HTTP.

## ¿Por qué importa?

Escribir un buen server es más valioso que escribir un buen cliente, porque **un server lo usan N clientes**. Cada vez que publicas un server para tu base de datos interna, tu CRM o tu wiki, cualquier agente MCP de tu organización puede consumirlo sin reinventar la integración.

Los servers oficiales (filesystem, github, postgres, slack…) cubren lo genérico. **Lo que da ventaja competitiva a tu empresa son los servers de tus sistemas internos**: tu Jira configurado a tu modo, tu lago de datos, tu plataforma de observabilidad. Ese es el trabajo que ningún open source hará por ti.

Buen diseño del server también importa por razones de seguridad: el server es el **punto de control**. Es donde decides qué puede hacer el modelo, qué datos ve y qué no, qué operaciones requieren confirmación. Un server mal diseñado es un vector de abuso directo.

## ¿Cómo funciona?

### Estructura general de un server

Todo server MCP sigue este esqueleto:

```
1. Importar el SDK y crear instancia (nombre + versión)
2. Registrar handlers para cada primitiva:
     - list_tools / call_tool
     - list_resources / read_resource
     - list_prompts / get_prompt
3. Elegir transport (stdio por defecto)
4. Ejecutar
```

El SDK ofrece dos APIs:

- **Low-level `Server`**: control total, decoradores para cada handler. Útil para casos avanzados.
- **High-level `FastMCP`**: inspirado en FastAPI, usa decoradores declarativos y deduce el JSON Schema del type-hint. Es lo recomendado para empezar.

### Flujo de una llamada a tool

```
Client                                  Server
  │  initialize ───────────────────────▶ │
  │  ◀─────────────── capabilities      │
  │  list_tools ───────────────────────▶ │
  │  ◀─────────── [tool metadata]       │
  │                                     │
  │  call_tool("get_pr", {...}) ───────▶ │
  │                                     │  (ejecuta lógica, llama API,
  │                                     │   maneja errores)
  │  ◀───────────── TextContent         │
```

Cada tool devuelve una lista de **content parts** (texto, imagen, embedded resource). El modelo recibe esto como salida de la función y decide el siguiente paso.

### Resources vs. Tools: cuándo usar cuál

| Pregunta | Si "sí" → úsalo como |
|---|---|
| ¿Tiene efectos secundarios (escribe, borra, envía)? | **Tool** |
| ¿Es solo lectura y el usuario puede "adjuntarlo" al contexto? | **Resource** |
| ¿El modelo elige cuándo usarlo según el prompt del usuario? | **Tool** |
| ¿Lo precarga el host al abrir una sesión? | **Resource** |

Un server bien diseñado suele ofrecer ambos: `read_file` como tool para que el modelo lea archivos sobre la marcha, y `file:///ruta/README.md` como resource para que el usuario lo adjunte manualmente a la conversación.

### Prompts

Los prompts son **plantillas parametrizadas** que el usuario invoca (en Claude Desktop aparecen como slash commands del server). Son útiles para empaquetar flujos repetitivos:

- `/security_review pr_number=1247` → arma un mensaje largo con instrucciones de auditoría.
- `/explain_schema table=users` → consulta el esquema y pide al modelo documentarlo.

## Ejemplo con código

### Server completo con `FastMCP` (tools + resources + prompts)

```python
# github_server.py
from mcp.server.fastmcp import FastMCP
from mcp.types import TextContent
from github import Github, GithubException
import os
import json

mcp = FastMCP("github-code-review", version="0.1.0")
gh = Github(os.environ["GITHUB_TOKEN"])

# ---------- TOOLS ----------

@mcp.tool()
def get_pr_details(owner: str, repo: str, pr_number: int) -> str:
    """Devuelve detalles de un Pull Request (título, autor, archivos modificados)."""
    if pr_number < 1:
        return json.dumps({"error": "pr_number debe ser positivo"})
    try:
        pr = gh.get_repo(f"{owner}/{repo}").get_pull(pr_number)
        return json.dumps({
            "number": pr.number,
            "title": pr.title,
            "author": pr.user.login,
            "state": pr.state,
            "files": [f.filename for f in pr.get_files()],
        })
    except GithubException as e:
        return json.dumps({"error": "github_error", "status": e.status, "message": str(e)})

@mcp.tool()
def post_comment(owner: str, repo: str, pr_number: int, body: str) -> str:
    """Publica un comentario en un PR. Operación con efecto secundario."""
    try:
        pr = gh.get_repo(f"{owner}/{repo}").get_pull(pr_number)
        comment = pr.create_issue_comment(body)
        return json.dumps({"ok": True, "id": comment.id, "url": comment.html_url})
    except GithubException as e:
        return json.dumps({"error": "github_error", "message": str(e)})

# ---------- RESOURCES ----------

@mcp.resource("github://{owner}/{repo}/pulls/{pr_number}/diff")
def pr_diff(owner: str, repo: str, pr_number: str) -> str:
    """Diff completo del PR como texto plano."""
    pr = gh.get_repo(f"{owner}/{repo}").get_pull(int(pr_number))
    return pr.diff_url  # en producción, descargar el contenido real

# ---------- PROMPTS ----------

@mcp.prompt()
def security_review(owner: str, repo: str, pr_number: int) -> str:
    """Plantilla de revisión de seguridad para un PR."""
    return (
        f"Revisa el PR #{pr_number} de {owner}/{repo} con foco en seguridad.\n\n"
        "Analiza:\n"
        "1. Validación y sanitización de inputs\n"
        "2. Auth y control de acceso\n"
        "3. SQL injection\n"
        "4. XSS\n"
        "5. Fuga de secretos\n\n"
        "Usa las tools disponibles para leer el diff y publica un comentario con los hallazgos."
    )

if __name__ == "__main__":
    mcp.run()  # stdio por defecto
```

### Despliegue remoto con streamable HTTP

```python
# server_http.py
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("remote-server")

@mcp.tool()
def ping() -> str:
    return "pong"

if __name__ == "__main__":
    # transport HTTP, útil para desplegar en un contenedor
    mcp.run(transport="streamable-http", host="0.0.0.0", port=8080)
```

Luego, desde el cliente:

```python
from mcp.client.streamable_http import streamablehttp_client

async with streamablehttp_client("http://localhost:8080/mcp") as (r, w, _):
    async with ClientSession(r, w) as s:
        await s.initialize()
        print(await s.call_tool("ping", {}))
```

### Low-level API (control total)

Si necesitas control fino, usa el `Server` de bajo nivel:

```python
from mcp.server import Server
from mcp.types import Tool, TextContent
import asyncio, json
from mcp.server.stdio import stdio_server

server = Server("low-level-example")

@server.list_tools()
async def list_tools():
    return [Tool(
        name="suma",
        description="Suma dos enteros",
        inputSchema={
            "type": "object",
            "properties": {"a": {"type": "integer"}, "b": {"type": "integer"}},
            "required": ["a", "b"],
        },
    )]

@server.call_tool()
async def call_tool(name: str, arguments: dict):
    if name == "suma":
        return [TextContent(type="text", text=json.dumps({"resultado": arguments["a"] + arguments["b"]}))]
    return [TextContent(type="text", text=json.dumps({"error": f"tool desconocido: {name}"}))]

async def main():
    async with stdio_server() as (r, w):
        await server.run(r, w, server.create_initialization_options())

if __name__ == "__main__":
    asyncio.run(main())
```

### Debug con el Inspector

```bash
npx -y @modelcontextprotocol/inspector python github_server.py
```

Abre `http://localhost:5173` donde puedes:

- Ver la lista de tools, resources y prompts.
- Invocar un tool manualmente con un formulario.
- Leer logs y payloads JSON-RPC en bruto.
- Verificar la negociación de capacidades.

## Errores comunes

- **No validar inputs antes de llamar APIs externas.** JSON Schema valida tipos pero no reglas de negocio. Si `pr_number` debe ser positivo, chequéalo tú. Un modelo alucinado puede pasarte `-1` o `0`.
- **Mensajes de error inútiles.** `"error occurred"` no sirve. Devuelve `{error: "rate_limit", message: "...", retry_after: 60}` para que el modelo pueda razonar sobre el fallo.
- **Operaciones bloqueantes en un server async.** Usar `requests.get(...)` en vez de `httpx.AsyncClient` congela el server mientras la API responde, bloqueando otros tools.
- **Hard-codear credenciales en el código.** Lee de `os.environ["GITHUB_TOKEN"]`. Nunca commits `token = "ghp_..."`.
- **No limitar el scope.** Un server de filesystem que recibe `/` como ruta base permite al modelo leer `/etc/shadow`. Pasa rutas explícitas y valídalas en cada llamada.
- **Exponer secretos como resources.** `secrets://api-keys/prod` filtra credenciales al contexto. Los secretos nunca viajan como datos servidos.
- **Olvidar manejar crashes.** Si el server muere, el host lo pierde hasta reiniciar. Usa un supervisor (systemd, pm2) o lógica de restart en el client.
- **No versionar el server.** Cuando cambia el schema de un tool, los clientes antiguos rompen. Declara `version="0.2.0"` y considera deprecaciones.
- **Devolver resultados gigantescos.** Si tu tool devuelve 2 MB de JSON, saturas el contexto del modelo. Paginar o resumir antes de responder.
- **No etiquetar tools destructivos.** `delete_repo` debería tener en su `description` que es irreversible, para que el host pueda pedir confirmación al usuario.

## Resumen

- Un **MCP server** traduce una capacidad interna (API, base de datos, servicio) al protocolo común de MCP para que cualquier client la consuma.
- Dos APIs en el SDK: **`FastMCP`** (decoradores declarativos, deduce schemas) para la mayoría de casos; **`Server`** low-level cuando necesitas control total.
- Expone cuatro primitivas: **tools** (acciones con side effects), **resources** (datos de solo lectura por URI), **prompts** (plantillas) y **sampling** (poco común).
- Transports: **stdio** para herramientas locales lanzadas como subproceso, **streamable HTTP** para despliegues remotos escalables.
- Diseño: tools para acciones, resources para contexto adjuntable, prompts para flujos repetitivos empaquetados como slash commands.
- Buenas prácticas: validar inputs, errores estructurados, código async, credenciales por env, scope mínimo, versionado explícito.
- Debug con **MCP Inspector** (`npx @modelcontextprotocol/inspector`); nunca intentes depurar MCP solo con prints.
- El server es el **punto de control de seguridad**: lo que no expongas, el modelo no lo verá. Diseña con el principio de menor privilegio.
