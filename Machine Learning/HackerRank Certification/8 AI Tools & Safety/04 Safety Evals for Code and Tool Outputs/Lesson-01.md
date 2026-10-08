# Safety Evals para Código Generado por IA

## ¿Qué es?

Las **safety evals para código** son un conjunto de verificaciones automatizadas diseñadas específicamente para detectar **patrones inseguros** en código producido por asistentes de IA (Copilot, Claude Code, Cursor, Codeium). A diferencia de los tests funcionales tradicionales (que verifican que el código *haga lo correcto*), las safety evals verifican que el código **no haga cosas peligrosas**: fugas de secretos, inyecciones SQL, deserialización insegura, bypass de autorización, dependencias vulnerables.

Formalmente, una safety eval es una función `s: Code → {pass, fail, warning}` que ejecuta sobre un diff o PR y produce un veredicto accionable. Se diferencia de un linter porque:

| Dimensión | Linter (Pylint, ESLint) | Safety Eval |
|---|---|---|
| Objetivo | Estilo, legibilidad | Seguridad y riesgo de ejecución |
| Falso positivo tolerable | Alto | Bajo (satura al equipo) |
| Severidad | Warning | Crítica / Alta / Media / Baja |
| Fuente de verdad | Guía de estilo | Modelo de amenazas + incidentes reales |
| Gating | Opcional | Puede bloquear merge |

> **Idea clave:** La IA genera código *plausible*, no necesariamente *seguro*. El código puede compilar, pasar tests y leerse bien, mientras introduce vulnerabilidades sutiles como logging de tokens, `eval()` sobre input del usuario o rutas sin middleware de autenticación.

### Pirámide de verificación

```
                 ┌──────────────┐
                 │  Red Team    │  ← adversarial, costoso, pre-release
                 ├──────────────┤
                 │  Pen Testing │  ← externo, trimestral
                 ├──────────────┤
                 │  Review manual│  ← senior eng, high-risk PRs
                 ├──────────────┤
                 │  Safety Evals │  ← automatizadas, cada PR
                 ├──────────────┤
                 │  Linters/Tests│  ← funcionalidad y estilo
                 └──────────────┘
```

Las safety evals ocupan la capa que **escala con el volumen de código generado por IA**: barata, rápida, reproducible.

## ¿Por qué importa?

Un asistente de IA genera decenas de PRs por día en un equipo mediano. El review humano **no escala** al mismo ritmo, y los revisores naturalmente se enfocan en *funcionalidad* más que en *seguridad*. El resultado: regresiones de seguridad que se cuelan al main en lotes.

Estudios y reportes de la industria (Snyk 2024 State of AI Code Security, Stanford CodeX 2023) muestran que:

- Entre **30-40%** del código generado por LLMs contiene al menos una vulnerabilidad detectable con SAST estático.
- Las categorías más comunes replican el **OWASP Top 10**: injection, broken auth, sensitive data exposure, XXE, broken access control.
- Los modelos tienden a reproducir **patrones obsoletos** vistos en training (ej. `md5` para passwords, `pickle` para datos externos).

### Marco regulatorio

| Jurisdicción | Marco | Qué exige |
|---|---|---|
| EU | AI Act (2024) | Evaluación de riesgo obligatoria para sistemas de alto riesgo; conformidad documentada |
| EE.UU. | NIST AI RMF | Framework voluntario: Govern, Map, Measure, Manage |
| EE.UU. | EO 14110 (Biden, 2023) | Red teaming obligatorio para modelos frontier |
| Global | ISO/IEC 42001 | Sistema de gestión de IA auditable |
| Anthropic | Responsible Scaling Policy | ASL thresholds: evaluaciones antes de desplegar capacidades peligrosas |
| OpenAI | Preparedness Framework | Scorecards de 4 categorías (cyber, CBRN, persuasion, autonomy) |

### Qué pasa sin safety evals

- Un endpoint `/api/profile` sin middleware de auth → cualquier usuario lee datos de otros.
- Un `logger.info(request.body)` → tokens y passwords en Datadog.
- Un `pickle.loads(user_data)` → RCE trivial.
- Dependencia `event-stream@3.3.6` → cryptojacker (incidente real, 2018).

