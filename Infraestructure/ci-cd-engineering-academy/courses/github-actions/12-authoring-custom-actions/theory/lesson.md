# Lección: Authoring custom actions

> **ID:** `gha-12-authoring-custom-actions` · **Nivel:** avanzado · **Duración:** 5–6 h
> **Prerrequisitos:** `gha-04-marketplace-actions-and-basics-of-reuse`, `gha-08-reusable-workflows-and-composite-actions`.

---

## 1. Introducción intuitiva

Hasta aquí has **consumido** actions: `actions/checkout@v4`, `actions/setup-node@v4`, `docker/login-action@v3`. Alguien las escribió, las empaquetó y las publicó. Tú solo las referenciaste.

En algún momento inevitable, en un equipo real, aparece el patrón contrario:

> *"Este bloque de 8 pasos lo copié ya en cuatro workflows. Necesitamos una action propia."*

El reflejo inicial —y a menudo correcto— es: **composite action o reusable workflow** (eso lo cubrió `gha-08`). Pero hay casos donde ninguno de los dos sirve:

- La lógica involucra **llamadas a la API de GitHub** parametrizadas (crear issue, moverlo de columna, parsear artifacts).
- Hay que **procesar datos** en memoria (parsear JSON de 10 MB, calcular métricas, generar un markdown).
- Quieres **cross-OS portable** (Linux + Windows + macOS en matriz).
- Quieres **publicarla al marketplace** para que la use gente fuera de tu org.

Para estos casos escribes una action **JavaScript** o **Docker**. La diferencia es grande, y escoger mal cuesta tiempo o compatibilidad.

Este módulo te da los tres tipos, el toolkit, el testing local, y la mecánica real de publicar y pinnear.

El escenario que vamos a dominar:

```
┌──────────────────┐  tag v1.0.0  ┌──────────────────────┐
│ Repo de tu action│ ───────────> │  Repo consumidor      │
│  action.yml      │              │  .github/workflows/   │
│  src/, dist/     │              │   uses: owner/action  │
│  tests/          │  pin a SHA   │          @<40-char>   │
└──────────────────┘ <──────────  └──────────────────────┘
         ▲                                    │
         │                                    │
         │ release notes + v1 móvil           │ ejecución
         │                                    ▼
         └──────────────  runner  ────────────┘
                   (JS, Docker, composite)
```

---

## 2. Fundamentos

### 2.1 Qué es una action

Una **action** es:

> Una unidad **reutilizable** de ejecución para GitHub Actions, descrita por un archivo `action.yml` en la raíz de un repositorio (o en un subdirectorio), y referenciada desde un step como `uses: owner/repo[/path]@ref`.

Un `step` en un job tiene dos formas excluyentes:

```yaml
steps:
  - run: echo "hola"                  # shell command
  - uses: owner/repo@sha              # action
    with:
      input1: value
```

Una action no es "mágica": es un **programa** que el runner ejecuta de alguna de tres maneras.

### 2.2 El `action.yml` como contrato

Todo tipo de action parte del mismo archivo:

```yaml
name: "Nombre humano"
description: "Qué hace, en una frase."
author: "owner"
branding:
  icon: "check-square"
  color: "green"

inputs:
  foo:
    description: "qué es foo"
    required: true
    default: "bar"

outputs:
  result:
    description: "qué devuelve la action"
    # para composite: value: "${{ steps.x.outputs.y }}"
    # para JS/Docker: lo setea el código con core.setOutput('result', ...)

runs:
  using: "composite" | "node20" | "docker"
  # … resto según tipo (ver §4)
```

El contrato es lo que ve el consumidor: `with:` corresponde a `inputs`, `outputs` quedan accesibles como `steps.<id>.outputs.<name>` en el workflow caller.

### 2.3 Cómo el runner "ejecuta" cada tipo

El runner interpreta `runs.using`:

