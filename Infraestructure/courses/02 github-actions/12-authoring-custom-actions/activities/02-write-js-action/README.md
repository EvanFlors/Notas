# Actividad 02 — Mini-proyecto: JavaScript action

## 1. Identificación

- **ID:** `gha-12-02-write-js-action`
- **Tecnología:** `github-actions`
- **Módulo:** `gha-12-authoring-custom-actions`
- **Dificultad:** advanced
- **Duración estimada:** 90–120 min
- **Tipo:** mini-project

## 2. Contexto

Construyes una **JavaScript action** útil desde cero: **`line-counter`**.

Recibe:

- `path` (required): archivo o directorio a contar.
- `pattern` (optional, default `**/*`): glob simple a filtrar (p. ej. `**/*.py`).
- `fail-threshold` (optional, default `0`): si `> 0` y las líneas totales exceden ese número, el step falla.

Produce:

- `total-lines`: entero.
- `file-count`: entero.
- `top-file`: ruta del archivo con más líneas (string vacía si no hay archivos).

La action usa `@actions/core` (I/O) y produce **salida determinista** que luego el workflow puede consumir.

**Independent**: no te doy el código. Te doy la estructura esperada y los tests. La actividad vale por el ejercicio de **autoría + testing local sin pushear a GitHub**.

## 3. Objetivos

Al terminar:
- Escribes un `action.yml` tipo `node20` con 3 inputs y 3 outputs.
- Implementas `src/index.js` usando `@actions/core` (`getInput`, `getBooleanInput`, `info`, `setOutput`, `setFailed`).
- Produces un `dist/index.js` que el runner puede ejecutar directamente.
- Testeas localmente invocando `node dist/index.js` con `INPUT_*` env vars.
- Entiendes y describes por qué `dist/` va commiteado.

## 4. Prerrequisitos

- **Node 20+**.
- Opcional: `npm` si quieres instalar `@actions/core` real. El starter incluye un stub local de `@actions/core` **suficiente para la actividad** si prefieres no depender de red.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/bootstrap.sh /tmp/js-action-lab
cd /tmp/js-action-lab/line-counter
ls -la
# verás: action.yml (TODOs), src/index.js (TODO), dist/ vacío, node_modules/@actions/core (stub)
# además: fixtures/ con archivos de prueba
```

El starter también crea `fixtures/` con 3 archivos conocidos:

- `a.txt` — 3 líneas.
- `b.txt` — 5 líneas.
- `c.py` — 10 líneas.

El validador usará estos fixtures.

### 5.2 Escribir el `action.yml`

Debe tener:

```yaml
name: "Line counter"
description: "Counts lines across files matching a glob"
author: "<tú>"
branding:
  icon: "bar-chart-2"
  color: "purple"

inputs:
  path:
    description: "File or directory to scan"
    required: true
  pattern:
    description: "Glob pattern (simple: ** / *.ext)"
    required: false
    default: "**/*"
  fail-threshold:
    description: "If > 0 and total lines exceed this, fail the step"
    required: false
    default: "0"

outputs:
  total-lines:
    description: "Total lines across matched files"
  file-count:
    description: "Number of matched files"
  top-file:
    description: "Path of the file with the most lines (empty if none)"

runs:
  using: node20
  main: dist/index.js
```

### 5.3 Escribir `src/index.js`

Usa `@actions/core`. Algoritmo:

1. `const path = core.getInput('path', { required: true });`
2. `const pattern = core.getInput('pattern') || '**/*';`
3. `const threshold = parseInt(core.getInput('fail-threshold') || '0', 10);`
4. Enumera archivos:
   - Si `path` es archivo: `[path]`.
   - Si es directorio: recursivo, aplicando el pattern.
5. Lee cada archivo y cuenta líneas.
6. Setea `total-lines`, `file-count`, `top-file`.
7. Si `threshold > 0 && total > threshold`: `core.setFailed(…)`.

**Hint para el glob**: no necesitas una lib externa. El pattern aquí es simple — soporta `**/*` (todo), `**/*.py` (sufijo). Puedes implementarlo con `fs.readdirSync` recursivo + `endsWith` para el sufijo. Ver `solution/` si te atascas.

### 5.4 Generar `dist/index.js`

Si no vas a usar `ncc`:

```bash
cp src/index.js dist/index.js
```

(En producción compilarías con `ncc` para bundlear todas las deps en un único archivo. Para esta actividad, como `@actions/core` ya está en `node_modules/` del propio repo, basta con copiar.)

### 5.5 Testear local

```bash
cd /tmp/js-action-lab/line-counter