Ninguno falla el test unitario. Todos fallan la safety eval.

## ¿Cómo funciona?

Una safety eval se construye en **cuatro capas** complementarias, cada una con herramientas distintas.

### Capa 1: Análisis estático (SAST)

Detecta patrones peligrosos sin ejecutar el código. Herramientas estándar:

| Herramienta | Lenguaje | Especialidad |
|---|---|---|
| **Semgrep** | Multi | Reglas custom con sintaxis AST; muy expresivo |
| **Bandit** | Python | OWASP Python; rápido en CI |
| **CodeQL** | Multi | Data-flow analysis profundo (GitHub Advanced Security) |
| **Snyk Code** | Multi | ML-powered, prioriza por explotabilidad |
| **SonarQube** | Multi | Quality gates integrados en CI/CD |
| **Checkov** | IaC | Terraform, CloudFormation, Kubernetes |

### Capa 2: Escaneo de dependencias (SCA)

Detecta CVEs en librerías de terceros:

- **Safety / pip-audit** (Python), **npm audit** (JS), **cargo audit** (Rust).
- **Snyk**, **Dependabot**, **Renovate** para automated upgrades.
- Políticas de allowlist por licencia.

### Capa 3: Escaneo de secretos

Previene que claves y tokens lleguen al repo:

- **detect-secrets** (Yelp), **truffleHog**, **gitleaks**.
- Hooks pre-commit + escaneo histórico del repo.

### Capa 4: Políticas específicas del repo

Reglas custom que codifican invariantes del equipo:

- "Toda ruta `/api/admin/*` debe decorarse con `@require_role('admin')`".
- "Prohibido `eval()`, `exec()`, `pickle.loads()` sobre input no verificado".
- "Toda query SQL debe usar parámetros, nunca f-strings".

### Severity gating

No todo hallazgo bloquea el merge. Un buen pipeline usa severidades:

| Severidad | Acción | Ejemplo |
|---|---|---|
| **Crítica** | Bloquea merge | SQL injection, RCE, secreto expuesto |
| **Alta** | Requiere approval explícito | Dependencia con CVE alta, auth faltante |
| **Media** | Ticket de follow-up | Logging de PII, crypto débil |
| **Baja** | Log informativo | Comentarios TODO sobre security |

### Flujo end-to-end

```
Dev + AI assistant generan PR
          ↓
    Pre-commit hook (secrets scan, lint rápido)
          ↓
    CI: Semgrep + Bandit + SCA + policy checks
          ↓
    ¿Crítica? ─── Sí ──→ Bloqueo + notificar
          │
          No
          ↓
    ¿Alta?   ─── Sí ──→ Request review de security owner
          │
          No
          ↓
    Merge permitido + log de hallazgos medios/bajos
          ↓
    Dashboard: tendencia de regresiones por semana
```

## Ejemplo con código

Pipeline práctico que combina Semgrep y Bandit, con severity gating y un test de regresión custom.

### 1. Reglas Semgrep para patrones comunes

```yaml
# .semgrep/ai-security.yml
rules:
  - id: no-eval-on-user-input
    patterns:
      - pattern-either:
          - pattern: eval($X)
          - pattern: exec($X)
      - pattern-not: eval("...")
    message: "Nunca uses eval/exec sobre input dinamico. RCE directo."
    languages: [python]
    severity: ERROR

  - id: no-pickle-untrusted
    pattern: pickle.loads($DATA)
    message: "pickle sobre datos externos permite ejecucion arbitraria."
    languages: [python]
    severity: ERROR

  - id: no-fstring-sql
    pattern-either:
      - pattern: cursor.execute(f"...{$X}...")
      - pattern: cursor.execute("..." + $X + "...")
    message: "Usa queries parametrizadas: cursor.execute(sql, (param,))."
    languages: [python]
    severity: ERROR

  - id: no-md5-for-secrets
    patterns:
      - pattern-either:
          - pattern: hashlib.md5($X)
          - pattern: hashlib.sha1($X)
    message: "MD5/SHA1 no son seguras para passwords/tokens. Usa bcrypt/argon2."
    languages: [python]
    severity: WARNING

  - id: no-request-body-in-logs
    pattern-either:
      - pattern: logger.$METHOD(request.body, ...)
      - pattern: logger.$METHOD(request.json, ...)
      - pattern: print(request.body)
    message: "Request body puede contener passwords/tokens. No lo loguees."
    languages: [python]
    severity: ERROR
```

