# Ejemplo 02 — Aurora Postgres Serverless v2 (lectura, no `apply`)

Cluster Aurora Postgres con capacidad **Serverless v2**: escala por **ACUs** (Aurora Capacity Units) entre un mínimo y un máximo, sin instancia fija.

## Snippet comentado

```hcl
# Cluster Aurora Postgres Serverless v2.
resource "aws_rds_cluster" "aurora" {
  cluster_identifier     = "example-aurora-sv2"
  engine                 = "aurora-postgresql"
  engine_version         = "15.4"
  engine_mode            = "provisioned" # Serverless v2 usa "provisioned", NO "serverless".
  database_name          = "appdb"
  master_username        = "admin"
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.aurora.name
  vpc_security_group_ids = [aws_security_group.aurora.id]
  storage_encrypted      = true
  kms_key_id             = var.kms_arn

  backup_retention_period     = 7
  preferred_backup_window     = "03:00-04:00"
  deletion_protection         = true
  skip_final_snapshot         = false
  final_snapshot_identifier   = "example-aurora-final"

  # El contrato Serverless v2: rango de ACUs.
  serverlessv2_scaling_configuration {
    min_capacity = 0.5 # minimo absoluto (0.5 ACU = 1 GB RAM).
    max_capacity = 16  # tope de escalado.
  }
}

# Instancia(s) del cluster. Para Serverless v2 el instance_class fijo es "db.serverless".
resource "aws_rds_cluster_instance" "writer" {
  identifier         = "example-aurora-writer"
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version
  publicly_accessible = false
}

# Reader opcional en otra AZ para offload de lectura.
resource "aws_rds_cluster_instance" "reader" {
  identifier         = "example-aurora-reader-1"
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version
  publicly_accessible = false
}

output "writer_endpoint" {
  value = aws_rds_cluster.aurora.endpoint          # para writes.
}

output "reader_endpoint" {
  value = aws_rds_cluster.aurora.reader_endpoint   # DNS round-robin entre readers.
}
```

## Qué mirar

- **`engine_mode = "provisioned"`**: Serverless v2 vive bajo "provisioned". El Serverless v1 (`"serverless"`) es legacy, no lo uses.
- **`serverlessv2_scaling_configuration`**: define el rango. `0.5 → 16` ACUs es un rango razonable para SaaS con tenants dormidos; para prod con base alta, considera `min_capacity = 2` para evitar cold-ish starts.
- **Dos endpoints**: `endpoint` (writer) y `reader_endpoint` (round-robin DNS entre readers). La aplicación **debe** usar `reader_endpoint` para queries SELECT; usar `endpoint` para todo malgasta writers.
- **Un reader no es "backup".** Si cae la AZ del writer, Aurora promueve un reader (si hay) en < 30 s. Sin readers, el failover crea uno nuevo (~1 min).

## Costos a considerar

- **Pagas por ACU-hora**. 1 ACU ≈ 2 GB RAM. Si tu min son 0.5 ACU y nunca duerme totalmente, pagas ~0.5 × 24 × 30 × $0.12 ≈ 43 USD/mes **por instancia**. Dos instancias (writer + reader) = ~86 USD base + escalado.
- **Storage** pagado por GB-mes usado, no por GB provisionado.
- **I/O** cuesta por request. Para workloads con mucho I/O, Aurora Standard (precio I/O por operación) puede costar más que **Aurora I/O-Optimized** (precio fijo mayor pero I/O gratis). Decisión aparte.

## Cuándo preferir vs RDS

- **Preferir Aurora Serverless v2 sobre RDS multi-AZ**: carga impredecible, equipo pequeño, no quieres dimensionar.
- **Preferir RDS multi-AZ sobre Aurora**: carga constante y predecible, presupuesto ajustado, no necesitas > 1 réplica, equipo cómodo con `pg_dump` clásico.
- **Preferir Aurora provisioned (no Serverless) sobre Serverless v2**: carga constante conocida y alta — las instancias reservadas (RI) salen ~40 % más baratas que Serverless.

## No ejecutar

Igual que el ejemplo 01: léelo, no lo apliques. Un cluster Aurora Serverless v2 corriendo a 0.5 ACU 24/7 con 2 instancias cuesta ~90 USD/mes.
