# Ejemplo 01 — `checkov -d .` sobre una carpeta Terraform

> Lectura y análisis. Objetivo: ver un escaneo real de Checkov sobre misconfigs clásicos y entender cómo se lee la salida.

## 1. Carpeta de ejemplo (HCL)

```hcl
# bad.tf — a propósito con 3 misconfigs clásicos
resource "aws_s3_bucket" "public_data" {
  bucket = "example-public-data"
  acl    = "public-read"            # CKV_AWS_20
}

resource "aws_iam_policy" "wide_open" {
  name   = "wide_open"
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = "*",                 # CKV_AWS_40 (wildcard action)
      Resource = "*"                  # CKV_AWS_1  (wildcard resource)
    }]
  })
}

resource "aws_security_group_rule" "ssh_from_world" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]   # CKV_AWS_24 (SSH abierto a Internet)
  security_group_id = "sg-xxxx"
}
```

> **No hay `terraform apply`.** Solo HCL en disco. Es exactamente lo que escanea `checkov -d .`.

## 2. Ejecutar

```bash
pip install checkov                    # una vez
cd /ruta/al/directorio/con/bad.tf
checkov -d . --framework terraform --compact
```

## 3. Salida (abreviada)

```
       _               _
   ___| |__   ___  ___| | _______   __
  / __| '_ \ / _ \/ __| |/ / _ \ \ / /
 | (__| | | |  __/ (__|   < (_) \ V /
  \___|_| |_|\___|\___|_|\_\___/ \_/

Check: CKV_AWS_20: "S3 Bucket has an ACL defined which allows public READ access."
  FAILED for resource: aws_s3_bucket.public_data
  File: /bad.tf:2-5
  Guide: https://docs.bridgecrew.io/docs/s3_1-acl-read-permissions-everyone

Check: CKV_AWS_40: "Ensure IAM policies does not allow full "*-" administrative privileges"
  FAILED for resource: aws_iam_policy.wide_open
  File: /bad.tf:8-18

Check: CKV_AWS_24: "Ensure no security groups allow ingress from 0.0.0.0:0 to port 22"
  FAILED for resource: aws_security_group_rule.ssh_from_world
  File: /bad.tf:20-27

Passed checks: 0, Failed checks: 3, Skipped checks: 0
```

## 4. Qué leer de la salida

- **ID (`CKV_AWS_*`)**: estable, úsalo en `skip-check`.
- **Recurso**: dirección Terraform (`aws_s3_bucket.public_data`), útil para el fix.
- **File:línea**: dónde ir.
- **Guide**: enlace a la explicación — leerlo **antes** de suprimir.

## 5. Supresión in-line vs global

In-line (recomendado para excepciones puntuales):

```hcl
#checkov:skip=CKV_AWS_20:bucket público intencional (static site). ADR-0007. expires 2026-06-01
resource "aws_s3_bucket" "static_site" { ... }
```

Global (en `.checkov.yaml`, para reglas que la org no acepta):

```yaml
skip-check:
  - CKV_AWS_79  # IMDSv1 todavía usado por una AMI legacy. ADR-0012.
```

Preferir **in-line** siempre que puedas: la excepción está donde está el riesgo.

## 6. Qué entrena este ejemplo

- Leer la salida de Checkov sin perderte.
- Distinguir "fix" vs "suprimir con razón" vs "falso positivo".
- Entender que los IDs (`CKV_AWS_*`) son el contrato estable.

## 7. Siguiente paso

- Ver `../02-trivy-config-k8s-manifests/` para la variante K8s.
- Ver `../03-checkov-on-plan-json/` para por qué el plan es más preciso.
