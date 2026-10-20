# Ejemplo 02 — NLB con PrivateLink (productor + consumidor)

> Lectura y análisis. **No se aplica.** Objetivo: ver los dos lados de PrivateLink en Terraform y entender el modelo de permisos.

## 1. Topología

```
   Cuenta A (productor)                             Cuenta B (consumidor)
   ┌────────────────────────────────┐               ┌─────────────────────────────┐
   │  App (private subnets)         │               │  Cliente (private subnets)  │
   │   │                            │               │   │                         │
   │   ▼                            │               │   ▼                         │
   │  NLB (internal, multi-AZ)      │               │  Interface Endpoint (ENIs)  │
   │   │                            │   PrivateLink │   DNS: *.vpce.amazonaws     │
   │   ▼                            │   (red AWS    │                             │
   │  VPC Endpoint Service          │    interna,   │                             │
   │   allowed_principals = [       │    sin IGW    │                             │
   │     arn:aws:iam::<B>:root]     │    ni NAT)    │                             │
   │   acceptance_required = false  │               │                             │
   └────────────────────────────────┘               └─────────────────────────────┘
```

> `<B>` es un **placeholder**. En producción real, un AWS Account ID de 12 dígitos; aqui jamas pongas uno real.

## 2. Productor (cuenta A) — fragmento Terraform

```hcl
# NLB interno, en subnets privadas del productor.
resource "aws_lb" "svc" {
  name               = "svc-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = aws_subnet.private[*].id

  enable_cross_zone_load_balancing = true  # OJO: en NLB cobra inter-AZ
}

resource "aws_lb_target_group" "svc" {
  name        = "svc-tg"
  port        = 8080
  protocol    = "TCP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    protocol = "TCP"
    port     = "8080"
  }
}

resource "aws_lb_listener" "svc" {
  load_balancer_arn = aws_lb.svc.arn
  port              = 8080
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.svc.arn
  }
}

# El servicio de PrivateLink expone el NLB.
resource "aws_vpc_endpoint_service" "svc" {
  acceptance_required        = false  # conexion automatica
  network_load_balancer_arns = [aws_lb.svc.arn]

  # Nombres DNS verificados opcionales (requiere TXT record propio).
  # private_dns_name = "svc.example.internal"
}

# Lista blanca de principals: solo la cuenta B puede DESCUBRIR el servicio.
resource "aws_vpc_endpoint_service_allowed_principal" "consumer_b" {
  vpc_endpoint_service_id = aws_vpc_endpoint_service.svc.id
  principal_arn           = "arn:aws:iam::${var.consumer_account_id}:root"
}

output "service_name" {
  description = "DNS name a compartir con el consumidor."
  value       = aws_vpc_endpoint_service.svc.service_name
}
```

## 3. Consumidor (cuenta B) — fragmento Terraform

```hcl
# Interface Endpoint que consume el servicio publicado por A.
resource "aws_vpc_endpoint" "svc" {
  vpc_id              = aws_vpc.main.id
  service_name        = var.producer_service_name  # el output del productor
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpce.id]
  private_dns_enabled = false  # true solo si el productor verifico DNS

  tags = {
    Name = "svc-vpce"
  }
}

# SG del Interface Endpoint: solo acepta trafico desde la app cliente.
resource "aws_security_group" "vpce" {
  name   = "svc-vpce-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.client_app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

## 4. Puntos a leer con cuidado

1. **`acceptance_required = false`**: con `allowed_principals` ya controlas quién. Si lo pones `true`, cada nueva conexión aparece como `pendingAcceptance` y debe aceptarse manualmente — útil para servicios muy sensibles, molesto para muchos consumidores.
2. **`enable_cross_zone_load_balancing` en NLB**: por default `false`, y cobra inter-AZ cuando se activa. Para PrivateLink casi siempre se activa a sabiendas, para evitar que un consumidor en AZ-b dependa de que haya targets en AZ-b.
3. **`private_dns_enabled`**: si lo pones `true`, AWS override-ea el DNS para que `svc.example.internal` resuelva al Interface Endpoint. Requiere que el productor haya **verificado** el dominio en el `aws_vpc_endpoint_service` (TXT record). Si no lo verificaste, mantén `false` y usa el DNS `*.vpce.amazonaws.com` que te da AWS.
4. **No hay peering, ni TGW, ni IGW**: el tráfico cliente→ENI→AWS backbone→NLB productor nunca ve internet. Esto es la razón de usar PrivateLink en lugar de peering para "exponer un solo servicio".
5. **Cross-account**: `principal_arn = arn:aws:iam::<B>:root` autoriza la cuenta entera; puedes refinarlo a un rol concreto (`arn:aws:iam::<B>:role/consumer`).

## 5. Qué no vemos aquí

- **Múltiples consumidores**: `aws_vpc_endpoint_service_allowed_principal` admite `for_each` sobre una lista de ARNs.
- **Métricas CloudWatch** del Endpoint Service: `ActiveConnections`, `NewConnections`, `BytesProcessed` por VPCE — útil para capacity planning.
- **DNS verificado y nombre bonito**: requiere publicar un TXT record en tu zona y añadirlo al `aws_vpc_endpoint_service` (`private_dns_name` + verificación).

## 6. Por qué este patrón importa

- Reemplaza "peering + SG + ruta en route table" por **un recurso explícito con allowlist**.
- Es la base de cómo AWS mismo publica Interface Endpoints de sus servicios para tu subnet privada — por eso cuando creas un `aws_vpc_endpoint` tipo `Interface` para `secretsmanager`, lo que estás haciendo es consumir un Endpoint Service de AWS.
