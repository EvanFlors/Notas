# Ejemplo 02 — Checkov baseline

## Concepto que demuestra

- **Checkov** escanea HCL por patrones conocidos como inseguros (reglas `CKV_AWS_*`).
- Cómo tratar hallazgos: corregir, suprimir con `--skip-check` justificado, o aceptar como *baseline* temporal.

## Prerrequisitos

- `python3` + `pip install checkov` (o `brew install checkov`).

## Archivos

- `main.tf` — un bucket S3 **intencionalmente** sin encriptación ni versionado ni block-public-access.
- `.checkov.yaml` — config: formato de salida, severidad mínima, skip-list con comentarios.

## Ejecución

```bash
cd examples/02-checkov-baseline

# Scan completo
checkov -d . --framework terraform

# Formato compacto para CI
checkov -d . --framework terraform --compact --quiet
```

## Qué debes observar

- Checkov detecta al menos:
  - `CKV_AWS_18` (access logging)
  - `CKV_AWS_19` (encryption)
  - `CKV_AWS_21` (versioning)
  - `CKV2_AWS_6` (block public access)
- Cada hallazgo apunta a archivo y línea.

## Patrón de baseline

Primera vez que corrés checkov en un repo *existente* con misconfig acumulada, generás un **baseline** que lista los hallazgos actuales. CI falla solo si aparecen **nuevos** hallazgos:

```bash
checkov -d . --create-baseline
# genera .checkov.baseline
checkov -d . --baseline .checkov.baseline
# ahora pasa; cualquier nuevo hallazgo lo hará fallar
```

El baseline debe **reducirse con el tiempo** (ticket por cada entrada). No es un `.gitignore` eterno.

## Supresión in-line

```hcl
# checkov:skip=CKV_AWS_18:Logging opt-out: static website bucket, no PII
resource "aws_s3_bucket" "static" {
  bucket = "my-static-site"
}
```

El comentario **debe** justificar por qué.

## Limpieza

```bash
rm -f .checkov.baseline
```