```
┌─────────────────────────────────────────────────────────────┐
│  runner (ubuntu-latest, windows-latest, macos-latest, …)    │
│                                                             │
│  "using: composite"                                         │
│     └─ expande los steps del action.yml *dentro* de este    │
│        job. No hay proceso nuevo; comparte env, PATH, pwd.  │
│                                                             │
│  "using: node20"                                            │
│     └─ node ./dist/index.js   (con INPUT_* en el env)       │
│        Un proceso Node. Veloz. Cross-OS (si tu código lo    │
│        es). El runner trae Node 20 preinstalado.            │
│                                                             │
│  "using: docker"                                            │
│     └─ docker build (si Dockerfile) o docker pull           │
│        docker run --rm -e INPUT_* -v /github:/github <img>  │
│        Aislado. Solo Linux. Cold start 10–60 s si build.    │
└─────────────────────────────────────────────────────────────┘
```

### 2.4 Dónde vive una action

Tres ubicaciones válidas para `uses:`:

| Forma | Ejemplo | Cuándo |
|-------|---------|--------|
| **Public** | `actions/checkout@v4` | Repo público (puede estar en Marketplace). |
| **Private** del repo | `./actions/mi-action` | Vive en `./actions/mi-action/action.yml` del mismo repo que el workflow (requiere `actions/checkout` antes). |
| **Private** de otro repo | `my-org/shared-actions/foo@v1` | Repo privado accesible; el `GITHUB_TOKEN` o un token con `contents: read` debe permitir leerlo. |

Para publicar al **Marketplace** el repo tiene que ser **público** y el `action.yml` tiene que estar en la raíz.

---

## 3. Historia y por qué hay tres tipos

- **Octubre 2018** — GHA se anuncia en beta orientado a Docker containers (único tipo). Se podía pegar un `Dockerfile` y GHA te lo corría.
- **Agosto 2019** — Lanzamiento general. Se añaden **JavaScript actions** (Node 12) porque Docker en runners Linux-only era limitante y lento. Node = cross-OS + arranque de milisegundos.
- **2020–2022** — **Composite actions** (steps de shell en `action.yml`, sin runtime propio) y luego versiones de Node (16 → 20) obligadas por el deprecation de las anteriores.
- **2024** — Node 20 obligatorio; Node 16 marcado deprecated; preparación para Node 22 en 2026.

La lección: hay tres tipos porque cada uno resuelve un problema real. **No existe el "mejor"**. Existe el adecuado al caso.

---

## 4. Los tres tipos, lado a lado

### 4.1 Composite action

```yaml
# action.yml
name: "Say hello"
description: "Prints a greeting"
inputs:
  who:
    description: "Target name"
    required: true
    default: "world"
outputs:
  greeting:
    description: "The emitted greeting"
    value: ${{ steps.emit.outputs.greeting }}
runs:
  using: composite
  steps:
    - id: emit
      shell: bash
      run: |
        g="Hello, ${{ inputs.who }}!"
        echo "$g"
        echo "greeting=$g" >> "$GITHUB_OUTPUT"
```

Características:
- **No tiene runtime propio**: los steps corren en el runner del caller, con su mismo shell, env y pwd.
- Puede llamar a `run:` (shell) y a `uses:` (otras actions).
- `outputs.<name>.value` referencia un `$GITHUB_OUTPUT` de un step interno.
- Comparte secretos y permisos con el job padre.
- **No hay forma de usar `@actions/core` sin hacer trampa** (no corre Node por sí sola). Si necesitas lógica compleja, no es composite.

### 4.2 JavaScript action (Node 20)

```yaml
# action.yml
name: "Say hello (JS)"
description: "Prints a greeting from Node"
inputs:
  who:
    description: "Target name"
    required: true
    default: "world"
outputs:
  greeting:
    description: "The emitted greeting"
runs:
  using: node20
  main: dist/index.js
```

```javascript
// src/index.js
const core = require('@actions/core');

async function run() {
  try {
    const who = core.getInput('who', { required: true });
    const greeting = `Hello, ${who}!`;
    core.info(greeting);
    core.setOutput('greeting', greeting);
  } catch (err) {
    core.setFailed(err.message);
  }
}

run();
```

Características:
- Node 20 **preinstalado** en todos los runners oficiales — no hay cold start.
- Portable Linux/macOS/Windows (si tu código no usa APIs específicas).
- Toolkit (`@actions/core`, `@actions/github`, `@actions/exec`, `@actions/io`) oficial.
- **Requiere commitear `dist/`** (ver §5).

### 4.3 Docker action

