# Sistema MCP de extremo a extremo

## ¿Qué es?

Esta lesson une todo lo anterior en un **sistema completo de producción**: un agente de code review que utiliza múltiples MCP servers especializados a través de un client manager unificado. Es un patrón arquitectónico aplicable mucho más allá del code review: data analysis, soporte, DevOps, operaciones de negocio.

La arquitectura general es:

```
┌───────────────────────────────────────────────────────────┐
│  HOST: Agent de code review (LLM: Claude Sonnet)          │
│  ┌─────────────────────────────────────────────────────┐  │
│  │          MCP Client Manager (routing)               │  │
│  └──┬──────────┬──────────┬──────────┬────────────────┘  │
└─────┼──────────┼──────────┼──────────┼───────────────────┘
      │          │          │          │
┌─────▼──┐  ┌────▼───┐  ┌───▼────┐  ┌──▼──────┐
│ GitHub │  │Security│  │Coverage│  │  Slack  │
│ server │  │scanner │  │ server │  │  server │
└────────┘  └────────┘  └────────┘  └─────────┘
```

Cada server es **independiente** (código, despliegue, escalado), el client manager **agrega** sus capacidades, y el agente **orquesta** sin saber qué server provee cada tool.

### Qué veremos

- Diseño modular por dominio (un server = una responsabilidad).
- Configuración declarativa con YAML + variables de entorno.
- Loop del agente con reintentos, timeouts y degradación.
- Observabilidad: logs estructurados, métricas, tracing.
- Consideraciones de seguridad en producción.

## ¿Por qué importa?

Un agente que llama una sola API es un juguete. Un agente de producción:

- Combina **múltiples fuentes** (código + CI + métricas + canal humano).
- Debe seguir funcionando **cuando algo falla** (si Slack cae, el review no se cancela).
- Se **actualiza por partes** (cambiar el escáner de seguridad no debe tocar el agente).
- Es **auditable**: hay que saber qué tool se llamó, con qué args, qué respondió.
- Es **testeable**: cada server se prueba aislado, el agente se prueba con servers mock.

MCP convierte estos requisitos en algo tratable. Sin MCP, cada equipo escribe su propio marco de integración de herramientas y acaba replicando lo mismo. Con MCP, obtienes servers reutilizables, un patrón de client probado y un ecosistema creciente de piezas intercambiables.

## ¿Cómo funciona?

### 1. Separación de responsabilidades

| Server | Responsabilidad única | Tools típicos |
|---|---|---|
| **github** | Repos, PRs, issues, comentarios | `get_pr_details`, `get_file_content`, `post_review` |
| **security** | Escaneo estático y SCA | `scan_code_security`, `check_dependencies` |
| **coverage** | Cobertura de tests | `get_coverage`, `find_untested_code` |
| **slack** | Notificaciones | `send_message`, `create_thread` |

Esta separación permite:

- Equipos distintos mantienen servers distintos.
- Fallos aislados (si `security` cae, el agente sigue con los otros tres).
- Escalado independiente (si `security` consume CPU, se escala solo él).
- Testeo individual (mocks por server).

### 2. Configuración declarativa

Toda la configuración del sistema vive fuera del código:

```yaml
# review_system.yaml
servers:
  github:
    command: ["npx", "-y", "@modelcontextprotocol/server-github"]
    env:
      GITHUB_PERSONAL_ACCESS_TOKEN: ${GITHUB_TOKEN}
  security:
    command: ["python", "servers/security_server.py"]
    env:
      SCANNER_API_KEY: ${SCANNER_API_KEY}
  coverage:
    command: ["python", "servers/coverage_server.py"]
  slack:
    command: ["python", "servers/slack_server.py"]
    env:
      SLACK_BOT_TOKEN: ${SLACK_BOT_TOKEN}
    optional: true   # si falla, el agente sigue sin él

agent:
  model: claude-sonnet-4-5
  max_iterations: 15
  timeout_seconds: 300
  required_tools:
    - get_pr_details    # sin esto, no hay review
```

### 3. Orquestación

El agente sigue el patrón ReAct (razonar → actuar → observar), pero las acciones son tool calls MCP:

