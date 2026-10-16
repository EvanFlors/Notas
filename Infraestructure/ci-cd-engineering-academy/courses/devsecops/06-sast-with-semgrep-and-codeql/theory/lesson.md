# Lección sec-06 — SAST con Semgrep y CodeQL

## 1. Qué es SAST (y qué no es)

**SAST = Static Application Security Testing**. Analiza **código fuente** (o bytecode) **sin ejecutarlo** para detectar patrones peligrosos: SQL injection, XSS, path traversal, uso de criptografía débil, deserialización insegura, `eval` de input no sanitizado, falta de timeouts en HTTP client, hardcoded credentials.

> SAST **no es**:
>
> - **SCA** — SCA mira CVEs en tus **dependencias** (Trivy, Grype). SAST mira **tu código**.
> - **DAST** — DAST ataca el **servicio corriendo** (ZAP, Burp). SAST no ejecuta nada.
> - **Tests** — un test afirma que el código **hace lo correcto**; SAST afirma que el código **no hace lo peligroso**. Son complementarios, nunca sustitutos.

La ley fundamental de SAST: **analiza sin ejecutar**. Eso significa que **no sabe los valores en runtime**. Trabaja con el AST y, si tiene suerte, con un modelo de dataflow. Dos herramientas que ilustran el extremo barato y el extremo caro:

| Herramienta | Enfoque | Precisión | Velocidad | Donde brilla |
|-------------|---------|-----------|-----------|--------------|
| **Semgrep** | Pattern matching sintáctico sobre AST, multi-lenguaje | Media (muchos FP sin cuidado) | Muy rápida | Reglas simples y custom org-specific |
| **CodeQL**  | Query language sobre AST **con dataflow + taint tracking** | Alta | Lenta | SQLi/XSS/path traversal reales, análisis cross-function |
| **Bandit**  | Reglas canónicas Python | Media | Rápida | `assert` en código prod, `pickle`, `subprocess shell=True`, random no seguro |

## 2. Semgrep en profundidad

Semgrep se diseñó para que la regla **se parezca al código** que busca. En lugar de regex, escribes "el código con huecos":

```yaml
rules:
  - id: requests-without-timeout
    patterns:
      - pattern: requests.$METHOD(...)
      - pattern-not: requests.$METHOD(..., timeout=$T, ...)
    message: "requests.$METHOD sin timeout — un peer lento cuelga tu proceso para siempre"
    severity: WARNING
    languages: [python]
```

Puntos clave:

- `$METHOD` y `$T` son **metavariables**. Capturan cualquier identificador/expresión y las puedes referenciar.
- `pattern` + `pattern-not` modela "existe un `requests.X(...)` que NO tiene `timeout=`".
- `languages: [python]` activa el parser Python.
- Severity: `INFO`, `WARNING`, `ERROR` (ERROR típicamente rompe el build).

### Registry público

Semgrep mantiene `semgrep --config auto`, que ejecuta un conjunto curado por lenguaje y framework detectados. Útil para empezar; **no sustituye** reglas custom.

### Reglas locales

Las reglas custom del repo viven en `.semgrep/*.yml` o se pasan explícitamente con `--config .semgrep/`.

### Suppressions

Para silenciar un hallazgo justificado, se añade un comentario inline:

```python
password = "test-only-fixture"  # nosemgrep: hardcoded-password
```

**Regla operativa**: toda suppression debe ir con la razón; si no, es ruido futuro. En CI, se puede fallar si aparece `# nosemgrep` sin razón adyacente.

### Integración CI

Un workflow mínimo (ver `examples/01-semgrep-ci/`) corre `semgrep --config auto --config .semgrep/ --sarif --output semgrep.sarif .` y sube el SARIF a Code Scanning. Severity → policy: ERROR falla el job, WARNING/INFO comentan.

## 3. CodeQL en profundidad

CodeQL es un **lenguaje de query** declarativo sobre una **base de datos** generada a partir del código. La diferencia esencial frente a Semgrep:

- Semgrep: "¿Dónde aparece este **patrón sintáctico**?"
- CodeQL: "¿Hay un **camino de datos** desde un **source** hasta un **sink**?"

Esto le permite modelar **SQLi real**: un `request.args[...]` (source) que fluye, incluso cross-function, a `cursor.execute(...)` (sink) sin pasar por un sanitizer. Esa precisión viene con un coste: generar la base de datos requiere **compilar o scrape de código** (Autobuild intenta hacerlo; a veces falla y hay que escribir el build a mano).

