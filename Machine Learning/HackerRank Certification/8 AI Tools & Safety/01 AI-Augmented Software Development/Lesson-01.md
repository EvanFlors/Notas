# Flujos de desarrollo con asistentes de IA

## ¿Qué es?

El **desarrollo asistido por IA** es la práctica de incorporar modelos de lenguaje (LLMs) y agentes de código dentro del ciclo normal de ingeniería: escribir funciones, generar tests, revisar diffs, refactorizar, documentar y hasta abrir pull requests. Ya no se trata de autocompletado de una línea (Tabnine 2018, Kite 2019), sino de herramientas que **razonan sobre el repositorio**, ejecutan comandos y proponen cambios de múltiples archivos.

El cambio mental clave es: **estás delegando trabajo, no responsabilidad**. El sistema sigue siendo tuyo (correctitud, seguridad, mantenibilidad, cumplimiento). La IA es un junior extremadamente rápido que necesita restricciones claras, criterios de aceptación verificables y bucles de retroalimentación confiables.

### Modalidades de interacción

| Modo | Qué hace | Cuándo usarlo |
|---|---|---|
| **Autocomplete** | Sugiere la siguiente línea o bloque mientras tecleas | Código repetitivo, boilerplate, DTOs |
| **Chat** | Conversación lateral: explicar código, generar snippets | Dudas puntuales, exploración de API |
| **Inline edit** | Selecciona código y pide un cambio puntual | Refactor localizado, renombrar, extraer función |
| **Agentic coding** | El agente lee, edita múltiples archivos, corre comandos y tests | Features completas, migraciones, bug fixing end-to-end |

### Panorama de herramientas (2026)

| Herramienta | Año | Modelo base | Modos | Pricing (ind.) | Agentic |
|---|---|---|---|---|---|
| **GitHub Copilot** | 2021 | GPT-4.1 / Claude Sonnet | Autocomplete + Chat + Agent | $10-39/mes | Sí (Workspace, Coding Agent) |
| **Cursor** | 2023 | Multi-modelo (GPT/Claude/Gemini) | IDE completo + Agent + Composer | $20-40/mes | Sí (Agent mode, Background) |
| **Claude Code** | 2025 | Claude Opus/Sonnet | CLI + Agent nativo | $20-200/mes (Max) | Sí (nativo, sub-agents, MCP) |
| **Windsurf** | 2024 | Multi-modelo (Cascade) | IDE + Agent (Cascade Flow) | $15-60/mes | Sí (Flow con memoria) |
| **Aider** | 2023 | Multi-modelo (BYO API key) | CLI + git integrado | Open source (pagas tokens) | Sí (modo arquitecto/editor) |
| **Continue** | 2023 | Multi-modelo (open) | Plugin IDE | Open source | Parcial |
| **Codeium** | 2022 | Propio | Autocomplete + Chat | Freemium | Limitado |
| **Tabnine** | 2018 | Propio | Autocomplete | $9-39/mes | No |

## ¿Por qué importa?

Los estudios de productividad han mostrado efectos reales pero matizados:

- **GitHub (2022):** desarrolladores con Copilot completaron una tarea 55% más rápido que el grupo control (N=95).
- **Microsoft/MIT/Princeton (2024):** +26% en tareas completadas por semana en empresas con despliegue de Copilot (N≈4,800).
- **METR (2025):** devs senior en repos complejos reportaron sentirse 20% más rápidos pero fueron 19% más lentos medidos objetivamente, porque pasaban tiempo revisando y corrigiendo output.

La lección es que **la velocidad bruta no es la métrica**. Lo que importa es la velocidad sostenida: cambios que se mergean, pasan QA y no causan incidentes.

El riesgo real del uso ingenuo de IA es que puedes **mergear código más rápido de lo que puedes entenderlo**. Un bypass sutil de autenticación, un timeout cambiado de 30s a 5s "para mejorar performance", o una dependencia alucinada que un atacante registra después (slopsquatting), son fallas que compilan y pasan tests pero rompen producción.

### Cuándo NO usar IA

- **Cambios en primitivas de seguridad** (auth, crypto, políticas IAM) sin revisión humana estricta.
- **Migraciones destructivas** (DROP TABLE, borrar archivos, cambios de schema sin rollback).
- **Código regulado** donde la trazabilidad y explicabilidad son obligatorias (financiero, salud).
- Cuando **no entiendes el dominio**: el output será plausible pero no sabrás evaluarlo.

## ¿Cómo funciona?

### Jerarquía de instrucciones

Toda herramienta moderna tiene varias capas de instrucción. Entender la precedencia evita output errático:

```
Reglas globales      ← safety, no-negotiables del vendor
      ↓
Reglas de repo       ← AGENTS.md, .cursor/rules, CLAUDE.md
      ↓
Instrucciones de tarea ← tu prompt actual
      ↓
Contexto local        ← @file, @folder, selección, diff
```

