# Recursos — aws-13-edge-dns-cdn-acm

> Lectura dirigida. No es exhaustivo; es lo mínimo para completar el módulo con criterio.

## Oficial AWS

- Route 53 — Developer Guide: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/Welcome.html
- Route 53 — Routing policies: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy.html
- Route 53 Resolver (hybrid DNS): https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver.html
- ACM — User Guide: https://docs.aws.amazon.com/acm/latest/userguide/acm-overview.html
- ACM — DNS validation: https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html
- ACM region requirements (CloudFront en us-east-1): https://docs.aws.amazon.com/acm/latest/userguide/acm-regions.html
- CloudFront — Developer Guide: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/Introduction.html
- CloudFront — Cache behaviors y precedence: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/distribution-web-values-specify.html#DownloadDistValuesPathPattern
- CloudFront — Cache / Origin request / Response headers policies: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/working-with-policies.html
- CloudFront — Origin Access Control (OAC): https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html
- CloudFront — Signed URLs y Signed Cookies: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/PrivateContent.html
- CloudFront — Functions vs Lambda@Edge: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cloudfront-functions.html
- CloudFront — HTTP/3 (QUIC) support: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/distribution-web-values-specify.html
- WAF — Web ACL con CloudFront: https://docs.aws.amazon.com/waf/latest/developerguide/web-acl.html

## Pricing (verificar siempre contra la calculadora)

- Route 53 pricing: https://aws.amazon.com/route53/pricing/
- ACM pricing (ACM público gratis; PCA pagado): https://aws.amazon.com/certificate-manager/pricing/
- CloudFront pricing: https://aws.amazon.com/cloudfront/pricing/
- WAF pricing: https://aws.amazon.com/waf/pricing/
- AWS Pricing Calculator: https://calculator.aws/

## Terraform

- `aws_cloudfront_distribution`: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution
- `aws_cloudfront_origin_access_control`: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_origin_access_control
- `aws_acm_certificate` + `aws_acm_certificate_validation`: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate
- `aws_route53_zone` + `aws_route53_record`: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record

## Lectura complementaria

- "DNS and BIND" (Albitz & Liu) — para fundamentos de DNS si vienes flojo.
- RFC 8446 (TLS 1.3) — handshake moderno.
- "High Performance Browser Networking" (Ilya Grigorik) — capítulos de TLS, HTTP/2, HTTP/3; libre online.
- Blog post AWS "Enhanced domain protections for Amazon CloudFront requests" — por qué OAC y no origen público.
