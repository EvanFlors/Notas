# Ejemplo 01 — Bucket S3 seguro por default (Terraform anotado)

> Lectura y análisis. Este `.tf` no se aplica en el módulo (requeriría cuenta AWS). Objetivo: fijar los **9 recursos** que acompañan a `aws_s3_bucket` para tener un bucket defendible en producción.

## 1. Por qué 9 recursos y no 1

Antes de 2022, `aws_s3_bucket` tenía todos los settings inline. El provider v4 los **separó** en recursos independientes para que cada setting tenga su propia state entry y pueda importarse/modificarse por separado. El resultado: un bucket "serio" hoy es un **conjunto de ~9 recursos** que viven juntos.

## 2. Bloque completo anotado

```hcl
# ---------------------------------------------------------------------------
# 1. El bucket. Nombre explicito, global unique, bajo convencion.
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "reports" {
  bucket = "acme-prod-reports-us-east-1"

  tags = {
    env         = "prod"
    owner       = "data-platform"
    cost_center = "cc-4210"
  }
}

# ---------------------------------------------------------------------------
# 2. Ownership controls: ACLs OFF (default moderno). Resource-based solo.
# ---------------------------------------------------------------------------
resource "aws_s3_bucket_ownership_controls" "reports" {
  bucket = aws_s3_bucket.reports.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# ---------------------------------------------------------------------------
# 3. Block Public Access: 4/4 true. La red de seguridad.
# ---------------------------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "reports" {
  bucket                  = aws_s3_bucket.reports.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------------
# 4. Versioning: habilitado desde dia uno. Sin esto, no hay red ante borrados.
# ---------------------------------------------------------------------------
resource "aws_s3_bucket_versioning" "reports" {
  bucket = aws_s3_bucket.reports.id
  versioning_configuration {
    status = "Enabled"
  }
}

# ---------------------------------------------------------------------------
# 5. SSE-KMS con CMK propia + Bucket Key (reduce 99% requests a KMS).
# ---------------------------------------------------------------------------
resource "aws_s3_bucket_server_side_encryption_configuration" "reports" {
  bucket = aws_s3_bucket.reports.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.reports.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_kms_key" "reports" {
  description             = "CMK for acme-prod-reports bucket"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

# ---------------------------------------------------------------------------
# 6. Lifecycle: transitions + limpieza de versiones viejas + multipart aborts.
# ---------------------------------------------------------------------------
resource "aws_s3_bucket_lifecycle_configuration" "reports" {
  bucket = aws_s3_bucket.reports.id

  rule {
    id     = "tiering-and-cleanup"
    status = "Enabled"
    filter {
      prefix = ""
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 180
      storage_class = "DEEP_ARCHIVE"
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ---------------------------------------------------------------------------
# 7. Bucket policy minima: Deny insecure transport + Allow role concreto.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "reports" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.reports.arn,
      "${aws_s3_bucket.reports.arn}/*",
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid     = "AllowReaderRole"
    effect  = "Allow"
    actions = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.reports.arn}/public/*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::111111111111:role/report-reader"]
    }
  }
}

resource "aws_s3_bucket_policy" "reports" {
  bucket = aws_s3_bucket.reports.id
  policy = data.aws_iam_policy_document.reports.json
}
```

## 3. Lectura clave

- **9 recursos** (bucket + ownership + BPA + versioning + SSE + KMS key + lifecycle + policy document + policy). Pierdes uno, pierdes garantía.
- **`BucketOwnerEnforced`** y **BPA 4/4** son el "no se filtra por accidente".
- **`bucket_key_enabled = true`** es gratis y evita que la factura de KMS se dispare.
- **`DenyInsecureTransport`** va **antes** que cualquier `Allow`. Si un cliente intenta HTTP, se corta antes de evaluar lo demás.

## 4. Que harias distinto si fuera prod real

- Añadir **`aws_s3_bucket_logging`** apuntando a un bucket de logs separado.
- Añadir **`aws_s3_bucket_notification`** si vas a disparar lambdas / sqs.
- Si el bucket sirve a **sitio estatico publico**, no lo abras: montar **CloudFront + OAC** por delante (modulo `aws-13`).
- IDs de cuenta reales no van hardcoded: salen de `data.aws_caller_identity.current.account_id` o de variables.

## 5. Que NO probamos aqui

- Que terraform `plan`/`apply` corran: requiere credenciales reales. Las actividades usan **LocalStack** para ejercitar el equivalente dinamico (bucket + upload + lifecycle + policy via CLI/boto3).
