# Ejemplo 01 — Gates como contrato de plataforma

> Lectura y análisis. No se ejecuta.

Dos artefactos:

- `TEMPLATE.md` — plantilla textual del **contrato de gates**: qué bloquea, qué informa, qué corre nightly, con la política de severidad CVSS+EPSS+KEV y el formato de exception.
- `golden-path.yml` — pipeline GitHub Actions **de referencia** que compone secret-scan + SAST + SCA + IaC + SBOM + sign y **agrega los SARIFs** a GitHub Code Scanning (único panel).

## Cómo leer el workflow

- Cada job emite SARIF (`-f sarif`) a `./sarif/<tool>.sarif`.
- El job final `upload-sarif` usa `github/codeql-action/upload-sarif@v3` con `category: <tool>` para que cada herramienta aparezca separada en Code Scanning.
- Gates **bloqueantes** usan `--exit-code 1`.
- Gates **warn-only** usan `--exit-code 0` y confían en el panel SARIF para visibilidad.
- Las excepciones viven en `exceptions/*.yaml` (versionadas en git); los scanners las leen antes de fallar.

## Qué NO está en el workflow (deliberado)

- DAST: típicamente en entorno de staging, out-of-band.
- Nightly full-history secret scan: workflow separado con `schedule: cron`.
- Baseline rescan: workflow separado consumiendo el inventory store.

## Referencias cruzadas

- Política de severidad: ver `../../theory/lesson.md` §3.
- Exception policy: ver `../../theory/lesson.md` §4.
- SBOM store: ver `../02-sbom-inventory-store/`.