```
┌──────────────────────────────────────────────┐
│  Usuario: "revisa PR #1247 de company/api"   │
└─────────────────────┬────────────────────────┘
                      ▼
      ┌─────────────────────────────┐
      │  LLM piensa + decide tools  │
      └─────────────┬───────────────┘
                    ▼
      ┌─────────────────────────────┐
      │  MCP manager rutea al server│
      └─────────────┬───────────────┘
                    ▼
      ┌─────────────────────────────┐
      │  Server ejecuta, devuelve   │
      └─────────────┬───────────────┘
                    ▼
    (loop hasta que el LLM responda sin tool_calls)
```

### 4. Degradación controlada

Un server marcado como `optional: true` puede fallar sin tumbar el sistema. El manager omite sus tools de la lista presentada al LLM, de modo que el modelo ni siquiera intenta usarlos.

## Ejemplo con código

### Construcción del sistema desde YAML

```python
# review_system.py
import os
import yaml
import asyncio
import json
import logging
from datetime import datetime
import anthropic
from client_manager import MCPClientManager  # del lesson 03

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("review-system")

def expand_env(value: str) -> str:
    """Expande ${VAR} desde el entorno."""
    if isinstance(value, str) and value.startswith("${") and value.endswith("}"):
        return os.environ.get(value[2:-1], "")
    return value

async def build_system(config_path: str):
    with open(config_path) as f:
        config = yaml.safe_load(f)

    mgr = MCPClientManager()
    for name, s_cfg in config["servers"].items():
        env = {k: expand_env(v) for k, v in s_cfg.get("env", {}).items()}
        try:
            await mgr.connect_stdio(name, s_cfg["command"], env=env)
            log.info("conectado server=%s", name)
        except Exception as e:
            if s_cfg.get("optional"):
                log.warning("server opcional %s falló: %s", name, e)
            else:
                raise

    # chequeo de tools requeridos
    required = set(config["agent"].get("required_tools", []))
    missing = required - set(mgr.tools.keys())
    if missing:
        raise RuntimeError(f"faltan tools requeridos: {missing}")

    return mgr, config["agent"]
```

### Agente completo

```python
class CodeReviewAgent:
    SYSTEM = (
        "Eres un revisor de código senior. Para cada PR:\n"
        "1. Obtén los detalles con get_pr_details.\n"
        "2. Lee cada archivo cambiado.\n"
        "3. Escanea con las tools de seguridad y cobertura disponibles.\n"
        "4. Publica un review (post_review) con hallazgos accionables.\n"
        "5. Notifica al autor si hay cambios críticos."
    )

    def __init__(self, mgr: MCPClientManager, cfg: dict):
        self.mgr = mgr
        self.cfg = cfg
        self.llm = anthropic.Anthropic()

    async def review(self, owner: str, repo: str, pr_number: int):
        start = datetime.now()
        messages = [{"role": "user",
                     "content": f"Revisa PR #{pr_number} en {owner}/{repo}"}]
        tools = self.mgr.tools_for_anthropic()
        tools_used = []

        for i in range(self.cfg.get("max_iterations", 15)):
            resp = self.llm.messages.create(
                model=self.cfg["model"],
                max_tokens=4096,
                system=self.SYSTEM,
                tools=tools,
                messages=messages,
            )

            if resp.stop_reason != "tool_use":
                summary = "".join(b.text for b in resp.content if b.type == "text")
                duration = (datetime.now() - start).total_seconds()
                log.info("review ok duration=%.1fs iter=%d tools=%s",
                         duration, i, tools_used)
                return {"ok": True, "review": summary,
                        "iterations": i, "tools_used": tools_used}

            messages.append({"role": "assistant", "content": resp.content})
            results = []
            for block in resp.content:
                if block.type == "tool_use":
                    tools_used.append(block.name)
                    out = await self.mgr.call(block.name, block.input, timeout=30)
                    results.append({"type": "tool_result",
                                    "tool_use_id": block.id,
                                    "content": json.dumps(out),
                                    "is_error": not out.get("ok")})
            messages.append({"role": "user", "content": results})

        log.error("review excedió max_iterations")
        return {"ok": False, "error": "max_iterations_exceeded"}
```

### Punto de entrada

```python
async def main():
    mgr, agent_cfg = await build_system("review_system.yaml")
    agent = CodeReviewAgent(mgr, agent_cfg)
    try:
        result = await agent.review("company", "backend-api", 1247)
        print(json.dumps(result, indent=2))
    finally:
        await mgr.close()

if __name__ == "__main__":
    asyncio.run(main())
```

### Flujo típico de un review

