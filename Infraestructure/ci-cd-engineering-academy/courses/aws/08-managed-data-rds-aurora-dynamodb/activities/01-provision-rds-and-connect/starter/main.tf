# starter/main.tf
# -----------------------------------------------------------------------------
# RDS Postgres multi-AZ — borrador recibido para auditoria.
# Tiene al menos UN hallazgo intencionado. Encuentralo antes de escribir
# el TOPOLOGY.md.
#
# IMPORTANTE: este archivo NO se aplica contra AWS. Solo se usa para:
#   1) terraform init  → descarga el provider
#   2) terraform plan  → valida HCL (fallara al pedir recursos reales).
#   3) auditoria manual.
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "private_subnet_ids"     { type = list(string) default = [] }
variable "vpc_id"                 { type = string      default = "" }
variable "app_security_group_id"  { type = string      default = "" }

resource "aws_db_subnet_group" "pg" {
  name       = "lab-pg-subnets"
  subnet_ids = var.private_subnet_ids
}

resource "aws_security_group" "pg" {
  name   = "lab-pg-sg"
  vpc_id = var.vpc_id

  # HALLAZGO INTENCIONADO: inbound abierto a toda la VPC (y potencialmente mas).
  # Reglas correctas usarian security_groups = [var.app_security_group_id].
  ingress {
    from_port   = 5432
    to_port     = 5432
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

resource "aws_db_instance" "pg" {
  identifier          = "lab-pg"
  engine              = "postgres"
  engine_version      = "16.3"
  instance_class      = "db.t4g.small"
  allocated_storage   = 20
  storage_type        = "gp3"
  storage_encrypted   = true

  db_subnet_group_name   = aws_db_subnet_group.pg.name
  vpc_security_group_ids = [aws_security_group.pg.id]

  publicly_accessible = false
  multi_az            = true

  username                    = "admin"
  manage_master_user_password = true

  # HALLAZGO potencial: faltan `deletion_protection`, `skip_final_snapshot`
  # y `iam_database_authentication_enabled`. Documentalos en TOPOLOGY.md.

  backup_retention_period = 7
}
