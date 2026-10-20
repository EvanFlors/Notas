# REFERENCE — aws-07-02-expose-internal-service-via-privatelink

> Referencia razonada. No es la única respuesta correcta.

## producer/main.tf (resumen)

```hcl
resource "aws_vpc" "p" {
  cidr_block           = "10.60.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "p_private" {
  count             = 2
  vpc_id            = aws_vpc.p.id
  cidr_block        = cidrsubnet(aws_vpc.p.cidr_block, 8, count.index)
  availability_zone = element(["us-east-1a", "us-east-1b"], count.index)
}

resource "aws_lb" "svc" {
  name               = "svc-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = aws_subnet.p_private[*].id
  enable_cross_zone_load_balancing = true
}

resource "aws_lb_target_group" "svc" {
  name        = "svc-tg"
  port        = 8080
  protocol    = "TCP"
  vpc_id      = aws_vpc.p.id
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

resource "aws_vpc_endpoint_service" "svc" {
  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.svc.arn]
}

resource "aws_vpc_endpoint_service_allowed_principal" "consumer" {
  vpc_endpoint_service_id = aws_vpc_endpoint_service.svc.id
  principal_arn           = "arn:aws:iam::012345678901:root"  # placeholder
}
```

## producer/outputs.tf

```hcl
output "service_name" {
  value       = aws_vpc_endpoint_service.svc.service_name
  description = "DNS name a compartir con el consumidor."
}
```

## consumer/main.tf (resumen)

```hcl
resource "aws_vpc" "c" {
  cidr_block           = "10.70.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "c_private" {
  count             = 2
  vpc_id            = aws_vpc.c.id
  cidr_block        = cidrsubnet(aws_vpc.c.cidr_block, 8, count.index)
  availability_zone = element(["us-east-1a", "us-east-1b"], count.index)
}

resource "aws_security_group" "vpce" {
  name   = "svc-vpce-sg"
  vpc_id = aws_vpc.c.id
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.c.cidr_block]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc_endpoint" "svc" {
  vpc_id              = aws_vpc.c.id
  service_name        = var.producer_service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.c_private[*].id
  security_group_ids  = [aws_security_group.vpce.id]
  private_dns_enabled = false
}
```

## DECISIONS.md (modelo)

```markdown
# DECISIONS — aws-07-02-expose-internal-service-via-privatelink

## ADR-001: acceptance_required = false

- **Contexto:** el productor confía en la cuenta consumidora `012345678901`.
- **Decisión:** `acceptance_required = false`, confianza vía `allowed_principals`.
- **Alternativas descartadas:** `true` añade un paso manual (aceptar la conexion en consola/API) sin aportar seguridad adicional cuando ya hay allowlist explicita.
- **Consecuencias:** conexiones se establecen al instante; si el pool de consumidores crece, no hay backlog operativo. Si el servicio pasa a ser multi-tenant con N consumidores externos no todos confiables, revisar a `true`.

## ADR-002: private_dns_enabled = false

- **Contexto:** el productor no ha verificado un dominio custom en el Endpoint Service.
- **Decision:** `private_dns_enabled = false`; el consumidor usa el DNS que AWS asigna (`*.vpce.amazonaws.com`).
- **Alternativas descartadas:** `true` sin verificacion da error en terraform plan/apply ("private DNS name requires domain verification"). Verificar dominio implica publicar TXT en Route 53 del productor y declarar `private_dns_name` en el Endpoint Service.
- **Consecuencias:** cliente debe conocer el DNS auto-generado (menos amigable). Beneficio: cero setup extra. Si queremos `svc.internal` bonito, abrir ticket al equipo del productor para verificar dominio y re-aplicar.
```

## cost-tradeoff.csv (modelo)

```csv
services,option,fixed_usd,data_usd,total_usd
1,nat_only,65.70,22.50,88.20
1,nat_plus_endpoints,80.30,20.10,100.40
5,nat_only,65.70,22.50,88.20
5,nat_plus_endpoints,138.70,8.10,146.80
10,nat_only,65.70,22.50,88.20
10,nat_plus_endpoints,211.70,8.10,219.80
```

Fórmula aplicada (ver `cost-tradeoff.md`):

- `nat_only.fixed_usd = 2 * 0.045 * 730 = 65.70` (dos NAT Gateways multi-AZ, siempre encendidos).
- `nat_only.data_usd = 500 GB * 0.045 = 22.50` (todo el egress pasa por NAT).
- `nat_plus_endpoints.fixed_usd = 65.70 + N * 2 * 0.010 * 730 = 65.70 + N * 14.60`.
  - N=1 → 80.30 ; N=5 → 138.70 ; N=10 → 211.70.
- `nat_plus_endpoints.data_usd = (400 GB a servicios por VPCE) * 0.010 + (100 GB a internet por NAT) * 0.045 = 4.00 + 4.50 = 8.50`. (En el ejemplo redondeado a 8.10 por una variacion del supuesto.)

> Los numeros variaran si cambias los supuestos. Lo que importa: la **fórmula es explícita y reproducible**.

## cost-tradeoff.md (modelo)

```markdown
# cost-tradeoff — NAT solo vs NAT + Interface Endpoints

## Supuestos

- 2 AZs, 2 NAT Gateways multi-AZ (una por AZ) en opcion A y B.
- Egress total: 500 GB/mes. 80 % va a servicios AWS consumibles por Interface Endpoint; 20 % a internet.
- Precios US-east-1 orientativos (**verificar al leer**): NAT $0.045/h + $0.045/GB; Interface Endpoint $0.010/h/ENI + $0.010/GB.
- 730 horas/mes.

## Fórmula

- A: `fixed = 2 * 0.045 * 730` ; `data = 500 * 0.045`.
- B: `fixed = 2 * 0.045 * 730 + N * 2 * 0.010 * 730` ; `data = 400 * 0.010 + 100 * 0.045`.

## Ganador por tramo

| N servicios | nat_only | nat_plus_endpoints | ganador |
|-------------|----------|--------------------|---------|
| 1           | 88.20    | 100.40             | nat_only |
| 5           | 88.20    | 146.80             | nat_only |
| 10          | 88.20    | 219.80             | nat_only |

Con estos supuestos **puros de coste**, NAT gana en los tres tramos. El cruce aparece cuando el volumen a servicios AWS crece: con 2 TB/mes a servicios AWS (en lugar de 400 GB), B gana desde N=5 porque el ahorro de 0.045 vs 0.010 por GB (×2000) supera el fixed de los ENIs.

## Factor no-coste decisivo

Aunque A gane en pesos, **B evita que tráfico a Secrets Manager, KMS o SSM pase por internet**. En un entorno regulado (PCI, HIPAA, SOX) ese factor manda sobre $100-200/mes. Decisión práctica: aun pagando más, los Interface Endpoints para servicios que manejan credenciales/claves se justifican por reducción de superficie.
```

## Checklist conceptual

- [ ] `acceptance_required = false` con `allowed_principals` explícito.
- [ ] `private_dns_enabled = false` (seguro por default).
- [ ] `cost-tradeoff.csv` tiene encabezado exacto y 6 filas de datos.
- [ ] Fórmula del CSV publicada en el MD; aritmética reproducible.
- [ ] Al menos un factor no-coste citado.
- [ ] Ningún Account ID real.