```yaml
# action.yml
name: "Say hello (Docker)"
description: "Prints a greeting from a container"
inputs:
  who:
    description: "Target name"
    required: true
    default: "world"
runs:
  using: docker
  image: Dockerfile       # o: image: docker://ghcr.io/owner/img:tag
  args:
    - ${{ inputs.who }}
```

```dockerfile
# Dockerfile
FROM alpine:3.20
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
```

```bash
# entrypoint.sh
#!/bin/sh
set -e
WHO="${1:-world}"
GREETING="Hello, ${WHO}!"
echo "$GREETING"
echo "greeting=${GREETING}" >> "$GITHUB_OUTPUT"
```

Características:
- Aislamiento máximo (contenedor efímero).
- Puedes usar cualquier lenguaje/binario que empaquetes en la imagen.
- **Solo runners Linux** — Docker action en `windows-latest` o `macos-latest` falla.
- Cold start: 10–60 s si construye el `Dockerfile` por run; mitígalo publicando la imagen y usando `image: docker://registro/img:tag`.
- Los inputs llegan en dos formas: como `args:` (posicionales) y como env vars `INPUT_<NAME>` (mayúscula, espacios → `_`).

### 4.4 Tabla comparativa

| Dimensión | Composite | JavaScript (Node 20) | Docker |
|-----------|-----------|----------------------|--------|
| Runtime | ninguno (expande steps) | Node 20 en runner | contenedor efímero |
| OS | cualquiera que soporte shell | Linux, macOS, Windows | **solo Linux** |
| Cold start | 0 | ~50 ms | 10–60 s (si build), <2 s (si pull) |
| Lenguaje de la lógica | shell + llamadas a actions | JavaScript / TypeScript | cualquiera |
| Acceso a toolkit `@actions/core` | no directo | sí (nativo) | no (hay que replicar: env vars + echo a `$GITHUB_OUTPUT`) |
| Dependencias | ninguna | `node_modules` (ver §5) | imagen base + lo que instales |
| Buena para | agrupar steps repetidos | lógica compleja + API GitHub | binarios/toolchains específicos |
| Mala para | lógica no trivial o parseo | binarios pesados | matriz multi-OS |

---

## 5. Por qué hay un `dist/` commiteado en las JS actions

Mira cualquier repo de action JS popular (`actions/checkout`, `actions/setup-node`): hay un `dist/index.js` **gigantesco** commiteado. ¿Por qué?

El runner **no hace `npm install`** antes de correr tu action. Hace exactamente esto:

```
cd <action-path>
node ${runs.main}
```

Si `require('@actions/core')` no está resuelto, el proceso falla. Opciones para que funcione:

1. **Commitear `node_modules/`** — funciona pero inflado y expone todas las deps a diff reviews.
2. **Compilar a un único bundle** con **`@vercel/ncc`** → `dist/index.js` contiene todo (tu código + deps) y commiteas solo eso. Es el **patrón estándar**.

Flujo típico:

```bash
npm init -y
npm install @actions/core @actions/github
npm install --save-dev @vercel/ncc
# en package.json añade:  "scripts": { "build": "ncc build src/index.js -o dist" }
npm run build
git add action.yml src/ dist/ package*.json
git commit -m "feat: initial action"
```

Riesgo real: **si cambias `src/` y olvidas `npm run build`, el `dist/` queda desincronizado** y la action en producción sigue haciendo lo viejo. Mitigación estándar: un workflow de CI que corre `npm run build && git diff --exit-code dist/` y falla si están fuera de sync.

> En este módulo las actividades no exigen `ncc` para no bloquearte si no tienes conexión; `src/index.js` puede llamar a `require('./node_modules/@actions/core')` directamente para test local. El patrón de producción se documenta y el `activities/02-write-js-action/solution/` lo ejemplifica.

---

## 6. Inputs y outputs — el detalle

### 6.1 Inputs

Declarados en `action.yml`:

```yaml
inputs:
  level:
    description: "log level (debug|info|warn)"
    required: false
    default: "info"
  file:
    description: "path to parse"
    required: true
```

Cómo llegan a tu código:

- **Composite**: como `${{ inputs.level }}` dentro de `run:` o `with:` de sub-actions.
- **JavaScript**: `core.getInput('level')` → por debajo lee `process.env.INPUT_LEVEL` (nombre: upper + espacios a `_`).
- **Docker**: `${INPUT_LEVEL}` directamente en el entrypoint, o como `args:` posicionales.

