# Ejemplo 01 — RDS Postgres multi-AZ en Terraform (lectura, no `apply`)

Este ejemplo **se lee**, no se ejecuta contra AWS. El objetivo es ver la forma de un `aws_db_instance` bien configurado y entender por qué cada atributo está donde está.

> **Nunca ejecutes `terraform apply` con credenciales reales desde este módulo.** Si quieres validar sintaxis, usa `terraform init && terraform plan -refresh=false` sin credenciales — fallará con un mensaje claro al pedirle que resuelva recursos reales, pero validará HCL.

## Snippet comentado

```hcl
# main.tf — Postgres 16 multi-AZ, encriptado, con IAM auth habilitada

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = "us-east-1"
  # No se configuran credentials: este archivo es ejemplo didactico.
}

# Subnet group: la DB se despliega en subnets privadas de >=2 AZs.
resource "aws_db_subnet_group" "pg" {
  name       = "example-pg-subnets"
  subnet_ids = var.private_subnet_ids # pasados por el modulo de VPC (aws-03).
}

# Security Group: inbound 5432 SOLO desde el SG de la aplicacion.
resource "aws_security_group" "pg" {
  name   = "example-pg-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.app_security_group_id] # NO cidr_blocks = ["0.0.0.0/0"].
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Parameter group: tunning minimo. Por ejemplo, logs de slow queries.
resource "aws_db_parameter_group" "pg16" {
  name   = "example-pg16-params"
  family = "postgres16"

  parameter {
    name  = "log_min_duration_statement"
    value = "500" # loguear queries > 500ms.
  }
}

# La instancia en si.
resource "aws_db_instance" "pg" {
  identifier     = "example-pg"
  engine         = "postgres"
  engine_version = "16.3"
  instance_class = "db.t4g.small" # Graviton, barato para dev.

  # Almacenamiento.
  allocated_storage     = 20
  max_allocated_storage = 100 # auto-scaling de disco.
  storage_type          = "gp3"
  storage_encrypted     = true          # OBLIGATORIO.
  kms_key_id            = var.kms_arn   # CMK propia (ver aws-09).

  # Red.
  db_subnet_group_name   = aws_db_subnet_group.pg.name
  vpc_security_group_ids = [aws_security_group.pg.id]
  publicly_accessible    = false # OBLIGATORIO: NUNCA true salvo lab aislado.

  # HA.
  multi_az = true # standby sincronico en otra AZ.

  # Auth.
  username                            = "admin"
  manage_master_user_password         = true # AWS crea secreto en Secrets Manager.
  iam_database_authentication_enabled = true # usuarios con IAM auth (ver seccion 3 de la leccion).

  # Backups.
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  skip_final_snapshot     = false
  final_snapshot_identifier = "example-pg-final-${formatdate("YYYYMMDD-hhmm", timestamp())}"
  deletion_protection     = true # EN PROD. En dev puede ser false.

  # Parameter group.
  parameter_group_name = aws_db_parameter_group.pg16.name

  # Monitoring.
  performance_insights_enabled    = true
  monitoring_interval             = 60 # Enhanced Monitoring cada 60s.
  monitoring_role_arn             = var.rds_monitoring_role_arn
  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = {
    Environment = "prod"
    Owner       = "data-platform"
  }
}

output "endpoint" {
  value       = aws_db_instance.pg.endpoint
  description = "App debe resolver este CNAME y reintentar en failover (DNS cambia)."
}
```

## Qué mirar

- **`multi_az = true`** — crea standby sincrónico. Doble costo, failover ~60–120 s.
- **`publicly_accessible = false`** — crítico. Un typo aquí expone la DB.
- **`storage_encrypted = true` + `kms_key_id`** — nunca uses la default `aws/rds` en prod; CMK propia permite rotación controlada.
- **`manage_master_user_password = true`** — AWS crea y rota el secreto en Secrets Manager automáticamente (ver `aws-09`).
- **`iam_database_authentication_enabled = true`** — habilita que apps con rol IAM pidan tokens; aún así tienes el password en Secrets Manager para accesos admin.
- **`deletion_protection = true`** — bloquea `terraform destroy` accidental. Hay que desactivarlo explícitamente antes de borrar.
- **`skip_final_snapshot = false`** — fuerza snapshot final; sin esto, borrar la DB es irreversible.

## Qué falta en este ejemplo (lo verás en otros módulos)

- Rotación personalizada del secreto más allá del default (`aws-09`).
- Read replicas y cross-region replica (ejercicio opcional de este módulo).
- Alarmas CloudWatch sobre `DatabaseConnections`, `CPUUtilization`, `ReplicaLag` (`aws-12`).

## No ejecutar

Si lo cargas en Terraform y haces `plan` con credenciales reales, intentará crear la DB. **El coste de una `db.t4g.small` multi-AZ con 20 GB corre ~30 USD/mes.** No lo apliques desde este curso.
