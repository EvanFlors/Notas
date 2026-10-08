# Reglas de repositorio para asistentes de IA

## ¿Qué es?

Las **reglas de repositorio** (repo rules) son instrucciones persistentes, versionadas en el propio código, que condicionan **cómo** un asistente de IA debe comportarse en ese repo específico. Son el equivalente del "handbook de ingeniería" pero legible por un LLM. Fijan convenciones, invariantes de seguridad, patrones de arquitectura y límites de scope.

Sin reglas de repo, cada desarrollador prompea distinto, cada herramienta descubre convenciones distintas y el codebase se vuelve un collage de estilos. Con reglas de repo, dos ingenieros usando herramientas distintas (Cursor y Claude Code, por ejemplo) producen output comparable y revisable.

### Formatos estándar actuales

| Archivo | Herramienta | Estado |
|---|---|---|
| `AGENTS.md` | Spec abierta (OpenAI, Google, Cursor, Factory, Jules, 2025) | De facto cross-tool |
| `CLAUDE.md` | Claude Code | Nativo (puede delegar a `AGENTS.md`) |
| `.cursor/rules/*.mdc` | Cursor | Rules modulares con globs y auto-attach |
| `.github/copilot-instructions.md` | GitHub Copilot | Oficial |
| `.windsurf/rules` | Windsurf | Reglas y memorias |
| `.aider.conf.yml` + `CONVENTIONS.md` | Aider | Config + archivo de convenciones |

El movimiento del ecosistema en 2025 fue **converger en `AGENTS.md`** como lingua franca; herramientas específicas aún leen sus formatos propios pero cada vez más también `AGENTS.md`.

### Jerarquía de instrucciones

```
Reglas globales (vendor)        ← safety, políticas del proveedor
         ↓
Reglas de repo (AGENTS.md)      ← convenciones del codebase
         ↓
Reglas de carpeta (anidadas)    ← overrides por subdirectorio
         ↓
Instrucciones de tarea          ← prompt del humano
         ↓
Contexto local                  ← archivos, diffs, logs
```

Cuando hay conflicto, la regla más específica suele ganar, **excepto en safety**: una regla de repo que prohíbe loguear secretos debe ganar sobre una instrucción de tarea que diga "añade logs para debuggear".

## ¿Por qué importa?

El problema sin reglas de repo es predecible:

- Un dev pide "añade endpoint" → el agente escribe controlador sin tests.
- Otro dev pide lo mismo → el agente añade una dependencia nueva y refactoriza el error handler.
- Reviewer tiene que aprender un estilo nuevo por cada PR.
- Cada vez que un dev nuevo llega, repite los mismos errores porque el conocimiento tribal no está en ninguna parte.

Las reglas de repo **codifican el conocimiento tribal**: convierten "así hacemos las cosas aquí" en texto que el agente lee en cada tarea. Esto reduce:

- **Varianza en diffs** para tareas similares.
- **Comentarios repetitivos de review** ("usa dependency injection", "no logueés request body").
- **Regresiones por fallos recurrentes** (bypass de auth, timeouts cambiados silenciosamente).
- **Fricción de onboarding** (nuevos devs son productivos antes).

Lo más importante: **las reglas son enforceable**. Las que no se pueden verificar en CI son solo sugerencias y se ignoran con el tiempo.

## ¿Cómo funciona?

### Qué va en reglas de repo

**Sí incluir** (estable, alta señal, previene fallos recurrentes):

- Estilo y estructura: formato, naming, layering.
- Testing: cuándo exigir tests, qué patrones (pytest fixtures, AAA, Testing Library).
- Error handling: formato de errores, logging, retries, timeouts por default.
- Seguridad: nunca loguear secretos, nunca saltar auth helpers, nunca ejecutar input de usuario.
- Performance: evitar N+1, cuidado con fetches sin paginación.
- Herramientas permitidas: qué scripts son seguros de correr, cuáles requieren aprobación.

**No incluir** (volátil o específico de tarea):

- Instrucciones one-off ("usa esta función para el ticket #123").
- Documentación extensa de APIs (va en docs, no en reglas).
- Preferencias personales de un dev individual.

Regla práctica: si cambia más de una vez al mes, probablemente no es una regla, es una tarea.

### Plantilla de `AGENTS.md`