### 2. Runner Python que orquesta SAST + gating

```python
#!/usr/bin/env python3
"""
Pipeline de safety evals para codigo generado por IA.
Ejecuta Semgrep + Bandit, aplica severity gating.
"""
import subprocess
import json
import sys
from dataclasses import dataclass
from enum import Enum
from typing import List

class Severity(Enum):
    CRITICAL = "critical"
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"

@dataclass
class Finding:
    tool: str
    rule_id: str
    severity: Severity
    file: str
    line: int
    message: str

def run_semgrep(target: str) -> List[Finding]:
    """Ejecuta Semgrep con reglas custom + registry OWASP."""
    cmd = [
        "semgrep", "--config", ".semgrep/ai-security.yml",
        "--config", "p/owasp-top-ten",
        "--json", target,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    data = json.loads(result.stdout) if result.stdout else {"results": []}

    severity_map = {"ERROR": Severity.CRITICAL, "WARNING": Severity.MEDIUM, "INFO": Severity.LOW}
    findings = []
    for r in data["results"]:
        findings.append(Finding(
            tool="semgrep",
            rule_id=r["check_id"],
            severity=severity_map.get(r["extra"]["severity"], Severity.LOW),
            file=r["path"],
            line=r["start"]["line"],
            message=r["extra"]["message"],
        ))
    return findings

def run_bandit(target: str) -> List[Finding]:
    """Ejecuta Bandit (SAST Python)."""
    cmd = ["bandit", "-r", target, "-f", "json", "-ll"]
    result = subprocess.run(cmd, capture_output=True, text=True)
    data = json.loads(result.stdout) if result.stdout else {"results": []}

    severity_map = {"HIGH": Severity.CRITICAL, "MEDIUM": Severity.HIGH, "LOW": Severity.MEDIUM}
    findings = []
    for r in data["results"]:
        findings.append(Finding(
            tool="bandit",
            rule_id=r["test_id"],
            severity=severity_map.get(r["issue_severity"], Severity.LOW),
            file=r["filename"],
            line=r["line_number"],
            message=r["issue_text"],
        ))
    return findings

def apply_gating(findings: List[Finding]) -> int:
    """Devuelve exit code: 0 = merge OK, 1 = bloqueo."""
    counts = {s: 0 for s in Severity}
    for f in findings:
        counts[f.severity] += 1
        marker = {
            Severity.CRITICAL: "BLOQUEA",
            Severity.HIGH: "APPROVAL",
            Severity.MEDIUM: "WARN",
            Severity.LOW: "INFO",
        }[f.severity]
        print(f"[{marker}] {f.tool}:{f.rule_id} {f.file}:{f.line} - {f.message}")

    print("\n--- Resumen ---")
    for s in Severity:
        print(f"  {s.value}: {counts[s]}")

    if counts[Severity.CRITICAL] > 0:
        print("MERGE BLOQUEADO: hay hallazgos criticos.")
        return 1
    if counts[Severity.HIGH] > 0:
        print("Requiere approval de security owner.")
        return 2  # CI puede tratarlo como bloqueo blando
    return 0

if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "src/"
    all_findings = run_semgrep(target) + run_bandit(target)
    sys.exit(apply_gating(all_findings))
```

### 3. Test de regresión custom (incidente real → test)

