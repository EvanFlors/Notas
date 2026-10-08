# Quiz: Model Context Protocol (MCP)

> **Contexto:** Tu equipo ha construido integraciones custom para GitHub, escáneres de seguridad y servicios de cobertura para su agente de code review. Cada integración ha tomado semanas construir y mantener. Ahora quieren añadir soporte para GitLab, cambiar de escáner de seguridad y compartir herramientas con otros equipos. Deciden estandarizar sobre **MCP** para eliminar duplicación e interoperar entre agentes.

---

### 1. ¿Qué problema resuelve el Model Context Protocol (MCP) en el desarrollo de agentes?

- MCP hace los agentes más rápidos reduciendo la latencia de las llamadas a API.
- **MCP provee un protocolo universal para conectar agentes a herramientas y fuentes de datos, eliminando la necesidad de escribir integraciones custom para cada herramienta.** ✅
- MCP reemplaza los modelos de lenguaje por motores de razonamiento más eficientes.
- MCP simplifica el prompt engineering para los agentes.

**Explicación:** MCP es un protocolo abierto publicado por Anthropic en noviembre de 2024 que convierte el problema **N×M** (N modelos por M herramientas) en **N+M**. Cada modelo implementa un client una vez, cada herramienta implementa un server una vez, y gracias al estándar común ambos interoperan sin código ad hoc. No cambia el modelo ni mejora la latencia por sí mismo; su valor es la **estandarización e interoperabilidad**.

---

### 2. En la arquitectura MCP, ¿cuál es el rol del server frente al rol del client?

- Los servers consumen capacidades y los clients las exponen.
- **Los servers exponen capacidades (tools y resources) a los agentes; los clients se conectan a los servers y presentan esas capacidades al agente.** ✅
- Server y client son términos intercambiables para el mismo componente.
- Los servers hacen la inferencia del LLM y los clients ejecutan los tools.

**Explicación:** El patrón es **host → client → server**. El **server** es un proceso independiente (local vía stdio o remoto vía HTTP) que publica tools, resources y prompts. El **client** vive dentro del host (Claude Desktop, Claude Code, tu app) y mantiene una sesión 1-a-1 con un server, encargándose del handshake, discovery, invocación y manejo de errores.

---

### 3. ¿Cuál es la diferencia entre tools y resources en MCP?

- Los tools son solo lectura y los resources solo escritura.
- **Los tools son funciones que el agente invoca para realizar acciones; los resources son fuentes de datos de solo lectura que el agente puede leer y referenciar.** ✅
- Los tools los proveen los clients y los resources los proveen los servers.
- No hay diferencia; son el mismo concepto con nombres distintos.

**Explicación:** Los **tools** son acciones con potenciales efectos secundarios (`post_comment`, `delete_file`, `send_message`) y es el **modelo** quien decide invocarlos durante el razonamiento. Los **resources** son datos identificados por URI (`file:///README.md`, `github://repo/pulls/123/diff`) que el **host o el usuario** adjunta al contexto. Esta distinción permite diseños más seguros: lo que es solo contexto no se mezcla con lo que es acción.

---

### 4. Al construir un MCP server, ¿qué debe devolver un tool handler?

- Un diccionario Python crudo con los datos del resultado.
- **Una lista de objetos TextContent con el resultado estructurado, típicamente serializado como JSON.** ✅
- Un string directo con el resultado.
- Nada; los tool handlers modifican estado global en vez de devolver valores.

**Explicación:** El protocolo MCP exige que la respuesta de un tool sea una lista de **content parts** (texto, imagen, embedded resource). Lo más común es devolver `[TextContent(type="text", text=json.dumps({...}))]`. Serializar como JSON permite que el modelo parsee resultados estructurados con fiabilidad. El SDK `FastMCP` oculta parte de este boilerplate aceptando un `str` o `dict` como retorno y empaquetándolo automáticamente.

---

### 5. ¿Por qué ayuda el patrón de **client manager** al conectar con múltiples servers especializados?

- Reduce las llamadas a API agrupándolas en batches.
- **Agrega las capacidades de múltiples servers y presenta una interfaz unificada, permitiendo que el agente use tools de distintos servers sin saber cuál las provee.** ✅
- Reintenta automáticamente los tool calls fallidos entre distintos servers.
- Cachea resultados de tools para mejorar el rendimiento.

**Explicación:** El manager mantiene N sesiones abiertas y construye una tabla `tool_name → server_name`. Cuando el modelo invoca `scan_security`, el manager sabe que ese tool vive en el server `security` y rutea la llamada. Esto desacopla al agente de la topología de servers: puedes añadir, mover o quitar servers sin tocar el system prompt del agente.

---

### 6. Al cambiar de una integración custom de GitHub a un GitHub MCP server, ¿cuál es el principal beneficio para el código del agente?

- El código del agente se vuelve más rápido porque MCP es más eficiente que las integraciones custom.
- **El código del agente no necesita cambiar; usa la misma interfaz de client MCP para conectarse a cualquier server compatible, lo que facilita cambiar herramientas o añadir capacidades.** ✅
- El código del agente se simplifica porque MCP elimina la necesidad de manejo de errores.
- El código del agente puede usar múltiples modelos de lenguaje simultáneamente.

**Explicación:** La **portabilidad** es el núcleo del valor de MCP. Hoy conectas al server oficial `@modelcontextprotocol/server-github`; mañana a uno de GitLab, Gitea o Bitbucket; el agente sigue viendo tools genéricos de "VCS" y sigue funcionando. MCP no elimina el manejo de errores (sigues necesitando reintentos y timeouts) ni habilita multi-LLM por arte de magia; su beneficio real es el **intercambio sin coste** de piezas.

---

### 7. ¿Cómo descubre un MCP client qué tools y resources ofrece un server?

- El client lee un archivo de configuración que lista todos los tools disponibles.
- **El client interroga al server usando métodos del protocolo MCP (como list_tools) para descubrir capacidades dinámicamente al momento de la conexión.** ✅
- El client debe registrar manualmente cada tool antes de conectarse.
- El server empuja la lista de tools al client cuando arranca.

**Explicación:** Tras el `initialize` y la **capability negotiation**, el client invoca `list_tools`, `list_resources` y `list_prompts`. Las respuestas incluyen nombres, descripciones y JSON Schemas. Esto hace que las capacidades sean **dinámicas**: un server puede añadir o quitar tools entre versiones sin que los clients necesiten cambios de código. Además, los servers pueden notificar cambios en caliente con `tools/list_changed`, y los clients bien hechos re-descubren.
