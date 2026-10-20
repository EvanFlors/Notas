# Ejemplo 01 — Composite action: setup Python + Poetry

## Concepto que demuestra

Cómo empaquetar una secuencia de setup repetitiva (checkout implícito, Python, Poetry pinneado, `poetry install` con cache) en una **composite action local** reutilizable desde cualquier job del mismo repo. Es el bloque más común de cualquier CI Python moderno.

## Qué aprendes

- La anatomía de un `action.yml` con `runs.using: composite`.
- Por qué cada `run:` dentro de un composite **requiere `shell: bash`**.
- Cómo declarar `inputs` con defaults y cómo propagar un `output` desde un step al nivel action.
- Cómo invocarla con `uses: ./.github/actions/<name>` (requiere `actions/checkout` antes).

## Prerrequisitos

- `gha-01` … `gha-06`.
- `bash` local para correr el demo. (No requiere GitHub real: todo se simula en `/tmp/`.)

**Costos**: ninguno.

## Archivos

- `files/action.yml` — la composite action.
- `files/caller-ci.yml` — un workflow caller que la invoca dos veces con inputs distintos.
- `files/run-example.sh` — script que materializa un repo demo en `/tmp/comp-demo/` con la estructura esperada por GitHub Actions.

## Ejecución (modo local)

```bash
bash files/run-example.sh /tmp/comp-demo
tree /tmp/comp-demo -L 3
```

Esto crea:

```
/tmp/comp-demo/
├── .github/
│   ├── actions/
│   │   └── setup-python-plus-poetry/
│   │       └── action.yml          (la composite)
│   └── workflows/
│       └── ci.yml                  (el caller)
└── pyproject.toml                  (dummy, para que poetry tenga qué leer)
```

Para **ejecutarlo contra GHA real**:

```bash
# (opcional, requiere gh auth + un repo remoto)
cd /tmp/comp-demo
git init -q -b main
git add .
git -c user.name=Demo -c user.email=demo@x.y commit -q -m "demo"
gh repo create comp-demo --private --source=. --remote=origin --push
# luego inspecciona el run con: gh run list
```

En GHA verás el job `test-matrix` con los steps de la composite **anidados dentro** del job (no son jobs separados — ese es el punto de composite).

## El `action.yml` (fragmento comentado)

```yaml
name: 'Setup Python + Poetry'
description: 'Set up a Python version, install Poetry pinned, run poetry install with cache'

inputs:
  python-version:
    description: 'Python version (e.g. 3.11, 3.12)'
    required: false
    default: '3.12'
  poetry-version:
    description: 'Poetry version pinned'
    required: false
    default: '1.8.3'
  install-args:
    description: 'Extra args forwarded to poetry install'
    required: false
    default: '--no-interaction --no-root'

outputs:
  python-path:
    description: 'Absolute path to the python binary used'
    value: ${{ steps.detect.outputs.python }}
  poetry-version:
    description: 'Resolved Poetry version string'
    value: ${{ steps.detect.outputs.poetry }}

runs:
  using: 'composite'
  steps:
    - uses: actions/setup-python@v5
      with:
        python-version: ${{ inputs.python-version }}
        cache: 'pip'

    - name: Install Poetry (pinned)
      shell: bash
      run: |
        pip install "poetry==${{ inputs.poetry-version }}"
        poetry --version

    - name: Install project dependencies
      shell: bash
      run: poetry install ${{ inputs.install-args }}

    - id: detect
      shell: bash
      run: |
        python_bin="$(command -v python)"
        poetry_v="$(poetry --version | awk '{print $NF}' | tr -d ')')"
        echo "python=$python_bin"   >> "$GITHUB_OUTPUT"
        echo "poetry=$poetry_v"     >> "$GITHUB_OUTPUT"
```

Comentarios no obvios:

- Los `${{ inputs.* }}` solo son válidos **dentro de la composite** (no uses `github.event.inputs` que es para `workflow_dispatch`).
- `shell: bash` en cada step `run:`. Sin él, el parse falla.
- El step con `id: detect` es un patrón común: ejecuta algo que descubre el ambiente y escribe keys en `$GITHUB_OUTPUT`; el `outputs:` a nivel action las expone al caller.

## El caller (fragmento comentado)

```yaml
name: CI
on: [push, pull_request]

jobs:
  test-matrix:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        python-version: ['3.11', '3.12']
    steps:
      - uses: actions/checkout@v4             # OBLIGATORIO antes de uses: ./...

      - id: env
        uses: ./.github/actions/setup-python-plus-poetry
        with:
          python-version: ${{ matrix.python-version }}
          # poetry-version se queda con el default

      - run: echo "python=${{ steps.env.outputs.python-path }} poetry=${{ steps.env.outputs.poetry-version }}"

      - name: Lint
        run: poetry run ruff check .

      - name: Test
        run: poetry run pytest -q
```

Observa: la composite se usa en una **matriz** sin que la propia composite tenga que saber de la matriz. Cada expansión del matrix es un job con su runner, y cada uno llama a la composite independientemente.

## Limpieza

```bash
rm -rf /tmp/comp-demo
```

## Preguntas de reflexión

1. ¿Podrías llamar a esta composite desde **otro repo** sin modificarla? ¿Qué tendrías que cambiar en el `uses:`?
2. ¿Qué pasa si el caller define `env: PIP_INDEX_URL: ...` a nivel job? ¿Lo ve la composite?
3. Si quisieras que la composite **también** corriera `pytest` como step, ¿por qué sería probablemente una mala decisión de diseño?
4. ¿Cuántos "minutos de runner" extra te cuesta usar esta composite vs tener los mismos 4 steps inline?
