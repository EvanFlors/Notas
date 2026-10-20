# REFERENCE — aws-07-01-publish-app-with-alb-tls-dns

> Referencia razonada. No es la única respuesta correcta.

## Terraform (`main.tf` resumido)

```hcl
# VPC + dos subnets publicas en AZs distintas.
resource "aws_vpc" "main" {
  cidr_block           = "10.42.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "aws-07-alb-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = element(["us-east-1a", "us-east-1b"], count.index)
  map_public_ip_on_launch = true
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# SG del ALB: HTTPS/HTTP desde internet.
resource "aws_security_group" "alb" {
  name   = "alb-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Zona Route 53 (creada por el propio TF para el lab; en real usarias un data).
resource "aws_route53_zone" "main" {
  name = "example.internal"
}

# ACM: cert con DNS validation.
resource "aws_acm_certificate" "api" {
  domain_name       = "api.example.internal"
  validation_method = "DNS"
  lifecycle { create_before_destroy = true }
}

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

resource "aws_acm_certificate_validation" "api" {
  certificate_arn         = aws_acm_certificate.api.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# ALB.
resource "aws_lb" "api" {
  name               = "api-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
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

## DECISIONS.md (modelo)

```markdown
# DECISIONS — aws-07-01-publish-app-with-alb-tls-dns

## ADR-001: ALB vs NLB para esta API

- **Contexto:** API HTTP/JSON expuesta a internet. Necesitamos host/path routing para servir `/api/v1/*` y `/api/v2/*` desde el mismo nombre, con headers.
- **Decisión:** ALB.
- **Alternativas descartadas:** NLB (es L4, no entiende HTTP, no permite routing por path/host sin un proxy extra). GWLB (es para appliances, no para publicar apps).
- **Consecuencias:** sin IP fija (si manana un partner nos pide whitelist por IP, migramos a NLB-in-front-of-ALB). Ganamos features L7: WAF directo, OIDC, headers, access logs HTTP ricos.

## ADR-002: Validacion de ACM por DNS vs email

- **Contexto:** Terraform crea y renueva el cert. Queremos cero clics manuales.
- **Decision:** `validation_method = "DNS"` con CNAME creado por `aws_route53_record` y `aws_acm_certificate_validation` para esperar.
- **Alternativas descartadas:** `email` requiere acceso al buzon `admin@dominio`, que a) no siempre existe, b) es manual, c) se rompe en renovaciones.
- **Consecuencias:** la zona en Route 53 debe estar antes del cert; el apply se bloquea hasta que ACM ve el CNAME (~1-5 min). A cambio, las rotaciones son totalmente automaticas.

## ADR-003: Alias record vs CNAME para apuntar al ALB

- **Contexto:** `api.example.internal` apunta al ALB. El ALB cambia sus IPs periodicamente.
- **Decision:** `aws_route53_record` tipo `A` con bloque `alias`.
- **Alternativas descartadas:** CNAME manual (no permitido en el apex de la zona; aunque aqui es un subdominio y seria legal, perderiamos la actualizacion automatica de IPs y pagariamos queries). ELB con IP estatica (ALB no tiene IP estatica; eso es NLB).
- **Consecuencias:** apex-compatible, gratis, auto-actualizado. Nos ata a Route 53 (si migramos de DNS, hay que recrear como CNAME).
```

## Checklist conceptual

- [ ] Mencionaste `aws_acm_certificate_validation` como el "guardián" que evita la race condition.
- [ ] El listener 443 referencia **el output del validation**, no el cert directo.
- [ ] El 80 hace redirect 301 (no 302 ni 307 — queremos cacheable para SEO y UA).
- [ ] `enable_cross_zone_load_balancing = true` (gratis en ALB).
- [ ] `evaluate_target_health = true` en el alias (si todos los targets están unhealthy, Route 53 lo marca, útil para failover con secundario).
- [ ] Ningún Account ID real, ningún dominio real, ningún secreto.
