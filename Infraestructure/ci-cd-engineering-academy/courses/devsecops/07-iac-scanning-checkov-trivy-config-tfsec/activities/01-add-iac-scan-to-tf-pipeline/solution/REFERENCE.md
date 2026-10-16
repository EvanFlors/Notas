# REFERENCE — sec-07-01-add-iac-scan-to-tf-pipeline

> Una referencia razonada. No es la única respuesta correcta.

## scan.sh (resuelto)

El `scan.sh` del `starter/` ya es funcional (es un guided-lab, no un ejercicio de llenar huecos ciego). La solución es **leerlo** y entender por qué:

- **`set -eu`** sin `-o pipefail`: evita que `jq | grep` dispare SIGPIPE y lo contemos como fallo.
- **`checkov ... || true`** y **`trivy ... || true`**: los scanners devuelven exit code 1 cuando encuentran algo. Si no lo neutralizáramos, `set -e` cortaría el flujo antes de generar el reporte.
- **Degradación graciosa**: si `checkov` o `trivy` no están, escribimos `{}` y seguimos — el lab debe correr en una máquina de alumno sin tener todo instalado.
- **Allowlist**: `suppressions.csv` con `rule_id,reason,expires`. El script usa **solo el `rule_id`** para filtrar; la razón y la fecha quedan como auditoría humana.
- **Blocking logic**: cuenta solo `HIGH` y `CRITICAL`. `MEDIUM`/`LOW` van al reporte pero no fallan el build.

## suppressions.csv — ejemplo justificado

```csv
rule_id,reason,expires
CKV_AWS_24,SSH 0.0.0.0/0 temporal durante bootstrap - ticket SEC-123,2026-06-01
```

**Reglas de la casa**:

- Toda fila lleva razón **concreta** (no "funciona así") y **fecha**.
- Si una fila está más de 90 días sin fecha razonable, revisar.
- El `scan.sh` extendido (ver "Extensiones" del README) puede fallar automáticamente cuando una excepción expiró.

## REPORT.md esperado (abreviado, con todas las excepciones puestas)

```markdown
# IaC scan report

## Resumen

- Checkov activos (HIGH/CRITICAL): 0
- Trivy activos (HIGH/CRITICAL):   0
- Total bloqueantes:               0
- Total suprimidos:                3

## Checkov

| rule_id     | severity | resource                       | status     |
| CKV_AWS_20  | HIGH     | aws_s3_bucket_acl.public_data  | suppressed |
| CKV_AWS_1   | HIGH     | aws_iam_policy.wide_open       | suppressed |
| CKV_AWS_24  | HIGH     | aws_security_group.open_ssh    | suppressed |

## Trivy config

| rule_id       | severity | message                                      | status     |
| AVD-KSV-0014  | CRITICAL | Container 'app' should not be run as root    | active     |
| ...

## Suprimidos
...
```

(Los IDs y severidades exactas dependen de la versión instalada; usa esto como forma, no como verdad literal.)

## Decisiones clave

1. **¿Por qué CSV y no JSON?** Legible por humanos sin herramientas. Las revisiones de supresiones son humanas, no automatizadas.
2. **¿Por qué `HIGH`/`CRITICAL` como umbral y no `MEDIUM`?** Fallar en MEDIUM genera fatiga de alertas: los equipos empiezan a suprimir sin leer. El umbral correcto se calibra con la historia del repo.
3. **¿Por qué dos scanners (Checkov + Trivy)?** Segunda opinión. Cada uno tiene reglas que el otro no cubre. El coste operativo (segundos extra en CI) es trivial comparado con el valor de la señal cruzada.

## Si quieres ir más allá

- Añade `terraform init && terraform plan` (sin `apply`) y escanea el plan JSON — detecta regresiones por data sources.
- Añade `trivy config` sobre `terraform/` (sí, también soporta HCL) para la segunda opinión también en TF.
- Añade `tfsec` como tercera opinión si tenés el binario instalado.
- Sube el output SARIF a GitHub Code Scanning (`checkov -o sarif -o cli --output-file-path .`).
