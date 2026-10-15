# Ejemplo 02 — `needs` y `outputs`: pasar un valor entre jobs

## Concepto que demuestra

Cómo un job A **computa** un valor (tag calculado dinámicamente, incluyendo valores multilínea con heredoc), lo expone como `outputs:` del job, y un job B lo **consume** vía `${{ needs.A.outputs.* }}`.

## Contexto

Pipeline de release trivial: el job `compute` deriva un tag basado en el SHA y el timestamp, y un bloque de release notes del log de git. Luego el job `publish` recibe ambos y los imprime en el summary del run.

## Objetivo

Al terminar, podrás responder:
- ¿Dónde se declara que un valor es `output` del job (no del step)?
- ¿Cómo se escribe un output multilínea sin romper el parseo?
- ¿Qué parte del contexto expone `needs.<job>.outputs.<key>`?

## Prerrequisitos

- Haber leído `theory/lesson.md` sección 4.2.

## Workflow

Archivo: `workflow.yml`.

```yaml
name: ex-02-needs-and-outputs
on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read

jobs:
  compute:
    runs-on: ubuntu-latest
    outputs:
      tag: ${{ steps.meta.outputs.tag }}
      notes: ${{ steps.meta.outputs.notes }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0        # necesario para `git log`
      - id: meta
        name: Compute tag and notes
        run: |
          TAG="v$(date -u +%Y%m%d-%H%M%S)-${GITHUB_SHA:0:7}"
          echo "tag=$TAG" >> "$GITHUB_OUTPUT"
          {
            echo 'notes<<EOF'
            git log --oneline -n 5
            echo 'EOF'
          } >> "$GITHUB_OUTPUT"
      - name: Debug (same-job access)
        run: |
          echo "In-job steps.meta.outputs.tag = ${{ steps.meta.outputs.tag }}"

  publish:
    needs: compute
    runs-on: ubuntu-latest
    steps:
      - name: Consume outputs from compute
        env:
          TAG:   ${{ needs.compute.outputs.tag }}
          NOTES: ${{ needs.compute.outputs.notes }}
        run: |
          echo "Publishing tag: $TAG"
          echo "---- notes ----"
          echo "$NOTES"
      - name: Write job summary
        env:
          TAG:   ${{ needs.compute.outputs.tag }}
          NOTES: ${{ needs.compute.outputs.notes }}
        run: |
          {
            echo "## Release $TAG"
            echo ""
            echo "### Changes"
            echo '```'
            echo "$NOTES"
            echo '```'
          } >> "$GITHUB_STEP_SUMMARY"
```

## Resultado esperado

- `compute` corre, imprime `In-job steps.meta.outputs.tag = v2026...`, y expone `tag` + `notes` como `outputs` del job.
- `publish` corre después, lee `needs.compute.outputs.tag` y `needs.compute.outputs.notes`, y los imprime.
- La UI del job `publish` muestra una tarjeta de summary con el tag y los últimos 5 commits.

## Interpretación

- **`outputs:` a nivel job**: sin ese bloque, el valor existe sólo *dentro* de `compute`.
- **`$GITHUB_OUTPUT`** es un archivo. Cada línea `key=value` es un par. Para multilínea, se usa el formato heredoc `key<<EOF ... EOF`.
- **Interpolación en env antes del shell**: `TAG` y `NOTES` entran como env vars, no como texto interpolado dentro del `run:`. Esto es importante: si `NOTES` contuviera caracteres de shell (p. ej. `$(rm -rf /)`), interpolarlo directamente sería inyección. Vía env, el shell lo trata como string.

## Errores frecuentes

- **Olvidar `fetch-depth: 0`**: el checkout por defecto es shallow (depth 1); `git log` no devuelve historia.
- **Interpolar directamente `${{ needs.compute.outputs.notes }}` en un `run:`**: si el log tuviera caracteres especiales, podría romper el script o ser inyección. Preferí env vars.
- **Omitir `id:` en el step `meta`**: sin `id`, no podés referenciar sus outputs.

## Relación con escenarios reales

- Pipeline de release: un job calcula versión semver, otro job construye imagen etiquetada con esa versión.
- Deploy condicional: un job decide si hay cambios reales (hash de dependencias), otro job solo deploya si cambió.
- Monorepo: un job calcula lista JSON de paquetes afectados, matriz dinámica los buildea en paralelo (ver sección 7.2 de la lección).

## Limpieza

No aplica.
