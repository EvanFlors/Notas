# Recursos — aws-03

Referencias oficiales. Verificar vigencia en Fase 4 (los precios y nombres de servicio cambian).

## Oficiales (AWS docs)

- **VPC User Guide**: `https://docs.aws.amazon.com/vpc/latest/userguide/`
- **Subnets y CIDR**: `https://docs.aws.amazon.com/vpc/latest/userguide/configure-subnets.html`
- **Internet Gateway**: `https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html`
- **NAT Gateway (incluye precios)**: `https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html`
- **NAT Instance (alternativa)**: `https://docs.aws.amazon.com/vpc/latest/userguide/VPC_NAT_Instance.html`
- **Route tables**: `https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html`
- **Security Groups**: `https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html`
- **Network ACLs**: `https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html`
- **VPC endpoints**: `https://docs.aws.amazon.com/vpc/latest/privatelink/concepts.html`
- **Gateway endpoints (S3/DynamoDB)**: `https://docs.aws.amazon.com/vpc/latest/privatelink/gateway-endpoints.html`
- **Interface endpoints**: `https://docs.aws.amazon.com/vpc/latest/privatelink/create-interface-endpoint.html`
- **VPC peering**: `https://docs.aws.amazon.com/vpc/latest/peering/what-is-vpc-peering.html`

## Precios (verificar vigencia)

- **VPC pricing**: `https://aws.amazon.com/vpc/pricing/`
- **Data transfer pricing**: `https://aws.amazon.com/ec2/pricing/on-demand/#Data_Transfer`

## Terraform

- **AWS provider — VPC**: `https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc`
- **Módulo oficial terraform-aws-modules/vpc/aws**: `https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest`
- **tfsec / terrascan / checkov** (análisis estático de Terraform): `https://aquasecurity.github.io/tfsec/`

## Lecturas útiles

- "NAT Gateway costs demystified" — buscar artículo reciente en el blog de AWS o lastweekinaws.
- "VPC endpoints vs NAT Gateway cost comparison" — hay varias calculadoras y posts de la comunidad.
- CloudPosse: patrones de VPC multi-AZ en Terraform.

## Herramientas para calcular CIDR

- `ipcalc` (CLI): `ipcalc 10.0.0.0/16`
- `sipcalc` (CLI): más detallado.
- Online: subnet calculators varios; cuidado con los que no restan las 5 IPs reservadas de AWS.

## Checklist de verificación requerida en Fase 4

- Precio actual de NAT Gateway por hora y por GB en 2–3 regiones.
- Lista actual de servicios con Gateway endpoint (hoy: S3 y DynamoDB; verificar).
- Lista de regiones con disponibilidad de IPv6 egress-only internet gateway (para no mencionarlo mal).
- Versión actual del provider `hashicorp/aws` (constraint recomendado).
