# Ejemplo 02 — JavaScript action con `@actions/core` y `@actions/github`

## Concepto que demuestra

Una JS action **mínima pero realista**: lee inputs con `@actions/core`, consulta el contexto con `@actions/github`, setea un output, y es ejecutable localmente con `node dist/index.js` + `INPUT_*` env vars.

## Contexto

Las JS actions son el "default" cuando compositional no alcanza: Node 20 ya está en el runner, el toolkit es oficial, los ciclos son rapidísimos. Este ejemplo muestra el patrón canónico que verás en 90 % de las actions del marketplace.

## Objetivo

Al terminar:
- Conoces la estructura de un repo de JS action (`src/`, `dist/`, `action.yml`, `package.json`).
- Entiendes por qué `dist/index.js` va commiteado.
- Sabes testear la action localmente con `INPUT_*` sin pushear a GitHub.

## Prerrequisitos

- **Node 20+** (`node --version`).
- Opcional: `npm` (si quieres regenerar `dist/` con `ncc`).

Si no tienes Node, el `run-example.sh` **se salta la ejecución** con un mensaje claro.

## Ejecución

```bash
bash files/run-example.sh /tmp/js-action-demo
```

Esto crea:

```
/tmp/js-action-demo/
└── repo-echo-pr-info/
    ├── action.yml
    ├── package.json
    ├── src/
    │   └── index.js
    ├── dist/
    │   └── index.js           # bundle "pre-compilado" (en el demo: wrapper simplificado)
    └── node_modules/
        └── @actions/
            ├── core/           # stub mínimo del toolkit, suficiente para el demo local
            └── github/
```

El `action.yml`:

```yaml
name: "Echo PR info"
description: "Reads a label input and emits a greeting + context info as outputs."
author: "demo"
branding:
  icon: "info"
  color: "blue"

inputs:
  label:
    description: "Label text to include in the greeting"
    required: false
    default: "hello"

outputs:
  greeting:
    description: "The computed greeting"
  event:
    description: "Event name as seen by the action"

runs:
  using: node20
  main: dist/index.js
```

El código:

```javascript
// src/index.js
const core   = require('@actions/core');
const github = require('@actions/github');

async function run() {
  try {
    const label = core.getInput('label') || 'hello';
    const ctx = github.context;
    const greeting = `${label} from ${ctx.repo?.owner || 'local'}/${ctx.repo?.repo || 'local'}`;

    core.info(`event: ${ctx.eventName || 'local'}`);
    core.info(greeting);

    core.setOutput('greeting', greeting);
    core.setOutput('event', ctx.eventName || 'local');
  } catch (err) {
    core.setFailed(err.message);
  }
}

run();
```

Testing local — así es exactamente como lo invoca el runner:

```bash
cd /tmp/js-action-demo/repo-echo-pr-info
export GITHUB_OUTPUT=/tmp/gh_output
: > "$GITHUB_OUTPUT"

INPUT_LABEL="hola" \
GITHUB_REPOSITORY="demo-owner/demo-repo" \
GITHUB_EVENT_NAME="push" \
  node dist/index.js

echo "--- outputs ---"
cat "$GITHUB_OUTPUT"
# greeting=hola from demo-owner/demo-repo
# event=push
```

## Resultado esperado

- `node dist/index.js` corre sin errores.
- `$GITHUB_OUTPUT` contiene `greeting=…` y `event=…`.

## Interpretación

- `runs.using: node20` + `main: dist/index.js` → el runner hace exactamente `node dist/index.js` con el cwd en el action path.
- Los inputs llegan como `process.env.INPUT_<NAME_UPPER>` (espacios y guiones a `_`).
- El contexto `github.context` se construye leyendo env vars como `GITHUB_REPOSITORY`, `GITHUB_EVENT_NAME`, `GITHUB_EVENT_PATH` (el JSON del payload).
- Los outputs se escriben a `$GITHUB_OUTPUT` (el toolkit abstrae la mecánica).

## Nota sobre `dist/` y `ncc`

En producción:

```bash
npm install @actions/core @actions/github
npm install --save-dev @vercel/ncc
# package.json → "build": "ncc build src/index.js -o dist --license licenses.txt"
npm run build
git add action.yml src/ dist/ package.json package-lock.json
```

En este demo, para no exigir conectividad, el script **genera un `dist/index.js` auto-contenido** y un pequeño `node_modules/@actions/{core,github}` suficiente para que el ejemplo funcione sin `npm install`. En las actividades verás también la variante con `ncc` (opcional).

## Errores frecuentes

- **`Cannot find module '@actions/core'`** → te falta `dist/` commiteado (o `node_modules/`). El runner no instala por ti.
- **`core.getInput('MyLabel')` devuelve `''`** → en el workflow pasaste `with: my-label: foo` (con guion). GHA lo mapea a `INPUT_MY-LABEL` y el toolkit lo normaliza a `my-label`. **Nombres consistentes.**
- **Olvidar `core.setFailed(err.message)` en el `catch`** → el step marca como OK aunque haya tirado.
- **Usar `console.log` sin más** → funciona (sale en el log) pero pierdes anotaciones (`core.notice/warning/error`).

## Limpieza

```bash
rm -rf /tmp/js-action-demo
```