Tipo: **siempre strings**. Si quieres un boolean lees `'true'`/`'false'` y conviertes. `@actions/core` tiene `getBooleanInput('x')` que acepta `true/True/TRUE/false/False/FALSE` y rechaza otros.

### 6.2 Outputs

- **Composite**: declarados en `outputs.<name>.value` referenciando `${{ steps.<id>.outputs.<n> }}`. Dentro del step, se escriben en el archivo apuntado por `$GITHUB_OUTPUT`:
  ```bash
  echo "greeting=hola" >> "$GITHUB_OUTPUT"
  ```
- **JavaScript**: `core.setOutput('greeting', 'hola')` (hace lo mismo por debajo).
- **Docker**: mismo truco — escribir en `$GITHUB_OUTPUT`. El archivo está montado en el contenedor en `/github/file_commands/set_output_<id>` y GHA lo lee al terminar.

El caller los consume así:

```yaml
- id: hi
  uses: owner/say-hello@v1
  with:
    who: "mundo"
- run: echo "La action dijo ${{ steps.hi.outputs.greeting }}"
```

### 6.3 Multiline outputs y el heredoc trick

Si tu valor tiene saltos de línea, el formato KV simple se rompe. GitHub soporta un heredoc:

```bash
{
  echo "report<<EOF"
  cat long-report.md
  echo "EOF"
} >> "$GITHUB_OUTPUT"
```

`@actions/core.setOutput` ya se encarga de esto si le pasas un string multilínea.

---

## 7. El toolkit `@actions/core` y `@actions/github`

### 7.1 `@actions/core` — I/O con el runner

Lo que vas a usar el 95 % del tiempo:

```javascript
const core = require('@actions/core');

// Inputs
const name   = core.getInput('name', { required: true });
const level  = core.getInput('level') || 'info';
const strict = core.getBooleanInput('strict');
const items  = core.getMultilineInput('items');

// Outputs
core.setOutput('result', 'OK');

// Env & PATH (persisten para los siguientes steps)
core.exportVariable('MY_VAR', 'value');   // escribe a $GITHUB_ENV
core.addPath('/opt/mybin');               // escribe a $GITHUB_PATH

// Logging
core.debug('solo visible con ACTIONS_STEP_DEBUG=true');
core.info('mensaje normal');
core.notice('mensaje destacado (aparece en resumen)');
core.warning('warning anotado en archivo', { file: 'src/x.js', startLine: 10 });
core.error('error anotado');

// Terminar
core.setFailed('mensaje de error (marca el step como failed con exit 1)');

// Mascaring de secretos (añade al runtime)
core.setSecret('ghp_abc...');

// Job summary (markdown en el resumen del run)
await core.summary
  .addHeading('Resultado')
  .addTable([
    [{data: 'archivo', header: true}, {data: 'estado', header: true}],
    ['foo.py', 'OK'],
  ])
  .write();
```

### 7.2 `@actions/github` — cliente API autenticado

```javascript
const core   = require('@actions/core');
const github = require('@actions/github');

const token  = core.getInput('token', { required: true }); // típicamente ${{ github.token }}
const octokit = github.getOctokit(token);

const { owner, repo } = github.context.repo;
const prNumber = github.context.payload.pull_request?.number;

if (prNumber) {
  await octokit.rest.issues.createComment({
    owner, repo,
    issue_number: prNumber,
    body: 'hello from my action',
  });
}
```

El `github.context` ya tiene parseado todo: `eventName`, `payload`, `sha`, `ref`, `workflow`, `job`, `runNumber`, `actor`, `repo` (owner+repo).

Riesgos: cualquier mutación en la API consume minutos del rate limit del `GITHUB_TOKEN` y queda auditada bajo *github-actions[bot]*.

---

## 8. Testing: local primero, integración después

### 8.1 Local — el patrón `INPUT_*`

El runner te pasa cada `inputs.foo` como env var `INPUT_FOO`. Puedes **reproducir** esto en tu laptop:

```bash
# Para una JS action
INPUT_WHO="mundo" node dist/index.js
# Deberías ver: Hello, mundo!

# Para una Docker action
docker build -t my-action .
docker run --rm -e INPUT_WHO="mundo" my-action mundo
```