### Modo primario: GitHub Code Scanning (hosted)

Para este módulo, **CodeQL se consume vía GitHub Code Scanning**:

1. Repo público → gratis. Repo privado → requiere **GitHub Advanced Security** (licencia).
2. Habilitar: `Settings → Code security → Code scanning → Set up → CodeQL`.
3. Se genera `.github/workflows/codeql.yml` oficial con `github/codeql-action`.
4. Los findings aparecen en la pestaña **Security → Code scanning alerts**.

Un `codeql.yml` básico:

```yaml
name: CodeQL
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: '23 4 * * 1'

jobs:
  analyze:
    name: Analyze (${{ matrix.language }})
    runs-on: ubuntu-latest
    permissions:
      actions: read
      contents: read
      security-events: write
    strategy:
      fail-fast: false
      matrix:
        language: [python, javascript]
    steps:
      - uses: actions/checkout@v4
      - uses: github/codeql-action/init@v3
        with:
          languages: ${{ matrix.language }}
          queries: security-and-quality
      - uses: github/codeql-action/autobuild@v3
      - uses: github/codeql-action/analyze@v3
```

### Autobuild vs build manual

- **Autobuild** detecta herramientas (Maven, Gradle, Make, setup.py) y las ejecuta. Funciona en ~70 % de los repos.
- **Build manual**: para lenguajes compilados exóticos o toolchains custom, se reemplaza `autobuild@v3` por los pasos de build manuales (`run: make all`, etc.).

Para Python/JavaScript/Ruby no hay compilación "necesaria": CodeQL hace scrape y Autobuild no hace nada.

### CLI local (opcional)

Existe `codeql` CLI, pero su uso típico es **doc-only** en este módulo: la fuente de verdad es Code Scanning. Si quieres experimentar, los pasos son:

```bash
# Descargar bundle: https://github.com/github/codeql-action/releases
codeql database create db --language=python --source-root=.
codeql database analyze db --format=sarif-latest --output=codeql.sarif \
  codeql/python-queries:codeql-suites/python-security-and-quality.qls
```

Pero en este curso lo **asumimos como workflow** en GitHub.

## 4. Bandit (Python)

Bandit es una herramienta canónica de **reglas de seguridad Python** escrita por el equipo de PyCQA. Se solapa parcialmente con Semgrep (Python) pero captura cosas específicas:

- `assert` en código prod (desaparece con `python -O`).
- `pickle` / `cPickle` deserializando input de red.
- `subprocess` con `shell=True`.
- `hashlib.md5` o `sha1` para integridad.
- `tempfile.mktemp` (TOCTOU).
- `random` (no `secrets`) para tokens.

```bash
pip install bandit
bandit -r src/ -lll   # fail only on HIGH severity
```

Suppressions inline: `# nosec BXXX`.

Barato de meter, buena señal/ruido para Python. En este módulo lo usamos como refuerzo de Semgrep.

## 5. Reglas custom — cuándo y cómo

**Cuándo**: cuando el patrón es **específico de tu organización** y el registry público no lo cubre. Ejemplos reales:

- "Prohibido usar `requests.get` sin `timeout=`."
- "Prohibido llamar a `logger.error` con `exc_info=False` en el módulo `payments`."
- "Prohibido `print(` en código de producción (solo `logger`)."

**Cuándo NO**: cuando ya hay regla en el registry que lo hace igual o mejor. Mantener reglas custom tiene coste.

### Estructura mínima Semgrep

```yaml
rules:
  - id: no-requests-without-timeout
    languages: [python]
    severity: ERROR
    message: "requests.* debe recibir timeout=<float>. Sin timeout, un servidor lento te cuelga."
    patterns:
      - pattern-either:
          - pattern: requests.get(...)
          - pattern: requests.post(...)
          - pattern: requests.put(...)
          - pattern: requests.delete(...)
          - pattern: requests.patch(...)
      - pattern-not: requests.$M(..., timeout=$T, ...)
```

### Tests de la regla

Semgrep acepta un fixture `rule.test.yaml` o archivos `OK` / `RULEID` convencionales. Patrón canónico:

```
.semgrep/
  no-requests-without-timeout.yml
  no-requests-without-timeout.test.py
```

