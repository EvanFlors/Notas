# Ejemplo 02 — `workflow_dispatch` con inputs tipados

## Concepto que demuestra

Cómo exponer un workflow como "pipeline manual" con parámetros tipados que la UI de GitHub valida y que puedes invocar también por `gh workflow run`.

## Objetivo

- Declarar inputs `string`, `choice`, `boolean` y `environment`.
- Consumir los inputs con `${{ inputs.<name> }}`.
- Invocarlo desde CLI.
- Ver por qué los inputs tipados son más seguros que leer de `env` o de otros contextos.

## Archivos

- `workflow.yml` — el workflow listo para `.github/workflows/deploy.yml`.
- `invoke.sh` — cómo lanzarlo con `gh` CLI.
- `validate.sh` — valida sintaxis.

## Lectura

```yaml
name: Manual deploy

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        type: choice
        required: true
        default: 'dev'
        options: [dev, staging, prod]
      tag:
        description: 'Image tag to deploy (e.g., v1.2.3)'
        type: string
        required: true
      dry_run:
        description: 'If true, only prints the plan'
        type: boolean
        required: false
        default: true

permissions:
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    steps:
      - name: Show plan
        run: |
          echo "env     = ${{ inputs.environment }}"
          echo "tag     = ${{ inputs.tag }}"
          echo "dry_run = ${{ inputs.dry_run }}"
      - name: Apply
        if: inputs.dry_run == false
        run: echo "Deploying ${{ inputs.tag }} to ${{ inputs.environment }}..."
      - name: Dry-run notice
        if: inputs.dry_run == true
        run: echo "DRY-RUN: no changes made."
```

Puntos clave:

- `type: choice` + `options:` → GitHub valida que el valor venga de la lista; en la UI aparece dropdown.
- `type: boolean` → GitHub normaliza a `true`/`false` (strings). Compara **sin comillas**: `inputs.dry_run == true`.
- `environment: ${{ inputs.environment }}` → el gate del environment (approvals, secrets) depende del input, útil para "deploy a prod solo si lo pide un humano".
- Hasta 10 inputs por workflow.

## Invocarlo

Desde la UI: `Actions → Manual deploy → Run workflow → ...`.

Desde CLI (ver `invoke.sh`):

```bash
gh workflow run deploy.yml \
  -f environment=staging \
  -f tag=v1.2.3 \
  -f dry_run=false
```

## Por qué inputs tipados > leer de env

- Validación en el borde (GitHub rechaza valores fuera de `options`).
- Documentación visible en la UI (`description`).
- Trazabilidad: el payload del evento lleva los valores exactos usados.
- Menos fricción con `pull_request_target`/`workflow_run` donde los contextos cambian.

## Validación

```bash
bash validate.sh
```

Comprueba que el YAML parsea y que `inputs.*` se usa de forma consistente.