Esto te da un ciclo **de milisegundos** sin pushear ni esperar a GHA. Es la base del validator de los `activities/` de este módulo.

### 8.2 Unit tests del código

Si tu `src/index.js` separa lógica pura de I/O, puedes testear la lógica con `node --test`, `jest`, `vitest`:

```javascript
// src/greet.js
function greet(who) { return `Hello, ${who}!`; }
module.exports = { greet };

// src/index.js
const core = require('@actions/core');
const { greet } = require('./greet');
try {
  core.setOutput('greeting', greet(core.getInput('who')));
} catch (e) { core.setFailed(e.message); }

// test/greet.test.js  (node --test)
const { greet } = require('../src/greet');
const assert = require('node:assert');
assert.strictEqual(greet('x'), 'Hello, x!');
```

### 8.3 Integración — workflow de prueba en el mismo repo

Dentro del repo de la action, añade `.github/workflows/test.yml`:

```yaml
name: Test action
on:
  push:
    branches: [main]
  pull_request:
jobs:
  smoke:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - id: run-mine
        uses: ./                 # usa la action *de este mismo repo*
        with:
          who: ci
      - run: |
          test "${{ steps.run-mine.outputs.greeting }}" = "Hello, ci!"
```

El `uses: ./` es el truco clave: le dice al runner "la action que quiero probar es este mismo repo, en el root". Sin esto no podrías tener una PR que **primero cambia la action y en el mismo PR la prueba**.

---

## 9. Versionado y publicación

### 9.1 La convención `v1` móvil

En Marketplace, el patrón casi universal es:

- `v1.0.0`, `v1.0.1`, `v1.1.0`, … — tags inmutables (semver).
- `v1` — tag **móvil** que se mueve siempre al último `v1.*.*`. Esto permite que los consumidores escriban `uses: owner/action@v1` y reciban fixes/minor automáticamente **dentro de la major**.

Cómo mantenerlo:

```bash
# release v1.0.1
git tag v1.0.1
git push origin v1.0.1
# mover v1
git tag -f v1 v1.0.1
git push origin v1 --force
```

Si en algún momento publicas `v2.0.0` (breaking), creas un `v2` nuevo. **Nunca** mueves `v1` a un `v2`.

### 9.2 Por qué `@v1` **no** es seguro

Tags son **mutables**. Un atacante que comprometa el repo puede mover `v1` a un commit malicioso y todo el que use `@v1` ejecutará código arbitrario con los permisos del `GITHUB_TOKEN` de su workflow.

Incidentes reales (p. ej. `tj-actions/changed-files` en 2025) demuestran que esto no es teórico.

**Mitigación obligatoria en producción**: `uses: owner/action@<40-char-SHA>  # v1.2.3`.
Comentario con la versión equivalente para que Dependabot pueda actualizarte.

Dependabot (`.github/dependabot.yml`):

```yaml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule: { interval: weekly }
```

### 9.3 Release notes

Un release en GitHub es `tag + metadata + assets`. Para una action:

- Título: `v1.0.1 — fix: handle empty inputs`.
- Body: changelog en Markdown (puedes autogenerarlo con `gh release create v1.0.1 --generate-notes`).
- Marca "Set as latest release" solo si corresponde (NO si estás publicando un patch de una mayor vieja).

### 9.4 Publicación al Marketplace

Requisitos (al 2026):

- Repo **público**.
- `action.yml` en la **raíz** del repo.
- `name:` único (si colisiona el marketplace lo rechaza).
- `description:`, `author:`, `branding.icon`, `branding.color`.
- Al crear el release, GitHub muestra un check *"Publish this Action to the GitHub Marketplace"*.

No es obligatorio publicar al marketplace para que `uses: owner/repo@sha` funcione — eso ya funciona con cualquier repo público. El marketplace solo mejora la *descoverabilidad*.

---

## 10. Elegir el tipo correcto

Preguntas, en orden:

1. **¿La lógica se puede expresar como una secuencia de `run:` y `uses:`?**
   → Sí → **composite**. Es la más simple y transparente.

2. **¿Es solo "ejecutar un comando de un binario que ya está en el runner"?**
   → Sí → **composite** con un `run:` basta.

3. **¿Necesitas llamar a la API de GitHub, parsear JSON grande, o lógica no trivial?**
   → Sí → **JavaScript**. El toolkit está hecho para esto.