En `no-requests-without-timeout.test.py`, cada línea marcada con `# ruleid: no-requests-without-timeout` debe disparar la regla; cada línea con `# ok: no-requests-without-timeout` no debe dispararla.

```python
import requests
r = requests.get("https://api.example.com/x")  # ruleid: no-requests-without-timeout
r = requests.get("https://api.example.com/x", timeout=5)  # ok: no-requests-without-timeout
```

Ejecutar: `semgrep --test .semgrep/`.

## 6. Triage y suppressions

El trabajo real no es correr SAST — es **triage**. Cada finding entra en uno de tres cubos:

1. **Fix** — el código es inseguro, se arregla.
2. **Suppress con razón** — es seguro en este contexto porque X; se añade comentario `# nosemgrep: id — razón: Y`.
3. **Falso positivo** — la regla se equivoca; se reporta upstream o se refina.

Un cuarto cubo, **ignorar**, no existe: ignorar es la fuente número uno de fatiga de alertas.

### Políticas de severity

Patrón típico:

- `ERROR` → **falla el job**. Rotura real.
- `WARNING` → comenta en PR, no bloquea.
- `INFO` → silencioso, visible en Code Scanning.

Resistir la tentación de "fallar en WARNING". Lleva a `# nosemgrep` masivos sin razón.

## 7. Falsos positivos — por qué pasa

- **Sin dataflow** (Semgrep lite): "esta función recibe input" ≠ "este input viene de la red".
- **Framework specific**: `request.args` de Flask es tainted; `request.args` de un wrapper interno quizá no.
- **Sanitizers no modelados**: tu `escape_html()` custom no está en la lista.

Solución operativa:

1. Empezar con `--config auto` + 3–5 reglas custom tuyas.
2. Iterar durante 2 sprints: triar, suprimir con razón, refinar.
3. **Solo cuando el ratio FP < 20 %**, subir severity a bloqueante.

## 8. Integración en pipeline — orden canónico

```
pre-commit:    gitleaks   (secretos)   [sec-04]
CI (fast):     bandit     (Python)
CI (fast):     semgrep    (--config auto + .semgrep/)
CI (slow):     codeql     (dataflow)
CI (slow):     trivy      (SCA + container) [sec-05]
```

Semgrep + Bandit en el job rápido (segundos). CodeQL en el job de PR o nightly (minutos). Fail-fast en ERROR crítico; comment-only en WARNING.

## 9. Elegir Semgrep vs CodeQL vs ambos

| Criterio | Semgrep | CodeQL |
|----------|---------|--------|
| Reglas custom frecuentes | Sí (muy fácil) | Difícil (requiere QL) |
| Dataflow / taint | Limitado (OSS) o Pro | Nativo |
| Velocidad en CI | Segundos | Minutos |
| Integración GitHub | SARIF upload | Nativa (Code Scanning) |
| Coste | OSS + SaaS opcional | Gratis en repos públicos; GHAS en privados |
| Lenguajes | 30+ | 10 (bien soportados) |

Recomendación por defecto: **Semgrep para reglas custom + CodeQL para análisis profundo**. Son complementarios, no competidores.

Snyk Code / Checkmarx / Veracode: equivalentes comerciales. Mismo paradigma, otro vendor. Para este módulo basta mencionarlos.

## 10. Antipatrones

- **"Un scanner nos salvará"**: no. El scanner encuentra patrones conocidos. Lo nuevo requiere threat modeling (`sec-01`) y revisión humana.
- **Fallar en WARNING global**: genera `# nosemgrep` masivo → ciego permanente.
- **Reglas custom sin tests**: la regla deja de disparar y nadie se entera.
- **Suppressions sin razón ni expiración**: pasan a ser inmortales.
- **Correr SAST solo en `main`**: los findings llegan tarde. Debe correr en PR.
- **Confundir "CodeQL ok" con "código seguro"**: SAST tiene FN. No sustituye revisión ni DAST.

## Resumen operativo

1. Semgrep + Bandit en CI rápido, en PR.
2. CodeQL vía Code Scanning (workflow oficial `codeql.yml`), en PR + nightly.
3. 3–5 reglas custom tuyas, con tests, en `.semgrep/`.
4. Severity bloqueante solo cuando FP < 20 %.
5. Toda suppression con razón; ninguna inmortal.
