# REFERENCE — aws-03-01-provision-vpc-via-tf-module

> Una referencia razonada. No es la única respuesta correcta.

## main.tf de referencia

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "mock"
  secret_key                  = "mock"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}

locals {
  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnets  = ["10.0.0.0/24",  "10.0.16.0/24", "10.0.32.0/24"]
  private_subnets = ["10.0.1.0/24",  "10.0.17.0/24", "10.0.33.0/24"]
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "aws-03-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "aws-03-igw" }
}

resource "aws_subnet" "public" {
  count                   = length(local.public_subnets)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnets[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true
  tags = { Name = "public-${local.azs[count.index]}" }
}

resource "aws_subnet" "private" {
  count             = length(local.private_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnets[count.index]
  availability_zone = local.azs[count.index]
  tags = { Name = "private-${local.azs[count.index]}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "rt-public" }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count  = length(local.azs)
  vpc_id = aws_vpc.main.id
  tags   = { Name = "rt-private-${local.azs[count.index]}" }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id
  tags              = { Name = "s3-gw-endpoint" }
}
```

## DESIGN.md de referencia (esqueleto)

```
# DESIGN — aws-03-vpc-module

## CIDR

VPC: 10.0.0.0/16 -> 65 536 IPs totales.
Cada subnet /24 -> 256 IPs, menos 5 reservadas AWS -> 251 utilizables.

| Subnet          | CIDR         | AZ          | Hosts utilizables |
|-----------------|--------------|-------------|-------------------|
| public-a        | 10.0.0.0/24  | us-east-1a  | 251               |
| public-b        | 10.0.16.0/24 | us-east-1b  | 251               |
| public-c        | 10.0.32.0/24 | us-east-1c  | 251               |
| private-a       | 10.0.1.0/24  | us-east-1a  | 251               |
| private-b       | 10.0.17.0/24 | us-east-1b  | 251               |
| private-c       | 10.0.33.0/24 | us-east-1c  | 251               |

Dejamos huecos (10.0.4.0/24..10.0.15.0/24) para crecer en cada AZ /20.

## Diagrama

(ver topologia completa — public subnets -> rt-public -> IGW;
 private subnets -> rt-private-<az>; S3 Gateway endpoint asociado a las 3 RT privadas)

## Decisiones

1. Una RT privada por AZ para aislar impacto de fallos de NAT (aunque hoy no hay NAT, dejamos la estructura lista).
2. No se despliega NAT Gateway: la actividad es plan-only; en modulo futuro se parametriza.
3. S3 Gateway endpoint asociado a las 3 RT privadas: habilita el shortcut en todas las AZ y es gratis.
4. enable_dns_hostnames=true para permitir Interface endpoints con private DNS en el futuro.
```

## Puntos frecuentes de error

- Olvidar `vpc_endpoint_type = "Gateway"` (por defecto es "Gateway" para S3/Dynamo pero conviene ser explícito).
- Pasar al endpoint una sola RT en lugar de las 3 (las otras AZ seguirán sin shortcut).
- Olvidar `skip_credentials_validation=true` -> el `plan` falla llamando a STS.
- Añadir ruta `local` a mano en la RT (AWS la añade; Terraform fallará o la ignorará).