```
1. get_pr_details(owner="company", repo="backend-api", pr_number=1247)
   → PR añade OAuth, cambia 5 archivos en auth/

2. get_file_content(path="auth/oauth.py") × 5
   → contenidos de los archivos

3. scan_code_security(files=[...])
   → 1 crítico (secret hard-codeado), 2 medios

4. get_coverage(path="auth/")
   → 67%, faltan tests para error handling

5. post_review(pr_number=1247, event="REQUEST_CHANGES", body="""
   Hallazgos:
   - CRÍTICO: secret hard-codeado en auth/oauth.py L45
   - MEDIO: validación de input faltante en auth/tokens.py
   Cobertura 67% < umbral 80%. Añadir tests para:
   - manejo de errores OAuth
   - expiración de token
   """)

6. send_message(channel="#backend", text="Review publicado en PR #1247")
```

### Consideraciones de producción

- **Observabilidad:** loguea en JSON (`structlog`), emite métricas (duración por tool, errores por server) a Prometheus/Datadog, correlaciona con `trace_id`.
- **Escalado:** varios workers consumiendo una cola (Redis/SQS); cada worker tiene su propio `MCPClientManager`.
- **Secretos:** nunca en código; usa Vault, AWS Secrets Manager, variables de entorno gestionadas.
- **Allowlist:** valida que `owner`/`repo` estén en una lista permitida antes de operar.
- **Resumen de tool outputs:** si un tool devuelve 500 KB, resume antes de pasar al modelo o guarda en resource y referencia por URI.

## Errores comunes

- **Acoplar el agente a nombres de tools específicos.** Si tu system prompt dice "siempre llama get_pr_details_v2", migrar servers rompe todo. Deja que el modelo descubra las tools por sus `description`.
- **No probar escenarios de fallo.** En desarrollo todo está UP; en producción Slack rate-limita, GitHub devuelve 503 y el escáner cuelga. Simula estos fallos con mocks.
- **Saturar el contexto con resultados gigantes.** Un diff de 3000 líneas o un reporte de seguridad de 10 MB consume el context window. Resume o pagina.
- **Ignorar el costo.** Cada iteración del loop es una llamada al LLM con todos los tools serializados. Vigila tokens de entrada y salida; optimiza descripciones de tools (menos ejemplos redundantes).
- **No distinguir fallos transitorios de permanentes.** `timeout` reintenta; `tool desconocido` no. Clasifica errores en el manager.
- **Loguear secretos.** Si tus logs incluyen `arguments` crudos y un tool recibe un token, acabas con credenciales en Splunk. Filtra campos sensibles antes de loguear.
- **Olvidar `required_tools`.** Un agente que arranca sin su tool principal "funciona" alucinando. Chequea presencia tras conectar.
- **No versionar la config.** `review_system.yaml` cambia; versiónalo en Git como cualquier código.
- **Mezclar entornos.** Un server de GitHub conectado a producción desde un entorno de desarrollo puede causar daño real (cerrar PRs, borrar branches). Usa cuentas y tokens separados por entorno.
- **Max iterations demasiado alto sin circuit breaker.** 50 iteraciones con un loop infinito del modelo = factura inesperada. Combina `max_iterations` con un presupuesto de tokens.

## Resumen

- Un sistema MCP de producción compone **múltiples servers especializados** (uno por dominio) tras un **client manager** y un **agente orquestador**.
- La **separación por dominios** permite desarrollo, despliegue y escalado independientes de cada server.
- La **configuración declarativa** (YAML + env) saca servers, credenciales y modelo del código y facilita rotar o deshabilitar piezas.
- El **agente nunca sabe** qué server implementa qué tool; el manager rutea transparentemente.
- La **degradación controlada** (servers opcionales) hace al sistema resistente a fallos parciales.
- **Observabilidad** (logs estructurados, métricas, tracing) y **seguridad** (secretos externos, allowlists, aislamiento por entorno) son requisitos, no extras.
- **Resumir outputs grandes** antes de pasarlos al LLM mantiene el context manejable y el costo controlado.
- Testea **escenarios de fallo** y limita `max_iterations` + presupuesto de tokens para evitar runaway costs.
- Con MCP, mover un sistema entre proveedores (`claude-sonnet-4-5` → `gpt-5` → `gemini-2.5-pro`) requiere cambiar el cliente LLM; **los servers son los mismos**.
- Dominas MCP cuando puedes articular por qué tal tool va en un server u otro, cuándo degradar, cómo observar y qué romper deliberadamente para probar.
