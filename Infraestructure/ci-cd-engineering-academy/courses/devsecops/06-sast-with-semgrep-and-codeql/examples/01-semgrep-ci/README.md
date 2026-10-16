# Ejemplo 01 — Semgrep en CI con upload SARIF

> Lectura y análisis. Puedes ejecutar los comandos localmente si tienes `semgrep` instalado.

## Objetivo

Ver cómo se mete Semgrep en GitHub Actions con **tres pilares**:

1. `--config auto` (reglas del registry curadas por lenguaje detectado).
2. `--config .semgrep/` (reglas custom del repo).
3. `--sarif --output semgrep.sarif` → upload a Code Scanning.

## Estructura asumida

```
repo/
├── src/
│   └── app.py
├── .semgrep/
│   └── no-print.yml           # regla custom del equipo
└── .github/workflows/
    └── semgrep.yml
```

## El workflow completo

```yaml
# .github/workflows/semgrep.yml
name: Semgrep SAST
on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
  schedule:
    - cron: '17 3 * * 1'

jobs:
  semgrep:
    name: semgrep/scan
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write     # necesario para subir SARIF
    container:
      image: semgrep/semgrep:latest
    steps:
      - uses: actions/checkout@v4

      - name: Scan
        run: |
          semgrep scan \
            --config auto \
            --config .semgrep/ \
            --sarif --output semgrep.sarif \
            --error                        # exit 1 si hay ERRORES
        continue-on-error: true            # no abortar antes del upload

      - name: Upload SARIF
        if: always()
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: semgrep.sarif
          category: semgrep
```

### Notas

- `--error` hace `exit 1` **solo** si hay reglas con `severity: ERROR` disparadas.
- `continue-on-error: true` + `if: always()` garantiza que subimos SARIF aunque el scan falle; de otro modo perderíamos los findings en Code Scanning.
- `category: semgrep` separa visualmente los findings de Semgrep de los de CodeQL en la pestaña Security.

## Ejecución local equivalente

```bash
pip install semgrep
semgrep scan --config auto --config .semgrep/ --sarif --output semgrep.sarif .
```

Para "¿esto cambia algo si subo este PR?":

```bash
semgrep scan --config auto --baseline-ref origin/main
```

`--baseline-ref` reporta **solo** findings nuevos frente a esa ref. Útil para no romper PRs por deuda preexistente.

## Qué mirar en el resultado

- `semgrep.sarif` tiene estructura SARIF 2.1.0. Puedes visualizarlo con la extensión VS Code "SARIF viewer".
- En GitHub, el PR muestra findings como check annotations; la pestaña **Security → Code scanning alerts** lista el histórico.
- Los IDs de regla (`python.lang.security.audit.xxx`) corresponden al registry; los `no-print` provienen de `.semgrep/`.
