# Actividad 01 — Extraer una composite action de un workflow con duplicación

## 1. Identificación

- **ID:** `gha-08-01-extract-composite-action`
- **Tecnología:** `github-actions`
- **Módulo:** `gha-08-reusable-workflows-and-composite-actions`
- **Dificultad:** intermediate
- **Duración estimada:** 45–60 min
- **Tipo:** guided-lab

## 2. Contexto

El starter te deja un repo con un workflow `.github/workflows/ci.yml` que tiene **tres jobs** (`lint`, `unit`, `integration`) y **cada uno repite** la misma secuencia de setup Python + Poetry (4 steps). Cambiar de versión de Python exige editar 3 bloques; añadir un step de setup exige editarlos 3 veces. Vas a extraer esa secuencia en una **composite action local**.

## 3. Objetivos

Al terminar:
- Creas `.github/actions/setup-env/action.yml` con `runs.using: composite` válido.
- Declaras `inputs.python-version` (default `3.12`) y `inputs.poetry-version` (default `1.8.3`).
- Expones un `output python-path` propagado desde un step con `$GITHUB_OUTPUT`.
- Refactorizas los 3 jobs del workflow para que cada uno sea `checkout` → `uses: ./.github/actions/setup-env` → su comando específico (`ruff`, `pytest -q`, `pytest tests/integration`).
- Pasas `bash tests/validate.sh`.

## 4. Prerrequisitos

- `gha-06` (jobs, matrix, outputs).
- `bash`, `python3` con PyYAML (`pip install pyyaml` o usa el que viene con tu venv).
- No requiere GitHub real: validación es estática sobre los YAML en `/tmp/`.

**Costos**: $0.

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/bootstrap.sh /tmp/extract-composite
find /tmp/extract-composite -not -path '*/.git*' | sort
```

Verás un repo con un `ci.yml` que **repite setup** 3 veces. Léelo con calma antes de empezar.

### 5.2 Crear la composite

Crea el archivo `/tmp/extract-composite/.github/actions/setup-env/action.yml`. El contrato mínimo que el validador exige:

- `name:` presente.
- `inputs.python-version` con `default: '3.12'`.
- `inputs.poetry-version` con `default: '1.8.3'`.
- `outputs.python-path` con `value:` que referencia `${{ steps.<id>.outputs.<key> }}`.
- `runs.using: 'composite'`.
- `runs.steps:` con al menos:
  - un `uses: actions/setup-python@v5` que pase `python-version: ${{ inputs.python-version }}`,
  - un `run:` que instale `poetry==${{ inputs.poetry-version }}` **con `shell: bash`**,
  - un `run:` que ejecute `poetry install` **con `shell: bash`**,
  - un `run:` final con `id` que escriba `python=<path>` a `$GITHUB_OUTPUT` **con `shell: bash`**.

Puntos trampa (si fallas aquí, el validador te lo dirá):

- **`shell: bash` en cada `run:`**. Olvidarlo falla el parse real de GHA y nuestro validador lo marca.
- **`inputs.*.default` como string entre comillas** si es `'3.12'`. YAML interpreta `3.12` como número por accidente.
- **El `value` del output** debe referenciar un step existente. Si tu step tiene `id: detect`, el value es `${{ steps.detect.outputs.python }}`.

### 5.3 Refactorizar el workflow

Edita `/tmp/extract-composite/.github/workflows/ci.yml` para que **cada uno de los 3 jobs** (`lint`, `unit`, `integration`):

1. Haga `uses: actions/checkout@v4`.
2. Luego **invoque la composite** con `uses: ./.github/actions/setup-env`.
3. Y luego ejecute solo su comando específico (`ruff check .`, `pytest -q`, `pytest tests/integration -q`).

Elimina los 4 steps duplicados de cada job.

### 5.4 Validar

```bash
bash tests/validate.sh /tmp/extract-composite
```

Debe salir con `RESULT: N/N checks OK.` y exit code 0.

## 6. Resultado esperado

- `/tmp/extract-composite/.github/actions/setup-env/action.yml` existe y cumple el contrato.
- `/tmp/extract-composite/.github/workflows/ci.yml` tiene **cero duplicación** de setup (los 3 jobs invocan la composite).
- Los 3 jobs del workflow conservan sus **comandos específicos** (`ruff`, `pytest`, `pytest integration`).

## 7. Criterios de aceptación

- [ ] `action.yml` tiene `runs.using: 'composite'`.
- [ ] Todos los `run:` dentro de la composite declaran `shell:`.
- [ ] `inputs.python-version` y `inputs.poetry-version` con defaults correctos.
- [ ] `outputs.python-path` referencia un step real.
- [ ] Los 3 jobs del workflow usan `uses: ./.github/actions/setup-env`.
- [ ] Ningún job del workflow repite ya `pip install poetry` ni `poetry install` directamente.

## 8. Validación

```bash
bash tests/validate.sh /tmp/extract-composite
```

El validador comprueba (en orden):

1. Existencia de la composite action y del workflow.
2. YAML válido (parse con `python3 -c "import yaml; yaml.safe_load(...)"`).
3. `runs.using == composite`.
4. `shell:` presente en cada `run:` de la composite.
5. Inputs y output con los nombres y defaults esperados.
6. Workflow con `uses: ./.github/actions/setup-env` en los 3 jobs.
7. Workflow sin referencias directas a `pip install poetry` ni `poetry install` fuera de la composite.

## 9. Preguntas de reflexión

1. Si quisieras publicar esta composite para que otros repos la consuman por `uses: my-org/shared/setup-env@v1`, ¿qué cambios estructurales harías?
2. ¿Por qué `shell: bash` es obligatorio en composite y no en workflows normales?
3. Si el `output python-path` lo necesitas en un step posterior, ¿con qué sintaxis lo lees desde el workflow caller?
4. Imagina que uno de los 3 jobs necesita Python 3.11 y los otros 3.12. ¿Qué cambia?

## 10. Extensiones (opcional)

- **E1** — Añade un `input install-args` (default `--no-interaction --no-root`) y páselo a `poetry install`.
- **E2** — Añade un segundo `output` `poetry-version` igualmente propagado.
- **E3** — Convierte el workflow en matriz 2x2 (`python-version` x `os`) y verifica que la composite sigue funcionando sin cambios en su contract.

## 11. Limpieza

```bash
rm -rf /tmp/extract-composite
```
