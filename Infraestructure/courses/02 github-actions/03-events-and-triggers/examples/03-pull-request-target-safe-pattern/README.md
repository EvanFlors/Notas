# Ejemplo 03 — Patrón seguro para `pull_request_target`

## Concepto que demuestra

Cómo construir un workflow con `pull_request_target` que **sí puede** labelear, comentar y usar secretos de forma segura, sin caer en el anti-patrón que exfiltra secretos a cualquiera que abra un PR.

## Contexto

Necesitas que un bot:

1. **Etiquete** PRs externos (requiere permisos de escritura).
2. **Publique un comentario** con información del PR (requiere escritura).
3. Opcionalmente **use un secret** (p. ej. token de Slack) para notificar al equipo.

Esto obliga a `pull_request_target` (porque `pull_request` desde fork es read-only y sin secretos). El reto es **no ejecutar código del PR** mientras lo hacemos.

## Archivos

- `pr-labeler.yml` — workflow seguro: `pull_request_target`, sin `actions/checkout`, solo opera sobre metadata del PR.
- `pr-test-and-report.yml` — pareja del patrón de dos workflows:
  - `pr-tests.yml` (otro archivo que vive en otro repo o aquí mismo): `on: pull_request`, corre tests, sube artefacto. Sin secretos.
  - `pr-test-and-report.yml`: `on: workflow_run`, descarga el artefacto y lo publica como comentario. Con secretos. **No** hace checkout del PR.
- `pr-tests.yml` — el workflow sin secretos que corre tests y produce el artefacto.
- `UNSAFE-example.yml.txt` — el anti-patrón explicado (con extensión `.txt` para que **nunca** se active si alguien copia el directorio dentro de `.github/workflows/`).
- `validate.sh` — valida que ningún `.yml` del ejemplo contenga el anti-patrón.

## El anti-patrón, para fijarlo

```yaml
# UNSAFE — NUNCA HAGAS ESTO
name: Unsafe PR test
on: pull_request_target
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.pull_request.head.sha }}   # ⚠ checkout del fork
      - run: npm install                                   # ⚠ ejecuta postinstall del atacante
                                                           # ⚠ con secretos disponibles
```

Qué pasa: cualquiera que abra un PR puede ejecutar código con tus secretos. Esto es un vector real; ha causado incidentes documentados.

## Variante segura A — Solo metadata (`pr-labeler.yml`)

```yaml
name: PR labeler

on:
  pull_request_target:
    types: [opened, reopened, synchronize]

permissions:
  contents: read
  pull-requests: write

jobs:
  label:
    runs-on: ubuntu-latest
    steps:
      - name: Add 'from-fork' label if applicable
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          PR_NUMBER: ${{ github.event.pull_request.number }}
          IS_FORK: ${{ github.event.pull_request.head.repo.fork }}
        run: |
          if [ "$IS_FORK" = "true" ]; then
            gh pr edit "$PR_NUMBER" --add-label "from-fork"
          fi
```

Observaciones:

- **No hay `actions/checkout`** — nunca se descarga código del PR.
- `permissions:` se escalan **solo** a `pull-requests: write`.
- Lo que viene del PR (`PR_NUMBER`, `IS_FORK`) se pasa por **env**, no se interpola en el shell (evita inyección aunque el campo fuera manipulable).

## Variante segura B — Dos workflows (`pr-tests.yml` + `pr-test-and-report.yml`)

**Workflow 1 — `pr-tests.yml`:** corre tests contra código del PR. Sin secretos, sin escritura.

```yaml
name: PR tests
on:
  pull_request:        # <- NO target. Tests contra código del PR.
    types: [opened, synchronize, reopened]

permissions:
  contents: read       # read-only; en fork PRs el token ya es read-only de todos modos

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: |
          echo "running tests"
          mkdir -p out
          echo "all green" > out/report.txt
          echo "${{ github.event.pull_request.number }}" > out/pr_number.txt
      - uses: actions/upload-artifact@v4
        with:
          name: pr-report
          path: out/
```

**Workflow 2 — `pr-test-and-report.yml`:** dispara cuando el anterior termina, con secretos, para publicar el comentario. **Sin tocar el código del PR.**

```yaml
name: PR test report
on:
  workflow_run:
    workflows: ['PR tests']
    types: [completed]

permissions:
  contents: read
  pull-requests: write

jobs:
  comment:
    if: github.event.workflow_run.event == 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - name: Download artifact from the source run
        uses: actions/download-artifact@v4
        with:
          name: pr-report
          run-id: ${{ github.event.workflow_run.id }}
          github-token: ${{ secrets.GITHUB_TOKEN }}
      - name: Post comment
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          REPO: ${{ github.repository }}
          CONCLUSION: ${{ github.event.workflow_run.conclusion }}
        run: |
          PR_NUMBER="$(cat pr_number.txt)"
          REPORT="$(cat report.txt)"
          BODY=$(printf 'CI finished with conclusion: **%s**\n\n```\n%s\n```\n' "$CONCLUSION" "$REPORT")
          gh pr comment "$PR_NUMBER" --repo "$REPO" --body "$BODY"
```

Puntos clave:

- Workflow 2 **nunca ejecuta código del PR** (ni siquiera `actions/checkout`).
- Los datos del PR vienen como **artefacto**, no como ejecución.
- Los secretos solo existen en workflow 2, que es trivial de auditar.

## Validación

```bash
bash validate.sh
```

El validador comprueba que:

- Los `.yml` del ejemplo son parseables.
- **Ningún** `.yml` con `pull_request_target` contiene `actions/checkout` apuntando al head del PR.
- El workflow etiquetador declara `permissions:` explícitas.
- El workflow de report usa `workflow_run` (no `pull_request_target` + checkout).

## Preguntas

1. ¿Por qué no basta con `if: github.event.pull_request.head.repo.fork == false` para "proteger" un `pull_request_target` con checkout?
2. ¿Qué pasa si editas `pr-test-and-report.yml` en una rama y abres un PR? ¿Qué YAML se ejecuta?
3. ¿Qué permisos mínimos necesita el workflow etiquetador?

(Respuestas: lección principal §7 y §8.)
