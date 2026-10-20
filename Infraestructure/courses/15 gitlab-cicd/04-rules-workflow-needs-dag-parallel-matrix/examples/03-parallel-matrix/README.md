# Ejemplo 03 — `parallel: matrix:` para una matriz 2×3

> Lectura y análisis. Sin ejecución. Objetivo: ver `parallel: matrix:` expandiendo 6 jobs y comparar con `strategy.matrix` de GHA.

## 1. GitLab

```yaml
test:
  stage: test
  image: python:$PY_VERSION
  parallel:
    matrix:
      - PY_VERSION: ["3.11", "3.12", "3.13"]
        OS_TAG: ["linux-x64", "linux-arm64"]
  tags:
    - $OS_TAG
  script:
    - python --version
    - pip install -e .
    - pytest -q
    - echo "shard $CI_NODE_INDEX / $CI_NODE_TOTAL"
```

Expande a **6 jobs**:

```
test: [3.11, linux-x64]
test: [3.11, linux-arm64]
test: [3.12, linux-x64]
test: [3.12, linux-arm64]
test: [3.13, linux-x64]
test: [3.13, linux-arm64]
```

Las variables `$PY_VERSION` y `$OS_TAG` quedan expuestas al script y a `image:`/`tags:` (interpolación en runtime).

## 2. GHA equivalente

```yaml
jobs:
  test:
    strategy:
      matrix:
        py: ["3.11", "3.12", "3.13"]
        os: [ubuntu-latest, ubuntu-24.04-arm]
      fail-fast: false
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.py }}
      - run: pytest -q
```

## 3. Diferencias prácticas

| Aspecto | GHA | GitLab |
|---------|-----|--------|
| Add combination | `strategy.matrix.include:` | Nueva entrada en `matrix:` |
| Remove combination | `strategy.matrix.exclude:` | **No existe directo** — reescribir el matrix o usar `rules:` por valor |
| Fail-fast | `strategy.fail-fast: true` | Por defecto NO fail-fast; hay que combinar `allow_failure:` y lógica externa |
| Límite paralelo | `strategy.max-parallel: N` | Se controla por **runner concurrency**, no por YAML |
| Nombre del job | `test (3.11, linux)` | `test: [3.11, linux]` |

## 4. Patrón "añadir una combinación extra"

GHA:
```yaml
strategy:
  matrix:
    py: ["3.11", "3.12"]
    os: [linux]
    include:
      - py: "3.13"
        os: macos
```

GitLab:
```yaml
parallel:
  matrix:
    - PY_VERSION: ["3.11", "3.12"]
      OS_TAG: ["linux"]
    - PY_VERSION: ["3.13"]
      OS_TAG: ["macos"]
```

Son **dos entradas** en el array `matrix:`. Cada entrada expande su propio producto cartesiano.

## 5. Patrón "excluir una combinación"

GHA:
```yaml
strategy:
  matrix:
    py: ["3.11", "3.12", "3.13"]
    os: [linux, macos]
    exclude:
      - py: "3.11"
        os: macos
```

GitLab (recomendado — explícito, feo):
```yaml
parallel:
  matrix:
    - PY_VERSION: ["3.11"]
      OS_TAG: ["linux"]
    - PY_VERSION: ["3.12", "3.13"]
      OS_TAG: ["linux", "macos"]
```

Alternativa con `rules:` (desaconsejada por complejidad):
```yaml
rules:
  - if: $PY_VERSION == "3.11" && $OS_TAG == "macos"
    when: never
  - when: on_success
```

Prefiere la primera: el YAML lee lo que realmente corre.

## 6. `CI_NODE_INDEX` vs variables de la matriz

- `parallel: N` → el único canal de reparto es `CI_NODE_INDEX` (1..N) y `CI_NODE_TOTAL`.
- `parallel: matrix:` → **no uses** `CI_NODE_INDEX`; usa las variables declaradas (`$PY_VERSION`, `$OS_TAG`). GitLab asigna un índice interno pero no es estable entre runs.