```markdown
# AGENTS.md

## Propósito
Reglas que debe seguir cualquier agente de IA al modificar este repositorio.
Si una regla de tarea entra en conflicto con una regla de seguridad aquí,
GANA la regla de seguridad.

## No-negociables (nunca violar)

### Seguridad
- NUNCA loguear secretos, passwords, tokens, API keys ni PII (email, SSN, teléfono).
- NUNCA saltar `require_auth()` ni helpers de autorización.
- NUNCA añadir dependencias sin label `[DEPENDENCY-APPROVED]` en el PR.
- NUNCA ejecutar código ni comandos provistos por el usuario sin sandbox.

### Correctitud
- NUNCA cambiar contratos públicos de API sin actualizar docs + tests + versión.
- NUNCA modificar schemas de BD sin un script de migración y rollback.
- NUNCA cambiar valores default (timeouts, flags) sin requerimiento explícito.
- NUNCA eliminar validaciones ni manejo de errores existentes.

## Convenciones de proyecto

### Estilo
- Python: `black` + `ruff`. Type hints obligatorios en funciones públicas.
- Controladores HTTP: delgados. Lógica de negocio va en `services/`.
- Acceso a datos: solo en `repositories/`. No usar ORM crudo en controladores.

### Error handling
- Respuesta de error: `{"error": str, "code": str, "request_id": str}`.
- HTTP: 400 para input inválido, 401 sin auth, 403 sin permisos, 404 no existe, 5xx del lado del servidor.
- Loguear con `logger.error(msg, extra={"request_id": ...})`, NUNCA el body del request.

### Testing
- Todo endpoint nuevo requiere unit tests (happy + error) e integración.
- Cobertura mínima: 80% líneas. CI falla si baja.
- Nombres: `test_<funcion>_<condicion>_<resultado_esperado>`.

## Verificación requerida
Antes de proponer el PR final, el agente debe:
1. Correr `make lint` y resolver warnings.
2. Correr `pytest -q` y mostrar que pasa.
3. Correr `make type-check` si tocó código con types.
4. Listar los archivos modificados y confirmar que están dentro del scope autorizado.

## Límites (NO hacer sin instrucción explícita)
- NO refactorizar código fuera del scope de la tarea.
- NO renombrar funciones ni archivos.
- NO cambiar configuraciones (settings, env, CI configs).
- NO correr comandos destructivos (`rm -rf`, `DROP`, `git push --force`).

## Ejemplos de violaciones

### Mal: loguear secretos
```python
# VIOLACIÓN
logger.info(f"Login: user={username} pass={password}")
```
**Por qué está mal:** passwords nunca van a logs, ni siquiera en debug.

### Mal: saltar auth "por conveniencia"
```python
# VIOLACIÓN
def get_user(user_id):
    if user_id.startswith("admin_"):
        return User.query.get(user_id)  # falta require_auth()
```
**Por qué está mal:** todo acceso a datos pasa por el helper de auth, sin excepciones.

### Mal: cambio silencioso de default
```python
# VIOLACIÓN
def fetch(url):
    return requests.get(url, timeout=5)  # era 30; cambio no documentado
```
**Por qué está mal:** cambiar defaults rompe clientes existentes. Si el cambio es intencional, hay que anunciarlo.
```

### Reglas modulares (ejemplo Cursor)

Cursor permite reglas por glob (`.cursor/rules/*.mdc`) que se auto-adjuntan según los archivos editados:

```yaml
# .cursor/rules/python-api.mdc
---
description: Reglas para endpoints Python/FastAPI
globs: ["src/api/**/*.py"]
alwaysApply: false
---

- Todo endpoint usa dependencias con `Depends()`, no imports directos.
- Validación con Pydantic en el request model, no manualmente.
- Nunca retornar objetos ORM; mapear a schemas de respuesta.
- Documentar con `summary` y `response_model`.
```

## Ejemplo con código

### Enforcement en CI: dependency check

```yaml
# .github/workflows/dep-check.yml
name: Dependency Policy
on:
  pull_request:
    paths:
      - 'requirements.txt'
      - 'package-lock.json'
      - 'pyproject.toml'
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - name: Require dependency approval label
        run: |
          if ! echo "${{ github.event.pull_request.body }}" | grep -q "\[DEPENDENCY-APPROVED\]"; then
            echo "::error::Cambio de dependencias sin aprobación. Añade [DEPENDENCY-APPROVED] y justificación al PR."
            exit 1
          fi
```

### Enforcement: tests obligatorios para endpoints nuevos

```python
# scripts/check_tests.py
"""Falla si se añadió un endpoint sin un test correspondiente."""
import subprocess, sys, pathlib, re

def changed_files() -> list[str]:
    out = subprocess.check_output(
        ["git", "diff", "--name-only", "--diff-filter=A", "origin/main...HEAD"],
        text=True,
    )
    return [l for l in out.splitlines() if l]

def is_endpoint(path: str) -> bool:
    return re.match(r"src/api/.+\.py$", path) and "test" not in path

def expected_test(path: str) -> str:
    name = pathlib.Path(path).stem
    return f"tests/api/test_{name}.py"

def main() -> int:
    violations = []
    for f in changed_files():
        if is_endpoint(f) and not pathlib.Path(expected_test(f)).exists():
            violations.append(f"{f} → falta {expected_test(f)}")
    if violations:
        print("Endpoints sin test:\n  " + "\n  ".join(violations))
        return 1
    return 0

if __name__ == "__main__":
    sys.exit(main())
```

