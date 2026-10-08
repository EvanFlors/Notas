# Evaluación de código generado por IA

## ¿Qué es?

La **evaluación (eval) de código generado por IA** es el conjunto de checks automáticos y evidencia objetiva que convierten "la IA escribió esto" en "podemos probar que es seguro de mergear". Es la aplicación del principio *trust, but verify* al desarrollo asistido.

En producción, la fluidez del output no es evidencia. Un diff puede verse perfecto, compilar sin errores y pasar unit tests, y aun así cambiar un timeout silenciosamente, loguear una contraseña o romper autorización. Los **evaluation gates** son la red de seguridad que atrapa esos modos de fallo específicos de la IA antes de que lleguen a prod.

### Capas de evaluación

| Capa | Qué atrapa | Tiempo | Ejemplos |
|---|---|---|---|
| **Fast checks** | Sintaxis, estilo, tipos | Segundos | `ruff`, `black`, `mypy`, `tsc --noEmit` |
| **Behavior checks** | Lógica funcional | Minutos | pytest unit + integración |
| **Regression packs** | Fallos pasados y flujos críticos | Minutos | Tests que encapsulan incidentes previos |
| **Security/policy** | Secretos, deps, APIs inseguras | Minutos | `gitleaks`, `semgrep`, `pip-audit`, OPA |
| **LLM-judge** | Calidad subjetiva (triage) | Minutos | Review de tono, claridad de docs |

### Modos de fallo específicos de IA

| Modo | Qué pasa | Cómo detectarlo |
|---|---|---|
| **Silent behavior change** | Cambia default/timeout sin anunciar | Regression test con valor esperado |
| **Speculative API** | Llama función/paquete que no existe | Import check + install real + lint |
| **Over-general refactor** | "Limpia" fuera de scope | Diff size check + file allowlist |
| **Hallucinated dependency** | Añade paquete inexistente (slopsquatting) | `pip-audit`, allowlist, verificar en PyPI |
| **Security regression** | Loguea secretos, debilita auth | `gitleaks`, semgrep rules, tests negativos |
| **Brittle tests** | Tests que validan implementación, no comportamiento | Mutation testing, review manual |
| **Prompt-injected code** | Instrucciones ocultas en inputs cambiaron el output | Diff review + sandboxing del agente |

## ¿Por qué importa?

Un asistente de IA puede generar **10x más código por hora** que un humano. Si tu proceso de review y verificación no escala al mismo ritmo, el cuello de botella se mueve al reviewer, que termina firmando PRs sin leer. El resultado: incidentes que miran al post-mortem y dicen "los tests pasaban".

Los evals existen porque:

- **La fluidez engaña.** El modelo no está mintiendo, está siendo útil; pero útil-plausible ≠ correcto.
- **Los modos de fallo son repetitivos.** La IA tiende a cometer los mismos errores en distintos repos (loguear secrets, cambiar defaults). Un regression pack los convierte en imposibles.
- **La evidencia hace review posible.** Un reviewer que ve "lint ✅, tests ✅, regression pack ✅, security scan ✅" revisa 5x más rápido que uno que debe correr todo manualmente.
- **Steering con evals mejora el output.** Si el agente ve que un test falló con el mensaje exacto, propone un fix mínimo. Sin evals, el agente "cree" que terminó y entrega código roto.

## ¿Cómo funciona?

### Regression pack: la gate de mayor leverage

Un **regression pack** es un conjunto pequeño (5-20 tests) curado a partir de incidentes reales y flujos críticos. Cada test tiene un nombre que describe el incidente que previene:

```
test_auth_bypass_2024_01_no_se_removio_require_auth
test_logging_2024_02_no_se_loguean_passwords
test_timeout_2024_03_default_sigue_siendo_30s
test_payment_flow_2024_05_no_se_duplican_cargos
```

Debe correr **en cada PR** y en **menos de 5 minutos**. Si tarda más, se moverá a nightly y perderá el 90% de su valor.

### Diferencia con tests normales

| Unit tests | Regression pack |
|---|---|
| Validan funcionalidad nueva | Validan que lo viejo sigue funcionando |
| Los escribe quien añade la feature | Los escribe quien triagea el incidente |
| Pueden ser muchos | Son pocos y de alto valor |
| Suelen testear detalles | Testean comportamiento observable |

### LLM como juez: dónde ayuda y dónde hiere

| Caso de uso | ¿Usar LLM-judge? |
|---|---|
| Triage de 100 PRs para ranking | Sí |
| Review de tono en mensajes a usuarios | Sí |
| Comparar varios candidatos antes de check determinista | Sí |
| Aprobar cambio de autenticación | **No** |
| Firmar migración de BD | **No** |
| Única gate antes de prod | **No** |

