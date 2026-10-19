# Ejemplo 01 — VPC multi-AZ con Terraform (plan-only)

> Lectura y `terraform plan`. **No se aplica.** Objetivo: ver cómo se expresan en Terraform los conceptos de la lección y entender la salida del `plan`.

## 1. Topología objetivo

```
                           +----------------- VPC 10.0.0.0/16 -----------------+
                           |                                                   |
                           |  rt-public (0.0.0.0/0 -> igw)                     |
                           |   +-- public-a   10.0.0.0/24   (AZ-a)             |
                           |   +-- public-b   10.0.16.0/24  (AZ-b)             |
                           |   +-- public-c   10.0.32.0/24  (AZ-c)             |
                           |                                                   |
     Internet  <--- IGW ---+                                                   |
                           |  rt-private-a (0.0.0.0/0 -> nat-a)                |
                           |   +-- private-a 10.0.1.0/24                       |
                           |  rt-private-b (0.0.0.0/0 -> nat-b)                |
                           |   +-- private-b 10.0.17.0/24                      |
                           |  rt-private-c (0.0.0.0/0 -> nat-c)                |
                           |   +-- private-c 10.0.33.0/24                      |
                           |                                                   |
                           |  + S3 Gateway endpoint (gratis) asociado a        |
                           |    las 3 rt-private                               |
                           +---------------------------------------------------+
```

## 2. Terraform de referencia (ilustrativo, no se aplica)

Archivo `main.tf`:

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  access_key                  = "mock"
  secret_key                  = "mock"
}

locals {
  azs = ["us-east-1a", "us-east-1b", "us-east-1c"]

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

# S3 Gateway endpoint (gratis). NAT Gateway omitido a propósito en el
# ejemplo para no sugerir que se aplique.
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.us-east-1.s3"
  tags         = { Name = "s3-gw-endpoint" }
}
```

## 3. Cómo lo recorreríamos (sin aplicar)

```bash
mkdir -p /tmp/aws-03-ex01 && cd /tmp/aws-03-ex01
# Pega el main.tf anterior
terraform init -backend=false
terraform plan -out=plan.out      # No se ejecuta `apply`
terraform show -no-color plan.out | head -80
```

Qué mirar en la salida:

- `aws_vpc.main` con `cidr_block = "10.0.0.0/16"`.
- 3 `aws_subnet.public` + 3 `aws_subnet.private` con `availability_zone` distintos.
- 1 `aws_internet_gateway`.
- 1 `aws_route_table` pública con la ruta `0.0.0.0/0 -> igw`.
- `aws_vpc_endpoint.s3` tipo Gateway (el default).

## 4. Qué NO está (a propósito)

- **NAT Gateway**: lo omitimos porque cada hora cuesta. En las actividades planteamos que el estudiante lo *modele* en Terraform y lea el plan, sin aplicar.
- **Security Groups**: viven en el ejemplo 02.
- **Interface endpoints**: viven en la actividad 02.

## 5. Lecciones del plan

- La route pública se materializa como un solo recurso `aws_route_table` + 3 `aws_route_table_association`. Un patrón muy común es que la gente escriba 3 route tables públicas idénticas por error — una sola es suficiente.
- No ves nunca la ruta `local` (al CIDR de la VPC): AWS la añade sola. No la escribas en Terraform ni intentes borrarla.
- `enable_dns_hostnames = true` es imprescindible si vas a añadir Interface endpoints con private DNS después.

## 6. Limpieza

Nada que limpiar: no se aplicó.

```bash
rm -rf /tmp/aws-03-ex01
```