### Verificar que los tests no hagan red real

```python
# scripts/no_network_in_tests.py
import pathlib, re, sys

PATTERNS = [
    r"requests\.(get|post|put|delete)\(",
    r"urllib\.request\.",
    r"httpx\.(get|post|AsyncClient)",
    r"aiohttp\.",
]

def scan() -> list[tuple[str, int, str]]:
    hits = []
    for test_file in pathlib.Path("tests").rglob("test_*.py"):
        for i, line in enumerate(test_file.read_text().splitlines(), 1):
            for pat in PATTERNS:
                if re.search(pat, line) and "mock" not in line.lower():
                    hits.append((str(test_file), i, line.strip()))
    return hits

if __name__ == "__main__":
    hits = scan()
    for f, i, line in hits:
        print(f"{f}:{i}  {line}")
    sys.exit(1 if hits else 0)
```

### Validar que el PR siga el template

Un hook de PR template simple fuerza al autor a declarar scope e intent:

```markdown
<!-- .github/pull_request_template.md -->
## Qué cambia y por qué


## Qué NO cambia (explícito)


## Cómo se verificó
- [ ] Lint pasa
- [ ] Unit tests pasan
- [ ] Integración (si aplica)
- [ ] Regression pack (si toca auth/pagos/data)

## Riesgos y mitigaciones


## Si se usó asistente de IA
- Herramienta/modelo:
- Prompt o template de tarea (link o resumen):
- Reglas de repo activas:
```

## Errores comunes

- **Reglas genéricas tipo "escribe código limpio".** No cambia nada; el modelo no sabe qué significa "limpio" en tu repo. Reemplaza con invariantes concretos: "endpoints usan `Depends()` para auth", "cobertura mínima 80%".
- **Reglas sin enforcement.** Si no hay un linter, un check de CI o un hook que la verifique, la regla se olvida en semanas. Pair rules with checks.
- **Reglas que se contradicen.** "Prefiere diffs pequeños" vs. plantilla que pide "refactoriza mientras estás ahí". El agente oscila. Documenta precedencia y limpia conflictos.
- **Un solo archivo gigante que nadie lee.** Reglas de 2000 líneas se vuelven ruido. Divide por módulo con reglas modulares (Cursor rules por glob, carpetas anidadas con su propio `AGENTS.md`).
- **No versionar las reglas.** Si cada dev tiene su `.cursor/rules` local y no están en el repo, no hay reglas compartidas.
- **Rules demasiado estrictas.** Si bloquean trabajo legítimo, los devs bypasean (`# noqa`, `--no-verify`). Haz que seguir la regla sea más fácil que esquivarla.
- **Cambios silenciosos de reglas.** Si alguien edita `AGENTS.md` sin aviso, el equipo queda desalineado. Las reglas cambian por PR con rationale.
- **Confiar que el agente "las habrá leído".** Verifica: pide al agente que al final liste qué reglas aplicaron a su cambio. Si no las menciona, probablemente las ignoró.
- **No incluir ejemplos de violaciones.** Los contraejemplos son los que más mueven el comportamiento del modelo. Un snippet de "no hagas esto" vale más que 10 líneas de prosa abstracta.

## Resumen

- **Reglas de repo** son instrucciones persistentes versionadas que condicionan al agente en cada tarea de ese repo.
- Formato convergente en 2025-2026: **`AGENTS.md`** como spec cross-tool; `CLAUDE.md`, `.cursor/rules`, `.github/copilot-instructions.md` siguen funcionando.
- La **jerarquía** va de reglas globales del vendor → reglas de repo → reglas de carpeta → tarea → contexto. En conflictos de safety, la regla de repo gana.
- Buenas reglas son **estables, de alta señal y previenen fallos recurrentes**: seguridad, convenciones, testing, error handling, performance.
- Lo que no se puede verificar en CI se termina ignorando: **enforcement > intención**. Linters, policy checks, CI gates convierten reglas en realidad.
- Incluir **ejemplos de violaciones** mueve el output del modelo más que prosa abstracta.
- Despliega las reglas **incrementalmente** (3-5 no-negociables primero, enforcement en 1-2) y mide el impacto en incidentes y comentarios de review.
- Si una regla se bypasea sistemáticamente, el problema es la regla o el tooling, no la gente: facilita cumplir, no castigues incumplir.
- Las reglas son el puente entre "prompting individual" y "workflow de equipo"; sin ellas, cada PR es una moneda al aire.