Regla: si no confiarías en un humano para aprobarlo sin correr tests, no confíes en un modelo tampoco.

### Steering: usar fallos como feedback

```
Fallo determinista → feed back al agente → fix mínimo → re-run
```

El agente obtiene mejores fixes cuando ve:

- El output exacto del fallo (stack trace completo).
- El test que falló y su nombre.
- Una instrucción explícita: "fix MÍNIMO que haga pasar el test. No modifiques nada más".

Sin esto, el agente intenta cambios amplios ("deja refactorizar esto también") que empeoran la situación.

## Ejemplo con código

### Regression pack con pytest

```python
# tests/regression/test_auth_regression.py
"""
Tests que previenen que la IA (o cualquiera) repita incidentes pasados.
Cada test cita el incidente que previene.
"""
import pytest
from unittest.mock import patch
from src.api.users import get_user_data
from src.api.auth import login


class TestAuthBypassRegression:
    """Incidente INC-2024-01-15: la IA removió require_auth 'por conveniencia'."""

    def test_get_user_requiere_autenticacion(self):
        with pytest.raises(PermissionError):
            get_user_data("user123", requester_id=None)

    def test_admin_prefix_no_bypasea_auth(self):
        # Regresión específica: en INC-2024-01-15 el bypass venía del prefix "admin_"
        with pytest.raises(PermissionError):
            get_user_data("admin_123", requester_id=None)


class TestSecretLoggingRegression:
    """Incidente INC-2024-02-03: debug logs incluyeron passwords."""

    def test_login_no_loguea_password(self, caplog):
        with caplog.at_level("DEBUG"):
            try:
                login("test@example.com", "superSecret!42")
            except Exception:
                pass
        logs = caplog.text.lower()
        assert "supersecret" not in logs
        assert "password" not in logs or "password=***" in logs


class TestTimeoutRegression:
    """Incidente INC-2024-03-10: la IA cambió timeout de 30s a 5s."""

    def test_default_timeout_sigue_siendo_30s(self):
        from src.services.external_api import DEFAULT_TIMEOUT
        assert DEFAULT_TIMEOUT == 30, (
            "Si cambias este default, actualiza clientes y documenta. "
            "Ver INC-2024-03-10."
        )


class TestNoNPlusOneRegression:
    """Incidente INC-2024-07-22: pantalla de usuarios hacía 1 query por fila."""

    def test_lista_usuarios_hace_a_lo_sumo_2_queries(self):
        from src.services.user_service import listar_usuarios_con_perfil
        with patch("src.db.engine.execute") as exec_mock:
            exec_mock.return_value = []
            listar_usuarios_con_perfil(ids=list(range(10)))
        assert exec_mock.call_count <= 2, (
            f"Patrón N+1 reintroducido: {exec_mock.call_count} queries para 10 usuarios"
        )
```

### Prompt para test generation con Claude

```python
import anthropic

client = anthropic.Anthropic()

PROMPT_SYSTEM = """Eres un ingeniero senior especializado en testing.
Reglas:
- Tests pytest, en español, con nombres descriptivos.
- Cubres: happy path, edge cases, errores esperados.
- Validas COMPORTAMIENTO observable, no detalles internos.
- No mockeas lo que puedes probar directo.
- Si el código tiene efectos (BD, red), usa fixtures explícitas.
- Devuelves SOLO el bloque de código, nada de prosa.
"""

def generar_tests(codigo: str, especificacion: str) -> str:
    msg = client.messages.create(
        model="claude-sonnet-4-5",
        max_tokens=2000,
        system=PROMPT_SYSTEM,
        messages=[{
            "role": "user",
            "content": f"Spec:\n{especificacion}\n\nCódigo:\n```python\n{codigo}\n```",
        }],
    )
    return msg.content[0].text


codigo = """
def calcular_descuento(precio: float, tipo_cliente: str) -> float:
    if precio < 0:
        raise ValueError("precio negativo")
    descuentos = {"vip": 0.20, "regular": 0.0, "nuevo": 0.10}
    pct = descuentos.get(tipo_cliente, 0.0)
    return round(precio * (1 - pct), 2)
"""

print(generar_tests(
    codigo,
    "Calcula el precio con descuento según el tipo de cliente. "
    "Precio negativo debe fallar. Cliente desconocido no da descuento."
))
```

### Policy checks como gates

