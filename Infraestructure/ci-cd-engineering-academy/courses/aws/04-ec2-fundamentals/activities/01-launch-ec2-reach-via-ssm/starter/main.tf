terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region

  # LAB MODE: no vamos a aplicar realmente. Estas banderas permiten que
  # `terraform validate` y `terraform plan` corran sin credenciales reales.
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  default_tags {
    tags = {
      Module  = "aws-04"
      Owner   = "aws-04"
      Project = "ci-cd-engineering-academy"
    }
  }
}

# -----------------------------------------------------------------------------
# TODO 1 — Resolver AMI dinamicamente via SSM Parameter Store.
# Rellena `name` con la ruta publica de la AMI Amazon Linux 2023 arm64:
#   /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-arm64
# (o x86_64 si prefieres t3.small en vez de t4g.small)
# -----------------------------------------------------------------------------
data "aws_ssm_parameter" "al2023" {
  name = "" # TODO: completa aqui
}

# -----------------------------------------------------------------------------
# TODO 2 — Trust policy del rol: solo el servicio EC2 puede asumirlo.
# Debe ser un statement con:
#   actions    = ["sts:AssumeRole"]
#   principals.type        = "Service"
#   principals.identifiers = ["ec2.amazonaws.com"]
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "ec2_trust" {
  statement {
    # TODO
  }
}

resource "aws_iam_role" "ec2_ssm" {
  name               = "${var.name_prefix}-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

# -----------------------------------------------------------------------------
# TODO 3 — Adjuntar la managed policy AmazonSSMManagedInstanceCore al rol.
# policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
# -----------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "" # TODO
}

# -----------------------------------------------------------------------------
# TODO 4 — Instance profile que envuelve el rol.
# -----------------------------------------------------------------------------
resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "${var.name_prefix}-profile"
  role = "" # TODO: aws_iam_role.ec2_ssm.name
}

# -----------------------------------------------------------------------------
# TODO 5 — Security Group:
#   * NINGUN bloque `ingress` (es una EC2 solo-SSM, no debe recibir trafico entrante).
#   * Un bloque `egress` para HTTPS 443 TCP a 0.0.0.0/0 (asi el agente SSM
#     puede llegar a los endpoints del servicio).
# -----------------------------------------------------------------------------
resource "aws_security_group" "ec2_private" {
  name        = "${var.name_prefix}-sg"
  description = "No ingress. Egress 443 only."
  vpc_id      = var.vpc_id

  # TODO: egress 443/tcp a 0.0.0.0/0
}

# -----------------------------------------------------------------------------
# TODO 6 — EC2 instance.
# Reglas:
#   * ami              = data.aws_ssm_parameter.al2023.value
#   * instance_type    = "t4g.small"   (o "t3.small" si usaste el AMI x86)
#   * subnet_id        = var.private_subnet_id
#   * vpc_security_group_ids = [aws_security_group.ec2_private.id]
#   * iam_instance_profile   = aws_iam_instance_profile.ec2_ssm.name
#   * associate_public_ip_address = false
#   * NO key_name (no vamos a SSH)
#   * user_data = file("${path.module}/user-data.sh")
#   * metadata_options:
#       http_endpoint               = "enabled"
#       http_tokens                 = "required"
#       http_put_response_hop_limit = 1
#       instance_metadata_tags      = "enabled"
#   * tags: Name, Environment, Owner
# -----------------------------------------------------------------------------
resource "aws_instance" "app" {
  # TODO: completa
  ami           = ""
  instance_type = ""

  tags = {
    Name = "" # TODO
  }
}