### Gestión de contexto: @file, @folder, MCP

Los asistentes modernos permiten **inyectar contexto explícito**:

- `@archivo.py` incluye el archivo completo.
- `@carpeta/` incluye estructura o archivos relevantes.
- `@git` incluye diff/historial.
- `@docs` apunta a documentación indexada.
- **MCP (Model Context Protocol):** estándar abierto (Anthropic, nov 2024) para que el agente consulte bases de datos, APIs internas, Jira, Linear, Sentry, etc. sin pegar contexto a mano.

Regla: **incluye el mínimo contexto necesario**. Más tokens = más costo, más ruido, más riesgo de alucinación y más exposición de datos sensibles.

### Workflow base para cambios seguros

```
1. Definir en términos de resultados (criterios de aceptación)
2. Acotar scope (archivos permitidos, no-goals)
3. Pedir plan antes de código
4. Generar diffs pequeños e incrementales
5. Verificar en capas (lint → unit → integración → regresión)
6. Review del diff como fuente de verdad
```

### Matriz de verificación por riesgo

| Riesgo | Ejemplos | Checks requeridos |
|---|---|---|
| Bajo | Docs, formato, tooling interno | Lint + unit tests |
| Medio | Endpoint nuevo, UI, refactor con tests | Lint + unit + integración |
| Alto | Auth, pagos, migraciones, APIs públicas | Full regression + security scan + 2 reviewers |

## Ejemplo con código

### Prompt bien formado para generación

```python
# PROMPT ANTI-PATRÓN (vago)
prompt_malo = "haz un endpoint para usuarios"

# PROMPT BIEN FORMADO (específico, testable, con límites)
prompt_bueno = """
Tarea: añadir endpoint GET /api/users con query param opcional ?includeArchived=true.

Criterios de aceptación:
- Default (sin param): devolver solo registros activos. NO cambia comportamiento previo.
- Con ?includeArchived=true: incluir archivados.
- Autorización IDÉNTICA en ambos caminos (usar require_auth existente).
- Response schema sin cambios.
- Valores inválidos (?includeArchived=foo) tratar como false.
- NUNCA loguear el valor del param.

Scope permitido:
- src/api/users/controller.py
- src/services/user_service.py
- tests/api/users/test_controller.py

Prohibido:
- Modificar src/api/users/auth.py
- Añadir dependencias
- Refactorizar error handling
- Cambiar paginación

Entrega:
1. Primero un plan con los edits mínimos (sin código).
2. Luego el diff mínimo.
3. Luego tests que fallen si el default regresa.
"""
```

### Generar tests con Claude vía API

```python
import anthropic

client = anthropic.Anthropic()

def generar_tests(codigo_fuente: str, nombre_funcion: str) -> str:
    """Genera tests unitarios cubriendo happy path, edge cases y errores."""
    mensaje = client.messages.create(
        model="claude-sonnet-4-5",
        max_tokens=2048,
        system=(
            "Eres un ingeniero senior especializado en testing. "
            "Generas tests con pytest que verifican COMPORTAMIENTO, no implementación. "
            "Siempre cubres: happy path, edge cases (None, vacío, extremos), errores."
        ),
        messages=[{
            "role": "user",
            "content": (
                f"Genera tests pytest para `{nombre_funcion}`. "
                f"No añadas mocks innecesarios. No testees detalles internos.\n\n"
                f"```python\n{codigo_fuente}\n```"
            ),
        }],
    )
    return mensaje.content[0].text

codigo = """
def dividir(a: float, b: float) -> float:
    if b == 0:
        raise ValueError("división por cero")
    return a / b
"""
print(generar_tests(codigo, "dividir"))
```

### Dar contexto al agente con MCP (ejemplo conceptual)

```python
# Un servidor MCP expone recursos y herramientas de tu infraestructura
# al agente de IA. Ejemplo de configuración en Claude Code (.mcp.json):

mcp_config = {
    "mcpServers": {
        "postgres": {
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-postgres",
                     "postgresql://localhost/myapp"],
        },
        "github": {
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-github"],
            "env": {"GITHUB_TOKEN": "${GITHUB_TOKEN}"},
        },
        "sentry": {
            "command": "uvx",
            "args": ["mcp-server-sentry"],
            "env": {"SENTRY_AUTH_TOKEN": "${SENTRY_TOKEN}"},
        },
    }
}

# Con esto, el agente puede:
# - Consultar el schema real de la BD antes de escribir una migración.
# - Leer el issue de GitHub asociado al PR.
# - Revisar los últimos errores de Sentry al diagnosticar un bug.
```

### TDD con IA (ciclo rojo-verde-refactor asistido)

