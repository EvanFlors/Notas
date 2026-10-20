# Recursos — aws-07

Referencias oficiales y lecturas de apoyo. Verifica vigencia (precios y features cambian).

## Oficiales (AWS)

- **ELB (Application / Network / Gateway)**: `https://docs.aws.amazon.com/elasticloadbalancing/`
- **ALB docs**: `https://docs.aws.amazon.com/elasticloadbalancing/latest/application/`
- **NLB docs**: `https://docs.aws.amazon.com/elasticloadbalancing/latest/network/`
- **GWLB docs**: `https://docs.aws.amazon.com/elasticloadbalancing/latest/gateway/`
- **ACM (Certificate Manager)**: `https://docs.aws.amazon.com/acm/`
- **Route 53**: `https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/Welcome.html`
- **Routing policies**: `https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy.html`
- **VPC Peering**: `https://docs.aws.amazon.com/vpc/latest/peering/`
- **Transit Gateway**: `https://docs.aws.amazon.com/vpc/latest/tgw/`
- **Cloud WAN**: `https://docs.aws.amazon.com/network-manager/`
- **PrivateLink**: `https://docs.aws.amazon.com/vpc/latest/privatelink/`
- **AWS services that integrate with PrivateLink**: `https://docs.aws.amazon.com/vpc/latest/privatelink/aws-services-privatelink-support.html`
- **Network Firewall**: `https://docs.aws.amazon.com/network-firewall/`

## Pricing (verificar en el momento del cálculo)

- **ELB pricing**: `https://aws.amazon.com/elasticloadbalancing/pricing/`
- **NAT Gateway pricing**: `https://aws.amazon.com/vpc/pricing/`
- **PrivateLink pricing**: `https://aws.amazon.com/privatelink/pricing/`
- **Transit Gateway pricing**: `https://aws.amazon.com/transit-gateway/pricing/`
- **Route 53 pricing**: `https://aws.amazon.com/route53/pricing/`

## Terraform (AWS provider)

- `aws_lb`, `aws_lb_listener`, `aws_lb_target_group`, `aws_lb_target_group_attachment`
- `aws_acm_certificate`, `aws_acm_certificate_validation`
- `aws_route53_zone`, `aws_route53_record`
- `aws_vpc_endpoint_service`, `aws_vpc_endpoint` (type `Interface` / `Gateway`), `aws_vpc_endpoint_service_allowed_principal`
- `aws_ec2_transit_gateway`, `aws_ec2_transit_gateway_vpc_attachment`, `aws_ec2_transit_gateway_route_table`
- Provider docs: `https://registry.terraform.io/providers/hashicorp/aws/latest/docs`

## Lecturas de referencia

- "Amazon VPC Connectivity Options" (whitepaper AWS, buscar la última edición).
- "Hub-and-Spoke Networks with Transit Gateway" — AWS Architecture Blog.
- "Choosing between ALB and NLB" — AWS re:Invent talks NET301/NET401 (varias ediciones).
- Corey Quinn, "The Compelling Economics of AWS NAT Gateway" — contexto crítico sobre costes.

## Para el curso previo

- `courses/aws/03-vpc-basics/` — base indispensable (CIDRs, subnets, NAT, SG, Gateway Endpoints).
- `courses/aws/06-iam-advanced/` — útil para `allowed_principals` cross-account de PrivateLink.

## Checklist a verificar en Fase 4

- Precio actual de NAT Gateway, Interface Endpoint y TGW en tu región de referencia.
- Features recientes de ALB (mTLS cliente, nuevos listener rules).
- Soporte PrivateLink por servicio AWS (la lista crece cada quarter).
- Estado de **IPv6 only** en ALB/NLB (va cambiando).