```python
# scripts/security_check.py
"""
Checks rápidos contra patrones peligrosos típicos de output de IA.
Pensado para correr en pre-commit o CI.
"""
import re
import sys
from pathlib import Path

RULES = [
    (r"\beval\s*\(", "eval() prohibido"),
    (r"\bexec\s*\(", "exec() prohibido"),
    (r"shell\s*=\s*True", "subprocess shell=True prohibido"),
    (r"pickle\.loads?\(", "pickle inseguro para datos externos"),
    (r"logger\.\w+\([^)]*(password|token|api_key|secret)", "logging de credencial"),
    (r"verify\s*=\s*False", "TLS verification deshabilitado"),
    (r"(AKIA|sk-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{20,})", "posible secret hardcodeado"),
]

def scan(root: Path) -> int:
    violations = 0
    for py in root.rglob("*.py"):
        if any(part in py.parts for part in ("tests", "__pycache__", ".venv")):
            continue
        for i, line in enumerate(py.read_text(errors="ignore").splitlines(), 1):
            for pattern, msg in RULES:
                if re.search(pattern, line):
                    print(f"{py}:{i}  {msg}  →  {line.strip()[:80]}")
                    violations += 1
    return violations

if __name__ == "__main__":
    sys.exit(1 if scan(Path(".")) else 0)
```

### Matriz de verificación por riesgo en CI

```yaml
# .github/workflows/ai-gates.yml
name: AI-Assisted Change Gates
on: [pull_request]

jobs:
  low-risk:
    if: contains(github.event.pull_request.labels.*.name, 'risk/low')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: make lint
      - run: pytest tests/unit -q

  medium-risk:
    if: contains(github.event.pull_request.labels.*.name, 'risk/medium')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: make lint type-check
      - run: pytest tests/unit tests/integration -q
      - run: python scripts/security_check.py

  high-risk:
    if: contains(github.event.pull_request.labels.*.name, 'risk/high')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: make lint type-check
      - run: pytest tests/unit tests/integration tests/regression -q
      - run: python scripts/security_check.py
      - uses: gitleaks/gitleaks-action@v2
      - run: pip-audit --strict
      - name: Require two reviewers
        run: |
          approvals=$(gh pr view ${{ github.event.pull_request.number }} \
            --json reviews -q '[.reviews[]|select(.state=="APPROVED")]|length')
          [ "$approvals" -ge 2 ] || exit 1
```

## Errores comunes

- **Métrica única monolítica.** "Todos los tests pasan" no cubre que un default cambió. Añade regression pack explícito para los fallos repetidos.
- **Usar LLM-judge como única gate.** Los jueces son inconsistentes y vulnerables a output plausible-pero-incorrecto. Para high-risk, usa checks deterministas.
- **Regression pack que crece sin control.** 500 tests en el pack → nadie los corre. Capa en 20-30 tests de alto valor y rota.
- **Tests que validan implementación.** La IA genera tests que coinciden con el código que acaba de escribir (circular). Resultado: pasa siempre, incluso cuando el comportamiento se rompe. Usa mutation testing o code review para detectarlo.
- **Evidencia inconsistente en el PR.** Un PR dice "corrí tests", otro no dice nada. Reviewer no sabe qué confiar. Plantilla de PR obligatoria con checkboxes.
- **No correr los tests del regression pack localmente antes de pedir review.** El autor debe ver los fallos primero.
- **Confiar en que "el agente dice que todo pasa".** El agente puede confundir "escribí los tests" con "los corrí y pasaron". Siempre ejecútalos tú o en CI.
- **No invalidar fixtures viejas.** Datos de prueba desactualizados → tests pasan por razones equivocadas. Revisa periódicamente.
- **Gates lentas se saltan.** Si el full suite tarda 2 horas, se moverá a nightly y perderá valor. Mantén la fast path <5 min.
- **No separar "fast feedback" de "deep check".** Fast gates en cada commit, deep gates en PR crítico. Un solo gate gigante bloquea el flujo.

## Resumen

- La **fluidez no es evidencia**: el output de IA debe probarse seguro, no asumirse seguro.
- Los evals son **capas**: fast checks (segundos) → behavior tests (minutos) → regression pack (minutos) → security/policy → opcional LLM-judge.
- Los **modos de fallo específicos de IA** (silent behavior change, hallucinated deps, slopsquatting, logging de secrets, over-general refactor) requieren gates targeted, no solo "más unit tests".
- **Regression packs** son la gate de mayor leverage: pequeños, curados a partir de incidentes reales, corren rápido en cada PR.
- **LLM-judge** sirve para triage, ranking y criterios subjetivos; **nunca** como única gate de código de alto riesgo.
- Los fallos deben usarse como **steering**: feed back explícito al agente para que haga el fix mínimo, no refactors amplios.
- La **matriz de verificación por riesgo** evita over-gating de cambios triviales y under-gating de cambios críticos.
- Evidencia estandarizada en el PR (lint ✅, tests ✅, regression ✅) acelera el review y reduce la carga mental del reviewer.
- Mantén las evals **rápidas y vivas**: suites lentas se saltan, fixtures viejas producen falsos positivos.
- El objetivo final: **mover rápido sin crear deuda invisible**. Evals son el harness que lo hace posible.