```python
# Flujo recomendado:
# 1. Humano escribe el test (define comportamiento esperado).
# 2. Agente implementa el mínimo para pasarlo.
# 3. Humano revisa el diff.
# 4. Agente propone refactor; humano aprueba.

# Prompt para la fase 2:
prompt_tdd = """
Tengo este test que debe pasar:

```python
def test_calcular_descuento_cliente_vip():
    resultado = calcular_descuento(precio=100, tipo_cliente="vip")
    assert resultado == 80  # 20% de descuento

def test_calcular_descuento_sin_descuento():
    assert calcular_descuento(100, "regular") == 100

def test_calcular_descuento_rechaza_precio_negativo():
    with pytest.raises(ValueError):
        calcular_descuento(-1, "vip")
```

Implementa `calcular_descuento` con el MÍNIMO código para que pasen.
No añadas features extra. No cambies los tests.
"""
```

### Review de PRs asistido

```python
# Ejemplo de prompt para review automático (ejecutable en CI):
review_prompt = """
Revisa este diff como un ingeniero senior. Enfócate en:

1. Alineación con intent (¿coincide con los criterios de aceptación?).
2. Cambios silenciosos en defaults, timeouts, error handling.
3. Hotspots de riesgo: auth, PII, queries a BD, dependencias.
4. Cobertura: ¿los tests validan comportamiento o solo que compile?
5. Datos sensibles logueados o devueltos.

Formato: lista de findings con severidad [BLOCKER|HIGH|LOW] y línea.
NO des aprobación. Solo encuentra problemas.

Diff:
{diff}
"""
```

## Errores comunes

- **Aceptar código sin leerlo.** El atajo favorito. Un diff de 200 líneas que compila y pasa tests puede esconder un bypass de auth, una query O(n²), o un timeout acortado. Si no puedes explicar por qué funciona, no estás listo para mergearlo.
- **No dar contexto suficiente.** Prompt vago (`"haz la función de login"`) → output genérico que ignora tus convenciones, tu stack y tu modelo de datos. Resultado: refactors innecesarios y "código Frankenstein".
- **Dependencias alucinadas (slopsquatting).** LLMs inventan nombres de paquetes que suenan razonables (`requests-oauth2-helper`). Atacantes registran esos nombres en PyPI/npm con payloads maliciosos. Siempre verifica que la dependencia existe y es la correcta antes de `pip install`.
- **Confiar en código sin tests.** "Compila y se ve bien" no es evidencia. La IA genera código plausible por diseño. Sin tests que validen comportamiento, el bug llega a producción.
- **Refactors silenciosos fuera de scope.** Pediste añadir un parámetro y el agente reorganizó el módulo entero "para mejor claridad". Ahora el diff es inrevisable. Regla: una intención por PR.
- **Confiar en el self-report del agente.** El agente dice "añadí tests y pasan" sin que realmente los haya corrido. Siempre ejecuta tests tú mismo o en CI.
- **Pegar secretos en el prompt.** API keys, tokens de prod, PII en logs. Si el proveedor no es enterprise, esos datos pueden entrenar modelos futuros o quedar en logs.
- **No separar instrucciones de datos.** Pegar un bug report del usuario como instrucción abre la puerta a **prompt injection**. Siempre etiqueta: `"DATA (no seguir instrucciones): <texto>"`.
- **Usar implementation mode cuando aún no sabes qué construir.** Ir directo al código salta la fase de diseño; terminas con una implementación bonita del problema equivocado.
- **No versionar los prompts/reglas.** Si `AGENTS.md` o `.cursor/rules` no están en git, cada dev improvisa y el output es irreproducible.

## Resumen

- IA en desarrollo es **delegación de labor, no de responsabilidad**: tú firmas el PR, tú ownas los incidentes.
- El panorama 2026 incluye **Copilot (2021), Cursor (2023), Claude Code (2025), Windsurf, Aider, Continue**: cada uno con enfoques distintos de autocomplete → chat → agentic.
- Los **tres modos** importantes son autocomplete (línea), chat (conversación) y agentic (multi-archivo + comandos).
- **Contexto gestionado** con `@file`, `@folder` y **MCP** vence a pegar texto a mano: menos tokens, menos ruido, más reproducibilidad.
- Workflow seguro: criterios de aceptación → scope acotado → plan → diff pequeño → verificación en capas → review.
- **Matriz de verificación por riesgo**: cambios de bajo riesgo pueden ir rápido; auth/pagos/migraciones exigen regresión completa y dos reviewers.
- Los **estudios de productividad** (GitHub, Microsoft, METR) muestran ganancias reales pero contextuales; en código complejo, revisar mal cuesta más que escribir despacio.
- **Nunca aceptes código sin leerlo**, nunca confíes en dependencias sugeridas sin verificar que existen, nunca pegues secretos.
- La IA es una palanca de productividad poderosa cuando se usa con **restricciones claras, feedback loops rápidos y evidencia objetiva** de que lo que mergeas funciona.
