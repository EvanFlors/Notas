# Ejemplo 01 — Filtro `paths` en push/PR

## Concepto que demuestra

Cómo hacer que un workflow dispare **solo** cuando cambian archivos relevantes, y la trampa de usar `paths` como *required check* en branch protection.

## Contexto

Un repo monorrepo con `src/` (código), `docs/` (sitio estático) y `.github/workflows/`. No quieres que el pipeline de tests corra cuando alguien solo edita un `.md` dentro de `docs/`. Pero si marcas `tests` como obligatorio en branch protection, los PRs doc-only se bloquean esperando un check que nunca llegará. Lo resolvemos con un patrón de "siempre pasa".

## Objetivo

- Leer y predecir qué dispara un `on:` con `paths` y negaciones.
- Entender la trampa de `paths` + required checks.
- Aplicar el patrón "workflow should pass without doing work".

## Archivos

- `workflow-naive.yml` — versión ingenua: skip cuando no toca `src/**`. Bloquea PRs doc-only si es required.
- `workflow-safe.yml` — versión segura: siempre crea el run, decide dentro con un `changed` job.

## Lectura: `workflow-naive.yml`

```yaml
name: CI (naive)

on:
  push:
    branches: [main]
    paths:
      - 'src/**'
      - '!src/**/*.md'
  pull_request:
    branches: [main]
    paths:
      - 'src/**'
      - '!src/**/*.md'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "running tests"
```

Comportamiento:

- Push que toca `src/app.ts` → run creado, `test` corre.
- Push que toca solo `docs/intro.md` → **no se crea run**.
- Push que toca `src/README.md` → **no se crea run** (la negación `!src/**/*.md` lo excluye).

Problema: si `test` es *required* en branch protection, los PRs doc-only quedan bloqueados esperando un check que nunca va a llegar.

## Lectura: `workflow-safe.yml`

```yaml
name: CI (safe-with-paths)

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      src: ${{ steps.filter.outputs.src }}
    steps:
      - uses: actions/checkout@v4
      - id: filter
        run: |
          if git diff --name-only "${{ github.event.pull_request.base.sha || github.event.before }}" HEAD \
             | grep -E '^src/' | grep -vE '\.md$' | grep -q .; then
            echo "src=true"  >> "$GITHUB_OUTPUT"
          else
            echo "src=false" >> "$GITHUB_OUTPUT"
          fi

  test:
    needs: changes
    runs-on: ubuntu-latest
    steps:
      - name: Skip if no src changes
        if: needs.changes.outputs.src != 'true'
        run: |
          echo "No src changes; reporting success without running tests."
          exit 0
      - uses: actions/checkout@v4
        if: needs.changes.outputs.src == 'true'
      - name: Run tests
        if: needs.changes.outputs.src == 'true'
        run: echo "running tests"
```

Diferencias:

- El `on:` no filtra por `paths` → el run **siempre se crea** → el required check **siempre se reporta**.
- La decisión se mueve a un job `changes` que calcula el diff.
- Si no hay cambios en `src/`, el job `test` reporta success sin hacer trabajo.

## Reproducir mentalmente

Para cada caso, decide si el run se crea y si `test` termina en success:

| Cambio | `workflow-naive` | `workflow-safe` |
|--------|------------------|-----------------|
| `src/app.ts` | run + test corre | run + test corre |
| `src/README.md` | **sin run** | run + test skippea → success |
| `docs/intro.md` | **sin run** | run + test skippea → success |
| `src/app.ts` + `docs/intro.md` | run + test corre | run + test corre |

## Validación

Ambos YAMLs deben ser **estructuralmente válidos**:

```bash
bash validate.sh
```

El validador comprueba sintaxis básica y la ausencia de los anti-patrones típicos.

## Preguntas

1. ¿Por qué `pull_request.base.sha` existe en el PR pero no en un push, y qué usas en push?
2. Si quitas `branches: [main]` del `on:`, ¿qué cambia?
3. ¿Qué pasa si alguien edita el propio archivo `.github/workflows/ci.yml` en un PR? ¿Qué YAML aplica, el del PR o el del base?

(Respuestas en la lección principal, secciones 4.1, 5.1 y 7.)
