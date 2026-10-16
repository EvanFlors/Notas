# Ejemplo 02 — CI con full-history scan

Workflow de GitHub Actions que escanea **toda la historia** del repo (no solo el PR actual) en cada push y pull request.

## Archivo del ejemplo

`.github/workflows/secret-scan.yml`:

```yaml
name: secret-scan

on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read

jobs:
  gitleaks:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout (full history, needed to scan all commits)
        uses: actions/checkout@v4
        with:
          fetch-depth: 0     # <-- clave: shallow checkout no vería commits viejos

      - name: Run gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          # GITLEAKS_LICENSE no se requiere para repos públicos
```

## Por qué `fetch-depth: 0`

`actions/checkout@v4` hace por defecto un shallow clone (profundidad 1 — solo el último commit). `gitleaks detect` sin historia escanearía solo ese commit, replicando el pre-commit sin ganar nada. Con `fetch-depth: 0` traes toda la historia y gitleaks la recorre con `git log -p`.

**Coste**: segundos de checkout extra en repos chicos; en repos muy grandes (>500 MB) considerar escanear solo desde la última rama "limpia" conocida (`gitleaks detect --log-opts="--since=2026-01-01"`).

## Qué hace gitleaks-action

- Baja gitleaks (versión fijada por la Action).
- Lee `.gitleaks.toml` si existe en el repo.
- Corre `gitleaks detect` sobre toda la historia disponible en el checkout.
- Si encuentra hallazgos: `exit 1` → el job falla → el PR queda bloqueado si el repo lo exige.
- Sube el reporte SARIF a la pestaña Security (Code Scanning Alerts) si tienes permiso.

## Comparación con trufflehog en CI

```yaml
      - name: Run trufflehog with verification
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          base: ${{ github.event.repository.default_branch }}
          head: HEAD
          extra_args: --only-verified
```

- `--only-verified`: solo reporta secretos que trufflehog pudo **validar contra el proveedor** (hace red egress). Casi cero FP, pero puede fallar si el runner está aislado o si el proveedor rate-limita.
- Patrón mixto: gitleaks en PR (barato), trufflehog `--only-verified` en main (más lento, pero reduce ruido).

## Qué chequear al terminar

- Que el workflow aparezca como requerido en la **branch protection** de `main`.
- Que un push de prueba con un secreto evidentemente falso (`AKIAFAKETEST000000`) **falle** el job (hacerlo en una rama tirar-y-quemar).
- Que las excepciones vivan en `.gitleaks.toml` y no en `--no-verify`.
