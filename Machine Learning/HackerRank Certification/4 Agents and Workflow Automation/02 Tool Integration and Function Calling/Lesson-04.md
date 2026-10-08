# Juntándolo todo: un Code Review Agent de punta a punta

## ¿Qué es?

Hasta aquí vimos las piezas por separado: **function calling** (Lesson-01), **schemas** (Lesson-02) y **capa de ejecución** (Lesson-03). Esta lección los combina en un **sistema real**: un **agente de code review** que lee un pull request, analiza seguridad, verifica cobertura de tests, revisa estilo y publica un comentario con el veredicto.

No es un ejemplo de juguete. Reproduce patrones de producción:

- Schemas coherentes como un **tool set** que se complementa.
- Executor con **validación**, **retry** y **async**.
- **Composición de tools** (una tool consume el output de otra).
- **Loop de orquestación** donde el LLM decide la secuencia.
- **Graceful degradation** ante APIs caídas.

![Arquitectura completa del code review agent](https://hrcdn.net/ai-engineering/module-4/dark/tool-integration-lesson04-architecture.svg)

## ¿Por qué importa?

Casi todos los tutoriales terminan en "aquí tienes `get_weather`". Pero un **agente real** tiene 5-15 tools, debe manejar errores entre ellas, componer sus resultados y producir una respuesta final que un humano pueda accionar.

Ver el sistema completo expone trade-offs invisibles en ejemplos aislados:

- Cuánto detalle poner en system prompt vs descriptions de tools.
- Cuándo paralelizar vs cuándo serializar por dependencias.
- Cómo cortar el loop (max iterations, token budget, early exit).
- Qué hacer cuando una tool falla a mitad del flujo.
- Cómo garantizar que side effects (publicar comentario) solo ocurran al final.

## ¿Cómo funciona?

### El tool set

Cinco herramientas que trabajan juntas:

| Tool | Propósito | Depende de |
|---|---|---|
| `get_pr_details` | Metadata del PR, archivos cambiados | – |
| `analyze_code_security` | Vulnerabilidades (SQLi, XSS, auth) | `get_pr_details` |
| `check_test_coverage` | Cobertura de tests por archivo | `get_pr_details` |
| `check_code_style` | Linter, type hints, formato | `get_pr_details` |
| `post_review_comment` | Publica el veredicto en el PR | **todas las demás** |

### El loop del agente

```
system prompt (rol + workflow sugerido)
      ↓
user: "revisa el PR 1247"
      ↓
┌─────────────────────────────────────┐
│ LLM.create(messages, tools)          │
│   → tool_use? sí → ejecuta → append  │
│                 → no → respuesta fin │
└─────────────────────────────────────┘
      ↑         loop (max N iters)
      └────────────────────────────────
```

El LLM **decide** el orden de llamadas basándose en lo que descubre; nosotros no hardcodeamos la secuencia.

### Graceful degradation

- Scanner de seguridad caído → fallback a regex básico de patrones conocidos (notar en el reporte).
- GitHub rate-limited → usar cache de PR si existe (anotar freshness).
- Coverage service lento → reportar "no disponible" en vez de bloquear al agente.

## Ejemplo con código

### Schemas del tool set (formato Anthropic)

```python
tools = [
    {
        "name": "get_pr_details",
        "description": (
            "Obtiene metadata del PR: título, autor, archivos cambiados, estado de CI y aprobaciones. "
            "SIEMPRE llámala primero al iniciar una revisión."
        ),
        "input_schema": {
            "type": "object",
            "properties": {"pr_number": {"type": "integer", "description": "Número del PR"}},
            "required": ["pr_number"],
        },
    },
    {
        "name": "analyze_code_security",
        "description": (
            "Escanea archivos buscando vulnerabilidades (SQL injection, XSS, auth flaws, crypto débil). "
            "Devuelve lista con severity, file, line, remediation. Úsala tras get_pr_details."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "pr_number": {"type": "integer"},
                "file_paths": {"type": "array", "items": {"type": "string"}},
                "severity_threshold": {
                    "type": "string",
                    "enum": ["low", "medium", "high", "critical"],
                    "description": "Default: medium",
                },
            },
            "required": ["pr_number"],
        },
    },
    {
        "name": "check_test_coverage",
        "description": (
            "Calcula cobertura de tests para los archivos cambiados. Devuelve % global y por archivo. "
            "Flaguear si está por debajo de 80%."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "pr_number": {"type": "integer"},
                "coverage_threshold": {"type": "number", "description": "Default: 80"},
            },
            "required": ["pr_number"],
        },
    },
    {
        "name": "check_code_style",
        "description": (
            "Corre linter y verificaciones de estilo. Devuelve violaciones por severidad. "
            "Issues menores se notan, mayores (ej. falta de type hints en API pública) deben bloquear."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "pr_number": {"type": "integer"},
                "strict_mode": {"type": "boolean", "description": "Default: false"},
            },
            "required": ["pr_number"],
        },
    },
    {
        "name": "post_review_comment",
        "description": (
            "Publica el comentario final de review en el PR. Úsala UNA SOLA VEZ al final, "
            "después de haber recabado todos los hallazgos. 'review_action' resume el veredicto."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "pr_number": {"type": "integer"},
                "body": {"type": "string", "description": "Comentario en Markdown"},
                "review_action": {
                    "type": "string",
                    "enum": ["approve", "request_changes", "comment"],
                },
            },
            "required": ["pr_number", "body", "review_action"],
        },
    },
]
```

### Executor con composición de tools

```python
import asyncio, json, time

class CodeReviewExecutor:
    def __init__(self, github, scanner, coverage, linter):
        self.github = github
        self.scanner = scanner
        self.coverage = coverage
        self.linter = linter
        self._pr_cache: dict[int, dict] = {}

    async def execute(self, name: str, args: dict) -> dict:
        try:
            method = getattr(self, f"_{name}")
            data = await method(**args)
            return {"success": True, "data": data}
        except Exception as e:
            return {
                "success": False,
                "error": {"type": type(e).__name__, "message": str(e), "retryable": isinstance(e, (TimeoutError, ConnectionError))},
            }

    async def _get_pr_details(self, pr_number: int) -> dict:
        if pr_number in self._pr_cache:
            return {**self._pr_cache[pr_number], "cached": True}
        pr = await self.github.get_pr(pr_number)
        info = {
            "number": pr.number, "title": pr.title, "author": pr.user,
            "files": [{"path": f.path, "additions": f.additions} for f in pr.files],
            "ci_status": pr.ci_status,
        }
        self._pr_cache[pr_number] = info
        return info

    async def _analyze_code_security(self, pr_number, file_paths=None, severity_threshold="medium"):
        pr = await self._get_pr_details(pr_number)  # composición
        files = file_paths or [f["path"] for f in pr["files"]]
        try:
            vulns = await self.scanner.scan(files, min_severity=severity_threshold)
        except ScannerDown:
            vulns = await self._fallback_regex_scan(files)  # graceful degradation
        return {
            "vulnerabilities": vulns,
            "summary": f"{len(vulns)} issues",
            "critical_count": sum(1 for v in vulns if v["severity"] == "critical"),
        }

    async def _check_test_coverage(self, pr_number, coverage_threshold=80.0):
        report = await self.coverage.for_pr(pr_number)
        return {
            "overall": report.overall,
            "by_file": report.by_file,
            "below_threshold": [f for f, pct in report.by_file.items() if pct < coverage_threshold],
            "passed": report.overall >= coverage_threshold,
        }

    async def _check_code_style(self, pr_number, strict_mode=False):
        pr = await self._get_pr_details(pr_number)
        violations = await self.linter.run([f["path"] for f in pr["files"]], strict=strict_mode)
        return {"violations": violations, "major_count": sum(1 for v in violations if v["severity"] == "major")}

    async def _post_review_comment(self, pr_number, body, review_action):
        # Side effect: requiere que todas las anteriores hayan corrido
        await self.github.post_review(pr_number, body=body, action=review_action)
        return {"posted": True, "action": review_action}
```

### Loop de orquestación

```python
import anthropic

SYSTEM_PROMPT = """Eres un code reviewer senior. Workflow sugerido:
1) get_pr_details para entender el scope.
2) En paralelo: analyze_code_security, check_test_coverage, check_code_style.
3) Síntesis + post_review_comment UNA VEZ al final.

Reglas:
- Si hay vulnerabilidades critical/high: review_action='request_changes'.
- Si coverage < 80%: menciónalo pero no bloquees por sí solo.
- Issues de estilo menores: solo notar, no bloquear.
- Sé específico: cita archivo y línea cuando sea posible.
"""

async def review_pr(pr_number: int, executor: CodeReviewExecutor):
    client = anthropic.AsyncAnthropic()
    messages = [{"role": "user", "content": f"Revisa el PR #{pr_number}."}]

    for iteration in range(10):  # hard cap
        resp = await client.messages.create(
            model="claude-sonnet-4-5",
            max_tokens=4096,
            system=SYSTEM_PROMPT,
            tools=tools,
            messages=messages,
        )
        messages.append({"role": "assistant", "content": resp.content})

        if resp.stop_reason != "tool_use":
            return resp.content[0].text

        tool_blocks = [b for b in resp.content if b.type == "tool_use"]
        # Ejecución en paralelo
        results = await asyncio.gather(*[
            executor.execute(b.name, b.input) for b in tool_blocks
        ])

        messages.append({
            "role": "user",
            "content": [
                {
                    "type": "tool_result",
                    "tool_use_id": b.id,
                    "content": json.dumps(r, default=str)[:8000],  # truncar por seguridad
                    "is_error": not r["success"],
                }
                for b, r in zip(tool_blocks, results)
            ],
        })

    raise RuntimeError("Max iteraciones alcanzado sin veredicto final")
```

### Flujo completo (traza típica)

```
turno 1  → tool_use: get_pr_details(1247)
turno 2  → tool_use PARALELO:
             analyze_code_security(1247)
             check_test_coverage(1247)
             check_code_style(1247)
turno 3  → tool_use: post_review_comment(
             1247,
             body="## Resumen\nSe encontró SQL injection en auth.py:42...",
             review_action="request_changes"
           )
turno 4  → respuesta final en texto: "Review publicada."
```

### Equivalente OpenAI (resumido)

```python
from openai import AsyncOpenAI
openai_tools = [{"type": "function", "function": {**t, "parameters": t.pop("input_schema")}} for t in tools]
# El loop es idéntico pero usa response.choices[0].message.tool_calls y role="tool".
```

## Errores comunes

- **Hardcodear el orden** en código ("primero security, luego coverage..."). Pierdes el valor del LLM: déjalo decidir con base en resultados.
- **No tener early exit.** Si la primera tool devuelve "PR no existe", debería terminar; algunos agentes insisten en llamar las demás.
- **Side effects dentro del loop.** `post_review_comment` ejecutada varias veces por un modelo confundido spamea el PR. Idempotencia o lock a nivel executor.
- **Context overflow silencioso.** Después de 10 iteraciones los `tool_result` acumulados exceden 100k tokens. Trunca, resume o reinicia con summary.
- **Composición con llamadas duplicadas.** Si `analyze_security`, `check_coverage` y `check_style` cada una llama internamente a `get_pr_details`, pagas 3 veces el round-trip. Cache a nivel executor.
- **Ignorar `is_error: true`.** Si no marcas los tool_result fallidos como error, el modelo asume que funcionó y sigue construyendo encima de datos inválidos.
- **System prompt gigante repitiendo descripciones.** Deja los detalles de uso en la **description** de cada tool; el system prompt es para rol y reglas globales.
- **Sin budget de iteraciones ni tokens.** Un bug en una tool puede dejar al agente en loop quemando dinero. Siempre `max_iterations` + monitoreo de token spend.
- **Faltar `graceful degradation`.** Si el scanner cae, el agente debería **continuar con lo disponible** y advertirlo, no abortar.
- **No testear el loop end-to-end.** Testear tools individuales no basta: necesitas tests de integración con mocks del LLM para validar secuencias.

## Resumen

- Construir un agente **de verdad** combina schemas coherentes, executor robusto y un loop de orquestación en el que el LLM decide la secuencia.
- Un **tool set** se diseña como conjunto: nombres consistentes, dependencias claras, side effects aislados en una herramienta final.
- Usa **composición**: tools que internamente llaman a otras (con cache) reducen latencia y confusión del modelo.
- **Paraleliza** las tool calls independientes con `asyncio.gather` cuando el modelo las emite en una sola respuesta.
- Aplica **graceful degradation**: cuando una API cae, continúa con lo que haya y repórtalo; no abortes el agente.
- Pon límites duros: **max iterations**, **token budget**, **timeouts por tool** y **circuit breakers** por servicio externo.
- Las side effects (comentarios, emails, pagos) deben ser **idempotentes** o requerir confirmación explícita.
- El **system prompt** define rol y reglas; las **descriptions** definen uso. No los mezcles.
- Testea tools unitariamente, pero también **loops end-to-end** con mocks del LLM para capturar bugs de orquestación.
- Este patrón (schemas + executor + loop) escala desde code review hasta soporte, análisis de datos, automatización de workflows e investigación.
