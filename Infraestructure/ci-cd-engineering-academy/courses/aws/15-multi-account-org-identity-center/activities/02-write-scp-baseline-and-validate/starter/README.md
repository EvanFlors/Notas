# Starter — aws-15-02-write-scp-baseline-and-validate

Esta actividad es **independiente**: produces 3 archivos JSON + 1 Markdown.

## Pasos

1. Lee `../README.md` completo y recorre `../../examples/02-scp-anatomy/`.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/aws-15-scp
   cd /tmp/aws-15-scp
   ```
3. Escribe los 3 archivos SCP (nombres exactos):
   - `scp-deny-regions.json`
   - `scp-deny-leave-org.json`
   - `scp-deny-disable-logging.json`
4. Verifica que son JSON válidos:
   ```bash
   for f in scp-*.json; do echo "--- $f"; jq . "$f" >/dev/null && echo OK; done
   ```
5. Escribe `README-INTENT.md` con una sección por SCP (`## scp-deny-regions`, `## scp-deny-leave-org`, `## scp-deny-disable-logging`).
6. Valida:
   ```bash
   bash <ruta-repo>/courses/aws/15-multi-account-org-identity-center/activities/02-write-scp-baseline-and-validate/tests/validate.sh /tmp/aws-15-scp
   ```
7. Compara con `../solution/REFERENCE.md` para autoevaluarte.

## Esqueletos útiles

### Esqueleto genérico de SCP

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DescriptiveName",
      "Effect": "Deny",
      "Action": "service:Operation",
      "Resource": "*"
    }
  ]
}
```

### Esqueleto con Condition

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DescriptiveName",
      "Effect": "Deny",
      "NotAction": ["iam:*", "..."],
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:RequestedRegion": ["eu-west-1"]
        }
      }
    }
  ]
}
```

> El validador comprueba sintaxis y presencia de claves mínimas, **no** el effect en una cuenta real.