```python
# tests/security/test_auth_middleware.py
"""
Regresion: PR #4821 introdujo /api/admin/users sin @require_admin.
Este test previene recurrencia.
"""
import ast
from pathlib import Path

PROTECTED_PREFIXES = ("/api/admin/", "/api/internal/")
AUTH_DECORATORS = {"require_admin", "require_auth", "login_required"}

def extract_routes(source: str):
    tree = ast.parse(source)
    for node in ast.walk(tree):
        if not isinstance(node, ast.FunctionDef):
            continue
        for dec in node.decorator_list:
            # @app.route("/path") o @router.get("/path")
            if isinstance(dec, ast.Call) and dec.args:
                arg = dec.args[0]
                if isinstance(arg, ast.Constant) and isinstance(arg.value, str):
                    decorator_names = {
                        d.func.attr if isinstance(d, ast.Call) and isinstance(d.func, ast.Attribute)
                        else d.id if isinstance(d, ast.Name) else ""
                        for d in node.decorator_list
                    }
                    yield arg.value, decorator_names, node.name

def test_protected_routes_have_auth():
    violations = []
    for py_file in Path("src/api").rglob("*.py"):
        for path, decorators, fn_name in extract_routes(py_file.read_text()):
            if path.startswith(PROTECTED_PREFIXES):
                if not (decorators & AUTH_DECORATORS):
                    violations.append(f"{py_file}::{fn_name} -> {path}")

    assert not violations, (
        "Rutas protegidas sin auth middleware:\n  " + "\n  ".join(violations)
    )
```

### 4. Configuración CI (GitHub Actions)

```yaml
# .github/workflows/safety-evals.yml
name: AI Code Safety Evals
on: [pull_request]

jobs:
  safety:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: "3.11" }
      - run: pip install semgrep bandit safety detect-secrets
      - name: Secrets scan
        run: detect-secrets scan --baseline .secrets.baseline
      - name: SAST pipeline
        run: python scripts/safety_pipeline.py src/
      - name: Dependency CVEs
        run: safety check --json
      - name: Regression pack
        run: pytest tests/security/ -v
```

## Errores comunes

- **Confiar solo en linters.** Pylint o Black no detectan `eval()` sobre input del usuario. Los safety evals son una capa distinta.
- **Dataset de eval público → modelos lo memorizan.** Si usas HumanEval o un benchmark conocido para medir seguridad del output, los modelos recientes ya vieron esos ejemplos. Usa **held-out sets privados** rotados cada trimestre.
- **No hacer eval en producción, solo pre-deploy.** El drift de comportamiento del modelo (actualizaciones de OpenAI, Anthropic) puede introducir regresiones post-deploy. Monitorea en continuo.
- **Reportar solo % de pass sin análisis case-level.** "95% de PRs pasan" oculta que el 5% que falla incluye los endpoints más críticos. Analiza por severidad y por módulo.
- **Confundir "no refusal" con "safe output".** Que el modelo acepte generar el código no significa que el código sea seguro; son dos ejes ortogonales.
- **Juez LLM con mismo bias que el generador.** Usar GPT-4 para evaluar código generado por GPT-4 produce auto-afirmación. Usa un modelo distinto o varios en ensemble.
- **Severity gating binario (todo bloquea o nada).** Satura al equipo y hace que ignoren todo. Usa 4 niveles con acciones distintas.
- **Olvidar las dependencias.** Un `requirements.txt` con `requests==2.6.0` tiene CVEs conocidos; el código puede ser perfecto y el sistema aún inseguro.
- **No tener dueño.** Las reglas Semgrep se desactualizan si nadie las mantiene. Asigna un security champion por equipo.
- **Allowlists sin expiración.** Un `# nosemgrep` temporal se vuelve permanente. Toda supresión debe tener fecha y ticket.

## Resumen

- Las **safety evals** son verificaciones automatizadas que detectan patrones *inseguros* en código generado por IA, distintas de los tests funcionales y de los linters de estilo.
- Importan porque la IA **escala el volumen** y **concentra errores predecibles** (OWASP Top 10 replicado). El review humano no escala al mismo ritmo.
- Se construyen en 4 capas: **SAST** (Semgrep, Bandit, CodeQL), **SCA** (Snyk, Safety), **secrets scanning** (detect-secrets, gitleaks) y **policy checks** custom.
- Usa **severity gating** de 4 niveles (critical bloquea, high requiere approval, medium ticket, low log) para mantener el signal alto.
- Codifica **incidentes reales como tests de regresión**: cada bug de seguridad reciente debe tener un test que lo prevenga.
- Marcos como **EU AI Act**, **NIST AI RMF**, **Anthropic RSP** y **OpenAI Preparedness** están empujando esto desde recomendación a requisito.
- Mide efectividad: hallazgos por semana, time-to-fix, incidentes que se escaparon de las evals. Si no mides, degradan.
