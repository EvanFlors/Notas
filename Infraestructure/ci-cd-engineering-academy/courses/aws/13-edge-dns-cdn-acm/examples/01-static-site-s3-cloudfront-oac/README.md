# Ejemplo 01 — Sitio estático en S3 servido por CloudFront con OAC

> Demostrativo. No se aplica contra AWS. Objetivo: leer la plantilla Terraform y el JSON de distribución, y entender las piezas mínimas que hacen posible "bucket privado + CDN público".

## 1. Pieza por pieza

```
   www.example.com
        │  (Alias A record en Route 53)
        ▼
   CloudFront distribution (viewer cert ACM us-east-1)
        │  (SigV4 con OAC)
        ▼
   S3 bucket privado (bucket policy permite solo esta distribución)
```

## 2. Plantilla Terraform (anotada)

Fichero `main.tf` ilustrativo — **no se ejecuta**. Las líneas comentadas con `# NOTE` explican *por qué* esa decisión.

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# NOTE: dos providers porque ACM para CloudFront DEBE estar en us-east-1,
# aunque el bucket y la zona vivan en eu-west-1.
provider "aws" {
  alias  = "euw1"
  region = "eu-west-1"
}

provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}

# ----------- S3 bucket privado -----------
resource "aws_s3_bucket" "site" {
  provider = aws.euw1
  bucket   = "example-static-site-demo"  # NOTE: nombre global; en real, usar prefijo con account id.
}

resource "aws_s3_bucket_public_access_block" "site" {
  provider                = aws.euw1
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ----------- OAC (reemplaza al legacy OAI) -----------
resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "oac-example-site"
  description                       = "OAC para example static site"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ----------- ACM cert en us-east-1 -----------
resource "aws_acm_certificate" "site" {
  provider          = aws.use1
  domain_name       = "www.example.com"
  validation_method = "DNS"

  subject_alternative_names = ["example.com"]

  lifecycle {
    create_before_destroy = true
  }
}

# ----------- Distribución CloudFront -----------
resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = ["www.example.com", "example.com"]
  price_class         = "PriceClass_100"  # NOTE: solo NA+EU, abarata ~40% si no sirves global.
  http_version        = "http2and3"       # NOTE: habilita HTTP/3 (QUIC) sin coste adicional.

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3-site"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
    # NOTE: SIN `s3_origin_config { origin_access_identity = ... }` — eso era OAI legacy.
  }

  default_cache_behavior {
    target_origin_id       = "s3-site"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    # Managed cache policy "CachingOptimized"
    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    # Managed origin request policy "CORS-S3Origin"
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf"
    # Managed response headers policy "SecurityHeadersPolicy"
    response_headers_policy_id = "67f7725c-6f97-4210-82d7-5512b31e9d03"
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.site.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

# ----------- Bucket policy restringido a esta distribución -----------
data "aws_iam_policy_document" "allow_cf" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
      # NOTE: SourceArn es lo que ancla el acceso a ESTA distribución y no a otra.
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  provider = aws.euw1
  bucket   = aws_s3_bucket.site.id
  policy   = data.aws_iam_policy_document.allow_cf.json
}
```

## 3. JSON de distribución (vista normalizada)

Un `terraform show -json` o un `aws cloudfront get-distribution` devuelven algo cercano a esto (recortado):

```json
{
  "DistributionConfig": {
    "Aliases": { "Quantity": 2, "Items": ["www.example.com", "example.com"] },
    "Origins": {
      "Quantity": 1,
      "Items": [
        {
          "Id": "s3-site",
          "DomainName": "example-static-site-demo.s3.eu-west-1.amazonaws.com",
          "OriginAccessControlId": "E1ABCDEF2GHIJ3",
          "S3OriginConfig": { "OriginAccessIdentity": "" }
        }
      ]
    },
    "DefaultCacheBehavior": {
      "TargetOriginId": "s3-site",
      "ViewerProtocolPolicy": "redirect-to-https",
      "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6",
      "OriginRequestPolicyId": "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf",
      "ResponseHeadersPolicyId": "67f7725c-6f97-4210-82d7-5512b31e9d03"
    },
    "CacheBehaviors": { "Quantity": 0 },
    "ViewerCertificate": {
      "ACMCertificateArn": "arn:aws:acm:us-east-1:123456789012:certificate/aaaa-bbbb",
      "SSLSupportMethod": "sni-only",
      "MinimumProtocolVersion": "TLSv1.2_2021"
    },
    "HttpVersion": "http2and3",
    "PriceClass": "PriceClass_100"
  }
}
```

Los campos clave que validarás estructuralmente en la actividad 01 son:

- `Aliases.Items` tiene al menos 1 FQDN.
- `Origins.Items[].OriginAccessControlId` existe y `S3OriginConfig.OriginAccessIdentity` está vacío (señal de que es OAC, no OAI).
- `DefaultCacheBehavior.ViewerProtocolPolicy == "redirect-to-https"`.
- `ViewerCertificate.ACMCertificateArn` empieza por `arn:aws:acm:us-east-1:` (región correcta).
- `ViewerCertificate.MinimumProtocolVersion` >= `TLSv1.2_2021`.

## 4. Qué no está aquí (y por qué)

- **No hay** `aws_route53_record` para el alias — la actividad 01 lo añade.
- **No hay** registros de validación DNS de ACM — la actividad 01 los diseña.
- **No hay** `aws_acm_certificate_validation` — depende de los records.
- **No se aplica**. `terraform init && terraform plan` es la demostración; `apply` provisionaría una zona Route 53 (coste 0.50 USD/mes), un cert ACM (gratis), y una distribución CloudFront (gratis hasta tráfico). El bucket es gratis hasta datos reales.

## 5. Costos si lo levantaras (que no vas a hacer)

| Recurso | Coste |
|---------|-------|
| Hosted zone Route 53 | **0.50 USD/mes** (prorrateado al día) |
| Queries Route 53 (alias a CloudFront) | 0 USD (no cobra alias interno) |
| ACM cert público | 0 USD |
| Distribución CloudFront | 0 USD si no hay tráfico |
| S3 bucket vacío | 0 USD |
| **Total ocioso** | ~0.50 USD/mes solo por la zona |

**Para esta academia: NO se aplica. Es `plan` y JSON validado.**
