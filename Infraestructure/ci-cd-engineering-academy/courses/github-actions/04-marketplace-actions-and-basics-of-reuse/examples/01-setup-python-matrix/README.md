# Ejemplo 01 — Matriz con `actions/setup-python` pinneado a SHA

## Concepto que demuestra

Un workflow mínimo pero realista que usa **tres actions oficiales** del catálogo (`actions/checkout`, `actions/setup-python`, `actions/cache`), ejecutándose en una **matriz** de versiones de Python (3.11, 3.12, 3.13). Todas pinneadas a SHA con comentario de versión.

## Contexto

Este es el patrón que verás en el 90% de los repos Python con CI en GitHub. Antes de hacer nada "avanzado" (publish, OIDC, SBOM), lo primero es tener este workflow bien formado y seguro.

## Objetivo

Al terminar:
- Puedes leer línea por línea el workflow y explicar qué hace cada `uses:`.
- Puedes decir por qué el `uses:` lleva un SHA de 40 chars y un `# v<SEMVER>` al lado.
- Puedes correrlo mentalmente para una `strategy.matrix` con 3 entradas.

## Prerrequisitos

- Haber leído `theory/lesson.md`.
- (Opcional) `actionlint` para validar sintaxis local.

## El workflow

Archivo: `files/ci.yml` (lo copiarías a `.github/workflows/ci.yml` en un repo real).

Lectura comentada:

```yaml
name: CI (matrix)

on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read            # principio de mínimo privilegio desde el día 1

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false       # queremos ver TODAS las versiones que fallan, no solo la primera
      matrix:
        python-version: ['3.11', '3.12', '3.13']
    steps:
      # (1) Trae el código del repo al workspace del runner
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2

      # (2) Instala Python en la versión de la matriz
      - uses: actions/setup-python@0b93645e9fea7318ecaed2b359559ac225c90a2b  # v5.3.0
        with:
          python-version: ${{ matrix.python-version }}
          cache: 'pip'       # cache integrada: la action usa hashFiles() de los lockfiles

      # (3) (Alternativa) cache manual más fino, solo si no usas el `cache:` de setup-python
      - uses: actions/cache@6849a6489940f00c2f30c0fb92c6274307ccb58a  # v4.1.2
        with:
          path: ~/.cache/pip
          key: ${{ runner.os }}-py${{ matrix.python-version }}-pip-${{ hashFiles('**/requirements*.txt') }}

      - name: Install deps
        run: |
          python -m pip install --upgrade pip
          if [ -f requirements.txt ]; then pip install -r requirements.txt; fi
          pip install pytest

      - name: Run tests
        run: pytest -q || echo "no tests yet"   # placeholder para el ejemplo
```

## Qué estudiar

1. **Pinning**: busca los 3 SHA. Verifica que son de 40 caracteres hex. Observa el comentario `# vX.Y.Z` al lado.

   > NOTA: los SHAs anteriores corresponden a `actions/checkout@v4.2.2`,
   > `actions/setup-python@v5.3.0` y `actions/cache@v4.1.2` a la fecha de redacción
   > del módulo. Antes de pegarlos en un repo real, re-verifícalos con:
   > `gh api repos/actions/checkout/git/refs/tags/v4.2.2 --jq '.object.sha'`

2. **Matriz**: 3 valores de `python-version` → el job se **expande en 3 ejecuciones paralelas**. Cada una ve un `${{ matrix.python-version }}` distinto.

3. **`fail-fast: false`**: por default la matriz se cancela cuando una entrada falla; aquí lo apagamos para ver qué versión(es) rompen.

4. **`permissions: contents: read`**: el `GITHUB_TOKEN` queda limitado a leer el repo. Nada de escribir issues, releases ni packages. Se extiende sólo cuando un job lo necesita.

5. **Cache**: ambas opciones (`cache: 'pip'` del propio setup-python **o** `actions/cache` explícito) funcionan. Lo normal es usar la primera; mostramos la segunda para que veas cómo se construye una `key` manual con `hashFiles()`.

## Verificación local

Si tienes `actionlint`:

```bash
cd /Users/efloresp06/Desktop/Courses/Python/Notas/Infraestructure/ci-cd-engineering-academy/courses/github-actions/04-marketplace-actions-and-basics-of-reuse/examples/01-setup-python-matrix
actionlint files/ci.yml
```

Si no, un chequeo mínimo con Python:

```bash
python3 -c "import yaml,sys; yaml.safe_load(open('files/ci.yml')); print('YAML OK')"
```

## Preguntas de reflexión

1. ¿Qué pasaría si quitaras `fail-fast: false`? ¿Y si lo pusieras a `true` explícito?
2. ¿Por qué `cache: 'pip'` dentro de `setup-python` suele ser suficiente y el `actions/cache` manual queda como *opt-in*?
3. ¿Qué pasa si pusieras `python-version: 3.11` (sin comillas, como número)? Pista: YAML flotante vs string.
4. ¿Cómo pedirías que la matriz **excluya** `3.13` sólo en PRs de dependabot? Pista: `if:` + `github.actor`.
5. Si el maintainer de `actions/setup-python` republicara el tag `v5.3.0` apuntando a otro commit, ¿tu workflow cambiaría? Explica por qué.
