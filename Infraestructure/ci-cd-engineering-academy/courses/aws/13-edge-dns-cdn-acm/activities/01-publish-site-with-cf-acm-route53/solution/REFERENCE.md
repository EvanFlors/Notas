# REFERENCE — aws-13-01-publish-site-with-cf-acm-route53

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

## Artefacto 1 — `main.tf` (modelo)

```hcl
terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  alias  = "euw1"
  region = "eu-west-1"
}

provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}

resource "aws_s3_bucket" "site" {
  provider = aws.euw1
  bucket   = "example-site-${var.account_id}"
}

resource "aws_s3_bucket_public_access_block" "site" {
  provider                = aws.euw1
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "oac-site"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_acm_certificate" "site" {
  provider          = aws.use1   # CloudFront exige ACM en us-east-1
  domain_name       = "www.example.com"
  validation_method = "DNS"
  subject_alternative_names = ["example.com"]
  lifecycle { create_before_destroy = true }
}

resource "aws_route53_zone" "primary" {
  provider = aws.euw1
  name     = "example.com"
}

resource "aws_route53_record" "www" {
  provider = aws.euw1
  zone_id  = aws_route53_zone.primary.zone_id
  name     = "www.example.com"
  type     = "A"
  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  aliases             = ["www.example.com", "example.com"]
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3-site"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-site"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
  }

  restrictions { geo_restriction { restriction_type = "none" } }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.site.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}
```

## Artefacto 2 — `distribution.json` (modelo)

```json
{
  "DistributionConfig": {
    "Aliases": { "Quantity": 2, "Items": ["www.example.com", "example.com"] },
    "Origins": {
      "Quantity": 1,
      "Items": [
        {
          "Id": "s3-site",
          "DomainName": "example-site.s3.eu-west-1.amazonaws.com",
          "OriginAccessControlId": "E1ABCDEF2GHIJ3",
          "S3OriginConfig": { "OriginAccessIdentity": "" }
        }
      ]
    },
    "DefaultCacheBehavior": {
      "TargetOriginId": "s3-site",
      "ViewerProtocolPolicy": "redirect-to-https",
      "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6"
    },
    "CacheBehaviors": { "Quantity": 0 },
    "ViewerCertificate": {
      "ACMCertificateArn": "arn:aws:acm:us-east-1:111111111111:certificate/aaaa-bbbb",
      "SSLSupportMethod": "sni-only",
      "MinimumProtocolVersion": "TLSv1.2_2021"
    },
    "HttpVersion": "http2and3",
    "PriceClass": "PriceClass_100"
  }
}
```

## Artefacto 3 — `ACM_DNS_WALKTHROUGH.md` (modelo)

El flujo típico:

1. Terraform aplica `aws_acm_certificate.site`. Estado inicial: **PENDING_VALIDATION**.
2. ACM devuelve, por cada FQDN (`www.example.com`, `example.com`), un **CNAME** de validación con `name` tipo `_abcd1234.www.example.com` y `value` tipo `_wxyz5678.acm-validations.aws`.
3. Terraform crea esos CNAME como `aws_route53_record` (uno por FQDN) a partir del output `domain_validation_options`.
4. ACM re-chequea los CNAME cada pocos minutos. En cuanto los encuentra, el cert pasa a **ISSUED**.
5. Un `aws_acm_certificate_validation` espera a `ISSUED` y desbloquea los recursos downstream (la distribución CloudFront no se crea hasta que el cert existe).

Después de la emisión, **no se borran** los CNAME de validación: ACM los re-usa en la **renovación automática** (cada ~13 meses). Si los borras, la próxima renovación fallará silenciosamente (vigila CloudWatch Events `ACM Certificate Approaching Expiration`).

## Artefacto 4 — `CACHE_ORDER_ADR.md` (modelo)

### Context

El sitio tiene cuatro tipos de rutas con requisitos distintos:

- `/api/*` — JSON dinámico desde ALB; no se puede cachear.
- `/private/*` — descargas firmadas desde S3 (OAC + signed cookies).
- `/static/*` — assets con hash en el nombre; long-TTL.
- default `*` — SPA (HTML entry point).

CloudFront evalúa `ordered_cache_behavior` **de arriba a abajo** y el primero que matchea gana. Esto obliga a ordenar de más específico a menos específico.

### Decision

Orden declarado:

1. `/api/*` → origin ALB, `CachingDisabled`, `AllViewer`.
2. `/private/*` → origin S3 (OAC), `CachingOptimized`, `trusted_key_groups = [...]`.
3. `/static/*` → origin S3 (OAC), `CachingOptimized`, `CORS-S3Origin`.
4. default `*` → origin S3 (OAC), `CachingOptimized`, con CloudFront Function de SPA fallback.

### Consequences

- Positivas: cada ruta recibe la policy correcta; `/api/*` nunca se envenena con cache; `/static/*` sirve del edge con TTL alto.
- Negativas: cuatro behaviors añaden complejidad; cambiar policies managed por custom requeriría tocar varios behaviors.
- **Gotcha**: si pusiéramos un `ordered_cache_behavior` con `path_pattern = "*"` **arriba**, se comería todo y las rutas específicas nunca se evaluarían. El catch-all es siempre el `default_cache_behavior`, no un `ordered` con `*`.

## Artefacto 5 — `COSTS.md` (modelo)

Coste real si se aplicara y se dejara ocioso:

- Hosted zone pública Route 53: **0.50 USD/mes** (prorrateada; coste persistente).
- Queries DNS vía alias record a CloudFront: 0 USD (alias interno no cobra).
- ACM certificate público: ACM es **gratis** (solo cobra PCA, que no usamos).
- Distribución CloudFront sin tráfico: 0 USD.
- Bucket S3 vacío: ~0 USD.

**Decisión: NO se aplica.** Este laboratorio es `terraform plan` + JSON estructurado + documentos. No se corre `terraform apply`, no se crea hosted zone real, no se incurre en coste. Si en algún momento se aplicara, el runbook de destrucción está en `theory/lesson.md` §9.
