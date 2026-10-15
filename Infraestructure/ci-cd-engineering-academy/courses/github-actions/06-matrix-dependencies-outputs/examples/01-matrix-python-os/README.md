# Ejemplo 01 — Matriz 2D: Python × OS

## Concepto que demuestra

Cómo `strategy.matrix` expande el producto cartesiano de dos dimensiones (versión de Python × sistema operativo), cómo `include` añade una combinación extra con atributos propios, y cómo `exclude` quita combinaciones no deseadas.

## Contexto

Un paquete Python que soporta `3.11` y `3.12` en Linux y macOS, pero: `python-3.11` no está disponible/soportado en `macos-latest` (hipotético) → `exclude`; además querés probar `python-3.13` en Linux como *experimental* → `include`.

## Objetivo

Al terminar, podrás responder:
- ¿Cuántos jobs crea esta matriz?
- ¿Qué diferencia hay entre `include` y `exclude` en orden de evaluación?
- ¿Qué hace `fail-fast: false` acá?

## Prerrequisitos

- Haber leído `theory/lesson.md` secciones 2 y 4.
- Opcional: un repo propio en GitHub para probarlo en vivo.

## Workflow

Archivo: `workflow.yml` (en este mismo directorio).

```yaml
name: ex-01-matrix-python-os
on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read

jobs:
  test:
    name: test (${{ matrix.os }} / py${{ matrix.python }}${{ matrix.experimental && ' [exp]' || '' }})
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      max-parallel: 4
      matrix:
        os: [ubuntu-latest, macos-latest]
        python: ['3.11', '3.12']
        exclude:
          # Hipotético: 3.11 en macOS no es soportado por una dep.
          - os: macos-latest
            python: '3.11'
        include:
          # Combinación extra: 3.13 en Ubuntu, marcada como experimental.
          - os: ubuntu-latest
            python: '3.13'
            experimental: true
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python }}
      - name: Show runtime
        run: |
          python --version
          echo "os=${{ matrix.os }} python=${{ matrix.python }} exp=${{ matrix.experimental }}"
      - name: Run tests
        continue-on-error: ${{ matrix.experimental == true }}
        run: python -c "print('tests OK on ${{ matrix.os }} / ${{ matrix.python }}')"
```

## Resultado esperado

Combinaciones generadas (expansión paso a paso):

1. **Producto cartesiano** (2 OS × 2 python): 4 combinaciones.
   - `ubuntu-latest / 3.11`
   - `ubuntu-latest / 3.12`
   - `macos-latest / 3.11`
   - `macos-latest / 3.12`
2. **Exclude** quita `macos-latest / 3.11` → quedan 3.
3. **Include** añade `ubuntu-latest / 3.13 (experimental)` → quedan **4**.

En la UI, el job matricial `test` aparece como un nodo expandible con 4 ramas. `fail-fast: false` garantiza que si una combinación rompe, las otras tres siguen corriendo (feedback completo). `max-parallel: 4` deja a GitHub ejecutar las 4 en paralelo (sería el default; está escrito para explicitar).

## Interpretación

- La matriz **no es un `for`** — son jobs independientes, cada uno con su runner.
- `include` que añade claves nuevas (`experimental`) a una combinación nueva: cuando el expansor no encuentra coincidencia exacta en las combinaciones existentes, **crea una fila**.
- `continue-on-error: ${{ matrix.experimental == true }}` se evalúa por combinación. En las no experimentales queda `false`.

## Errores frecuentes

- **`include` que coincide con una combinación**: no duplica, enriquece. Si querés dos jobs idénticos salvo por un flag, no uses matriz — definí dos jobs.
- **Olvidar `fail-fast: false`**: con el default (`true`), un fallo en una combinación aborta las otras. Para releases querés el panorama completo.
- **Expresión en el `name:` del job**: perfectamente válida — hace los logs legibles.

## Relación con escenarios reales

- Compat matrix de un paquete publicado a PyPI.
- Build cross-platform de un CLI escrito en Node/Go/Rust.
- Smoke tests de un cliente contra varias versiones de un servicio.

## Limpieza

No hay recursos cloud ni archivos locales; es un workflow en el repo.
