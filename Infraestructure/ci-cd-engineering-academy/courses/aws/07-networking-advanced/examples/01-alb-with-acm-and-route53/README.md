# Ejemplo 01 — ALB con ACM y Route 53 (publicación HTTPS con DNS)

> Lectura y análisis. **No se aplica.** Objetivo: fijar el patrón canónico de publicar una app en HTTPS con cert gestionado y DNS alias.

## 1. Topología

```
   Internet
      │
      ▼ (HTTPS 443)
   ┌─────────────────────┐
   │  Route 53            │ api.example.internal  ──alias──►  ALB DNS
   │  (zona pública)      │
   └─────────────────────┘
            │
            ▼
   ┌─────────────────────┐
   │  ALB (public subnets, multi-AZ)        │
   │   listener 443 (HTTPS)  cert = ACM     │
   │   listener 80 (HTTP) → redirect 443    │
   │   SG: allow 443/80 from 0.0.0.0/0       │
   └─────────────────────┘
            │  (HTTP a target 8080)
            ▼
   ┌─────────────────────┐
   │  Target Group (ip targets, port 8080)  │
   │  Health check: GET /healthz => 200     │
   └─────────────────────┘
            │
            ▼
   ┌─────────────────────┐
   │  App EC2 / ECS tasks (private subnets) │
   │  SG: allow 8080 from ALB SG            │
   └─────────────────────┘
```

Nota: el dominio `example.internal` es un **placeholder didáctico**, no un TLD real. En producción usarías un dominio que controles.

## 2. Fragmento Terraform (anotado, no copies literal)

```hcl
# ACM: cert para api.example.internal con validacion DNS automatica.
resource "aws_acm_certificate" "api" {
  domain_name       = "api.example.internal"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Route 53: CNAME que ACM necesita para validar el dominio.
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.api.domain_validation_options :
    dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id = aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.value]
  ttl     = 60
}

# Espera a que ACM confirme el DNS validation.
resource "aws_acm_certificate_validation" "api" {
  certificate_arn         = aws_acm_certificate.api.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# ALB en subnets publicas, multi-AZ.
resource "aws_lb" "api" {
  name               = "api-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false  # true en produccion real
  enable_cross_zone_load_balancing = true
}

resource "aws_lb_target_group" "api" {
  name        = "api-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/healthz"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Listener 443 con cert ACM. depende de la validacion.
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.api.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.api.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

# Listener 80 que redirige a 443 (no exponer HTTP en claro).
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.api.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Alias record: api.example.internal -> ALB DNS (sin coste de query).
resource "aws_route53_record" "api_alias" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.example.internal"
  type    = "A"

  alias {
    name                   = aws_lb.api.dns_name
    zone_id                = aws_lb.api.zone_id
    evaluate_target_health = true
  }
}
```

## 3. Puntos a leer con cuidado

1. **`for_each` sobre `domain_validation_options`**: ACM puede pedir varios CNAMEs si hay SANs. El patrón `for_each` cubre todos.
2. **`aws_acm_certificate_validation`** es un recurso *sin API real*: solo bloquea el grafo de Terraform hasta que ACM confirma. Es la pieza que evita la *race condition* entre crear el cert y asignarlo al listener.
3. **`ssl_policy`**: elige una policy moderna (TLS 1.2+/1.3). No uses las que incluyen SSLv3.
4. **`alias`** en vez de `CNAME`: imprescindible si el record vive en el apex de la zona; recomendado siempre para targets AWS.
5. **Listener 80 → redirect 301**: no sirvas HTTP en claro, pero no rompas clientes que llegan por error con `http://`.

## 4. Qué deberías notar que **no** está en el ejemplo

- **WAF**: `aws_wafv2_web_acl_association` para proteger la app a nivel L7.
- **Access logs** a S3: `access_logs { bucket = ... enabled = true }`.
- **Autenticación OIDC**: `authenticate_oidc` en la `default_action` del listener.
- **mTLS cliente**: `mutual_authentication` block en el listener 443.

Todo eso es extensión natural del patrón; se cubre en `aws-13` (edge) y en el módulo de seguridad web.