export GITHUB_OUTPUT=/tmp/js-action-lab/gh_output
: > "$GITHUB_OUTPUT"

INPUT_PATH="./fixtures" INPUT_PATTERN="**/*" \
  node dist/index.js

cat "$GITHUB_OUTPUT"
# total-lines=18
# file-count=3
# top-file=./fixtures/c.py (o fixtures/c.py)
```

### 5.6 Validar

```bash
bash tests/validate.sh /tmp/js-action-lab
```

Si Node no está instalado, el validador se salta la ejecución con un mensaje y falla con instrucciones de instalación.

## 6. Resultado esperado

- `action.yml` válido con 3 inputs y 3 outputs.
- `src/index.js` + `dist/index.js` presentes.
- Al correr `node dist/index.js` con `INPUT_PATH=./fixtures`, los outputs esperados son:
  - `total-lines=18` (3+5+10).
  - `file-count=3`.
  - `top-file` termina en `c.py`.
- Al correr con `INPUT_PATH=./fixtures INPUT_PATTERN=**/*.py`, los outputs:
  - `total-lines=10`, `file-count=1`, `top-file` termina en `c.py`.
- Al correr con `INPUT_PATH=./fixtures INPUT_FAIL_THRESHOLD=5`, el proceso sale con rc != 0.

## 7. Criterios de aceptación

- [ ] `action.yml` parsea y tiene `runs.using: node20` + `main: dist/index.js`.
- [ ] Los 3 inputs y los 3 outputs declarados.
- [ ] `dist/index.js` existe y es ejecutable con `node`.
- [ ] Comportamiento correcto para los 3 casos del validador.
- [ ] `src/index.js` usa `require('@actions/core')` (no `console.log` crudo para outputs).

## 8. Validación

```bash
bash tests/validate.sh /tmp/js-action-lab
```

## 9. Preguntas de reflexión

1. ¿Por qué commiteas `dist/`? ¿Qué pasaría si lo pones en `.gitignore`?
2. En un repo real, ¿cómo prevendrías "me olvidé de correr `npm run build`" con un workflow? (Pista: `git diff --exit-code dist/` en CI.)
3. Si la action necesitara llamar a la API de GitHub (p. ej. crear un comentario en el PR), ¿qué input añadirías y cómo lo usarías con `@actions/github`?
4. Compara: para la misma funcionalidad, ¿cómo cambiaría si fuera una **composite action**? ¿Dónde se complicaría?
5. Riesgo: si tu action lee rutas de `inputs.path`, ¿qué podría pasar si un consumidor pasa `../../etc/passwd`? ¿Qué validación añadirías?

## 10. Extensiones (opcional)

- **E1** — Reemplaza el stub local por `@actions/core` real: `npm init -y && npm install @actions/core && npm install --save-dev @vercel/ncc` y usa `npm run build` para generar `dist/`.
- **E2** — Añade `include-hidden` boolean input y `getBooleanInput`.
- **E3** — Escribe `tests/greet.test.js` con `node --test` para la función de conteo (separa `src/count.js` puro + `src/index.js` que lo invoca).
- **E4** — Crea `.github/workflows/test.yml` que haga `uses: ./` y verifique los outputs (YAML, no ejecutable aquí).

## 11. Limpieza

```bash
rm -rf /tmp/js-action-lab
```
