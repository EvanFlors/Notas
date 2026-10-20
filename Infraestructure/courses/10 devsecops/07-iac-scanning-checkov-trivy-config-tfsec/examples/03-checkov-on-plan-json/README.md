# Ejemplo 03 — Checkov sobre `terraform show -json tfplan`

> Lectura y análisis. Objetivo: ver con un caso concreto por qué escanear el **plan** detecta cosas que el HCL puro no.

## 1. HCL ambiguo

```hcl
# main.tf
variable "bucket_acl" {
  type        = string
  default     = "private"
  description = "ACL del bucket; private por defecto"
}

resource "aws_s3_bucket" "data" {
  bucket = "example-data"
  acl    = var.bucket_acl
}
```

Y en un `prod.tfvars`:

```hcl
# prod.tfvars
bucket_acl = "public-read"
```

## 2. Escanear solo HCL — señal débil

```bash
checkov -d .
```

Checkov ve `acl = var.bucket_acl`. El valor de la variable **puede** ser cualquier cosa. Para no inundar de falsos positivos, Checkov usa **el default** cuando puede resolverlo. En este caso leería `"private"` → **PASS**.

> El escaneo HCL **no sabe** que en producción el `.tfvars` lo pone en `public-read`. Falso negativo clásico.

## 3. Escanear el plan — señal fuerte

```bash
terraform init
terraform plan -var-file=prod.tfvars -out=tfplan.binary
terraform show -json tfplan.binary > tfplan.json

checkov -f tfplan.json
```

Ahora Checkov ve el **recurso resuelto**:

```json
{
  "address": "aws_s3_bucket.data",
  "type": "aws_s3_bucket",
  "values": {
    "acl": "public-read"
  }
}
```

→ dispara `CKV_AWS_20`. **FAIL**, como debe ser.

## 4. Otro caso: data sources

```hcl
data "aws_ami" "legacy" {
  owners      = ["self"]
  most_recent = true
  filter {
    name   = "name"
    values = ["company-base-*"]
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.legacy.id
  instance_type = "t3.micro"
  # imdsv1 permitido en la AMI → regresión invisible en HCL
}
```

El HCL no sabe qué AMI resolverá `data.aws_ami.legacy`. Si alguien publica una AMI nueva con metadatos inseguros (p. ej. IMDSv1 habilitado), el **plan lo verá** porque resolvió el data source. El HCL **no**.

## 5. Qué entrena este ejemplo

- Por qué `-f tfplan.json` reduce falsos positivos **y** detecta regresiones.
- Por qué los pipelines serios corren **ambos**: HCL en pre-commit (rápido) y plan en CI (preciso).
- Por qué los data sources son una categoría entera de regresiones que no se detectan sin plan.

## 6. Caveat operativo

- `terraform plan` requiere credenciales (incluso en dry-run) si hay `data` sources que las necesitan. En CI, usar **credenciales mínimas de solo lectura** vía OIDC/short-lived.
- El plan JSON puede contener **valores sensibles** (outputs, variables). No lo publiques como artefacto público sin sanear.

## 7. Siguiente paso

- Hacer la actividad `01-add-iac-scan-to-tf-pipeline/` que combina HCL + plan en un `scan.sh`.
