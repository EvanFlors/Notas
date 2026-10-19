# REFERENCE — aws-08-01-provision-rds-and-connect

> Una referencia razonada. No es la única respuesta correcta; es un modelo contra el que compararte.

## A — Hallazgos de la auditoría

### Hallazgo 1 — Security Group abierto al mundo

```hcl
ingress {
  from_port   = 5432
  to_port     = 5432
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]   # <-- MAL
}
```

- **Qué está mal:** permite tráfico 5432 desde cualquier IP. Aunque `publicly_accessible = false` evita que la DB tenga IP pública, dentro de la VPC/peering/VPN cualquier cliente puede intentar conectarse si gana acceso a la red. Es defensa en profundidad rota.
- **Impacto:** si un pod comprometido o un attacker con acceso a la VPN consigue credenciales, la DB está alcanzable. También dispara findings de Config/Security Hub.
- **Fix:**
  ```hcl
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.app_security_group_id]
  }
  ```

### Hallazgo 2 — Falta `deletion_protection`

- **Qué está mal:** sin `deletion_protection = true`, un `terraform destroy` o un click en consola borran la DB.
- **Impacto:** pérdida total del dato en segundos. En prod es un incidente catastrófico.
- **Fix:** `deletion_protection = true` en el bloque `aws_db_instance`.

### Hallazgo 3 — Falta `skip_final_snapshot = false` + `final_snapshot_identifier`

- **Qué está mal:** por defecto `skip_final_snapshot = false`, lo que crearía snapshot final — pero sin `final_snapshot_identifier` Terraform falla. Falta la pareja completa.
- **Impacto:** o no se crea backup final, o el destroy falla a mitad y deja estado inconsistente.
- **Fix:**
  ```hcl
  skip_final_snapshot       = false
  final_snapshot_identifier = "lab-pg-final-${formatdate("YYYYMMDD-hhmm", timestamp())}"
  ```

### Hallazgo 4 — Falta `iam_database_authentication_enabled`

- No es crítico de seguridad, pero cerrar la puerta a IAM auth implica depender siempre de Secrets Manager / passwords. Habilitarlo es gratis.
- **Fix:** `iam_database_authentication_enabled = true`.

## B — ADR de topología

### B.1 Multi-AZ sí

Para prod OLTP: **sí, multi-AZ**. RPO ≈ 0 (replicación sincrónica), RTO ~60–120 s (DNS CNAME flip al standby). El 2× del coste es asumible frente a la caída total de una AZ (que ocurre varias veces al año en us-east-1).

### B.2 Read replicas

Depende del patrón de lectura:

- Si la app es write-mostly (~ 90 % writes) → **ninguna réplica**, el primario basta.
- Si hay un dashboard o reportes que agregan sobre la DB → **1 read replica** dedicada a esos clientes, con driver que la elija por connection string.

### B.3 Cross-region read replica

**No** para este workload asumido (CRM interno, 1 región). Alternativa de DR razonable: snapshot copy diario a otra región. Si el negocio exige RTO regional < 1 h, entonces sí; evaluar también Aurora Global Database.

### B.4 Backup retention

- **7 días** por defecto es suficiente para rollback táctico.
- Snapshot manual mensual retenido 1 año para compliance.
- PITR activo automáticamente al tener `backup_retention_period > 0`.

## C — Esquema SQL local

DDL de referencia (puedes guardarlo también como `/tmp/aws-08-rds/schema.sql`):

```sql
CREATE TABLE users (
  id         bigserial PRIMARY KEY,
  email      text UNIQUE NOT NULL,
  name       text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE orders (
  id         bigserial PRIMARY KEY,
  user_id    bigint NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  status     text NOT NULL CHECK (status IN ('pending', 'paid', 'shipped', 'cancelled')),
  total_cts  bigint NOT NULL CHECK (total_cts >= 0),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE order_items (
  order_id   bigint NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  sku        text NOT NULL,
  qty        integer NOT NULL CHECK (qty > 0),
  price_cts  bigint NOT NULL CHECK (price_cts >= 0),
  PRIMARY KEY (order_id, sku)
);

CREATE INDEX orders_user_created_idx ON orders (user_id, created_at DESC);
```

**Justificación del índice `(user_id, created_at DESC)`**:

- La query canónica es `WHERE user_id = ? ORDER BY created_at DESC`. Un índice compuesto en ese orden exacto permite que Postgres haga **Index Scan** sirviendo el `ORDER BY` sin sort adicional.
- Un índice sólo sobre `user_id` obligaría a leer todas las órdenes del usuario y ordenarlas en memoria → caro cuando hay miles.
- Dos índices separados (`user_id`, `created_at`) desperdiciarían espacio y Postgres no los combinaría eficientemente para esta query.
- Si llegara un patrón `WHERE user_id = ? AND status = ?`, consideraría añadir `(user_id, status, created_at DESC)` — pero sólo si el patrón es frecuente, nunca por si acaso.

## D — Conexión segura

- Puerto: **5432** (Postgres default).
- Fuente permitida: **SG de la app** (`security_groups = [sg-app]`), **nunca** `cidr_blocks = ["0.0.0.0/0"]` ni el CIDR entero de la VPC.
- `publicly_accessible = false` no basta: evita IP pública, pero no segmenta el tráfico interno. Combinación correcta = SG estrecho + no público + subnet privada.
- **IAM auth** para la aplicación con rol IAM (los pods de EKS vía IRSA, por ejemplo). Tokens de 15 min, sin password que leaquear.
- **Secrets Manager** para el password admin (con rotación cada 30 días) y para accesos humanos de emergencia. Los dos esquemas conviven: IAM auth para la app, Secrets Manager para humanos.