4. **¿Tiene que correr en Windows y macOS también?**
   → Sí → **JavaScript** (Docker queda descartado).

5. **¿Necesitas un binario/toolchain exótico que no está en el runner y es caro de instalar en cada run?**
   → Sí → **Docker** con imagen ya construida y publicada en GHCR, referenciada por `image: docker://...@sha`. Evita construir el `Dockerfile` en cada run.

6. **¿La lógica es "ensamblar un pipeline" (muchos jobs orquestados)?**
   → Entonces **ni composite ni JS ni Docker**: necesitas un **reusable workflow** (visto en `gha-08`).

Regla mnemotécnica:
```
composite ⇔ "quiero DRY"
JS         ⇔ "quiero código"
Docker     ⇔ "quiero empaquetar un binario"
reusable   ⇔ "quiero orquestar jobs"
```

---

## 11. Anti-patrones comunes

- **JS action sin `dist/` commiteado** → fallan todos los runs con `Cannot find module '@actions/core'`.
- **`dist/` desactualizado** (olvidaste `npm run build`) → la action en producción hace lo del commit anterior, difícil de depurar.
- **Docker action que construye el `Dockerfile` cada run** → 30–60 s de latencia multiplicados por cada vez que corre.
- **No validar inputs** → `core.getInput('path')` devuelve `''` si no se pasó y no es `required: true`; tu código revienta más tarde con un mensaje enigmático.
- **Interpolar `${{ inputs.x }}` directamente dentro de un `run:` en una composite** → vulnerable a script injection si `inputs.x` viene de un `pull_request.title`. Usa env vars: `env: { X: '${{ inputs.x }}' }` y luego `"$X"` en el shell. (Más en `gha-13`.)
- **Mover `v1` a un commit que rompe compat** → todos los consumidores de `@v1` fallan al día siguiente. Si rompes compat, publica `v2`.
- **No tener workflow de prueba en el repo de la action** → publicas sin saber si funciona.
- **Pedir `token: ${{ secrets.GITHUB_TOKEN }}` cuando `${{ github.token }}` basta** → confusión; funcionalmente son lo mismo pero el segundo no requiere `secrets:`.
- **Confundir `node20` con `nodejs20` / `node_20` / `Node20`** → el valor exacto es `node20` (sin guion, sin mayúsculas).

---

## 12. Preguntas de evaluación

Responde **sin consultar** el resto de la lección:

1. ¿Qué tres valores puede tomar `runs.using` en un `action.yml` y qué runtime invoca cada uno?
2. ¿Por qué una Docker action no corre en `macos-latest`? ¿Qué pasa si lo intentas?
3. ¿Por qué las JS actions tienen un `dist/index.js` commiteado en el repo? ¿Qué herramienta lo genera y qué riesgo tiene no re-generarlo?
4. Un step consumidor hace `with: who: "${{ github.event.issue.title }}"`. Tu composite action usa `${{ inputs.who }}` directamente dentro de un `run:`. ¿Qué puede salir mal y cómo se arregla?
5. ¿Qué diferencia hay entre `${{ github.token }}` y `${{ secrets.GITHUB_TOKEN }}` desde el punto de vista del consumidor de tu action?
6. Describe cómo testearías localmente una JS action que recibe `who` y produce `greeting`, **sin ejecutar un workflow en GitHub**.
7. Explica la convención `v1` móvil + tags inmutables `v1.0.0`. ¿Por qué `uses: owner/action@v1` sigue siendo inseguro en un entorno hostil y cuál es la mitigación?
8. Tienes un bloque de 12 steps repetido en 5 workflows del mismo repo, sin lógica de API. ¿Lo haces composite, JS, Docker o reusable workflow? Justifica.
9. ¿Cuál es el formato en el que una JS action recibe el input `max-retries` del `action.yml`? ¿Y una Docker action?
10. ¿Qué pasa con los `outputs` de una composite action que no referencia `steps.<id>.outputs.<name>` en su `outputs.<out>.value`?

---

## Siguiente

→ `gha-13-security-hardening` (profundiza el riesgo de script injection en inputs y la auditoría de actions de terceros).
→ `gha-14-supply-chain-sbom-attestations-signing` usará tu action para firmarla con cosign y publicar attestation SLSA.
