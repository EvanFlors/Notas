# Actividad 01 — RDS Postgres multi-AZ (plan + Postgres local) y ADR

## 1. Identificación

- **ID:** `aws-08-01-provision-rds-and-connect`
- **Tecnología:** `aws`
- **Módulo:** `aws-08-managed-data-rds-aurora-dynamodb`
- **Dificultad:** intermediate
- **Duración estimada:** 60–90 min
- **Tipo:** guided-lab (sin provisionar nada real)

## 2. Contexto

Vas a actuar como data engineer que recibe un `main.tf` para un RDS Postgres multi-AZ. El Terraform ya está escrito; tu trabajo es:

1. **Auditar** la configuración y detectar lo que falta o lo que es inseguro.
2. **Validar HCL** con `terraform plan` sin credenciales reales (sin tocar AWS).
3. **Levantar un `postgres:16` local** en un contenedor, modelar un esquema OLTP pequeño y comprobar que se conecta igual que lo haría una app contra RDS.
4. **Escribir una ADR** (`TOPOLOGY.md`) que justifique las decisiones: multi-AZ sí/no, read replicas sí/no, backup retention, SG mínimo.

No se crea ningún recurso AWS. Nada que pueda cobrar.

## 3. Objetivos

Al terminar deberías poder:

- Identificar en un `main.tf` de RDS los atributos **obligatorios** (`storage_encrypted`, `publicly_accessible = false`, `multi_az`, `deletion_protection`, `skip_final_snapshot = false`) y los **opcionales con fuerte recomendación** (`iam_database_authentication_enabled`, `manage_master_user_password`).
- Explicar por qué un `cidr_blocks = ["0.0.0.0/0"]` en el SG de la DB es un hallazgo crítico aunque la DB sea `publicly_accessible = false`.
- Diseñar un esquema SQL mínimo (3–4 tablas con FK) sobre Postgres local y argumentar sus índices.
- Escribir una ADR corta pero correcta.

## 4. Prerrequisitos

- `aws-03` (VPC) y `aws-06` (IAM) completados.
- Docker instalado y en marcha (`docker --version` responde).
- `terraform` ≥ 1.5 instalado (`terraform version`). Si no lo tienes, puedes **saltar** el paso 5.3 — el validador no lo exige.
- `psql` como cliente (viene con el paquete `postgresql-client`), o usar `docker exec` para abrir `psql` desde dentro del contenedor.

**Costos**: cero. Sin AWS real.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/aws-08-rds
cd /tmp/aws-08-rds
```

Si usas otra ruta, pásala al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Copiar el main.tf starter y auditarlo

Copia el archivo `starter/main.tf` a `/tmp/aws-08-rds/main.tf`:

```bash
cp <ruta-repo>/courses/aws/08-managed-data-rds-aurora-dynamodb/activities/01-provision-rds-and-connect/starter/main.tf /tmp/aws-08-rds/main.tf
```

El archivo contiene **al menos un problema de seguridad intencionado** (hallazgo). Encuéntralo. Lo documentarás en `TOPOLOGY.md`.

### 5.3 (Opcional) `terraform init && plan` sin credenciales

```bash
cd /tmp/aws-08-rds
terraform init -input=false   # descarga el provider aws.
terraform plan -input=false || true  # fallara al no poder resolver variables/credenciales; es esperado.
```

El objetivo no es ver un plan exitoso, sino **validar que el HCL es sintácticamente correcto**. Si `terraform init` falla por sintaxis, arréglalo antes de seguir.

### 5.4 Levantar `postgres:16` local

```bash
docker run -d --name aws08-pg \
  -e POSTGRES_PASSWORD=lab \
  -e POSTGRES_USER=lab \
  -e POSTGRES_DB=appdb \
  -p 55432:5432 \
  postgres:16

# Esperar unos segundos y comprobar.
docker exec aws08-pg pg_isready -U lab
```

Conectar:

```bash
PGPASSWORD=lab psql -h 127.0.0.1 -p 55432 -U lab -d appdb
```

### 5.5 Modelar un esquema OLTP mínimo

Crea el esquema en Postgres (puedes guardarlo también como `/tmp/aws-08-rds/schema.sql`):

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
  total_cents integer NOT NULL CHECK (total_cents >= 0),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX orders_user_created_idx ON orders (user_id, created_at DESC);

CREATE TABLE order_items (
  order_id   bigint NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  sku        text NOT NULL,
  qty        integer NOT NULL CHECK (qty > 0),
  unit_price_cents integer NOT NULL CHECK (unit_price_cents >= 0),
  PRIMARY KEY (order_id, sku)
);
```

Inserta algunos datos de prueba y comprueba una query típica:

```sql
INSERT INTO users (email, name) VALUES ('a@example.com', 'Ana'), ('b@example.com', 'Bruno');
INSERT INTO orders (user_id, status, total_cents) VALUES (1, 'paid', 12000), (1, 'pending', 3000);
SELECT * FROM orders WHERE user_id = 1 ORDER BY created_at DESC;
```

### 5.6 Escribir `TOPOLOGY.md`

Crea `/tmp/aws-08-rds/TOPOLOGY.md` con **cuatro secciones**:

#### A — Hallazgos de la auditoría del `main.tf`

Lista **al menos 2** hallazgos reales que encontraste en el starter (seguridad, falta de encryption, SG mal cerrado, falta de deletion_protection, final_snapshot ausente, etc.). Para cada uno:

- **Qué está mal.**
- **Impacto si va a prod así.**
- **Fix propuesto** (nombre del atributo y valor).

#### B — ADR: topología multi-AZ

Responde en 1–2 párrafos cada punto:

1. ¿Multi-AZ sí o no para este workload? Justifica con **RPO / RTO** esperados.
2. ¿Añadirías **read replicas**? ¿Cuántas y por qué?
3. ¿Habilitarías **cross-region read replica**? Si sí, ¿por qué; si no, qué alternativa de DR consideras?
4. **Backup retention**: ¿cuántos días? ¿snapshots manuales adicionales?

#### C — Esquema SQL local

Incluye el `CREATE TABLE` que ejecutaste y **justifica el índice** `orders_user_created_idx` (por qué `(user_id, created_at DESC)` y no `(user_id)` solo).

#### D — Conexión segura

Explica el **Security Group** mínimo para que la app alcance la DB:

- Puerto exacto.
- Fuente permitida (SG de la app, no CIDR).
- Por qué no basta con `publicly_accessible = false`.
- Cómo encaja **IAM database authentication** vs **Secrets Manager** para esta app.

### 5.7 Limpieza

```bash
docker rm -f aws08-pg
rm -rf /tmp/aws-08-rds
```

El validador comprueba el entregable **antes** de limpiar.

## 6. Resultado esperado

- `/tmp/aws-08-rds/TOPOLOGY.md` existe con las 4 secciones.
- `/tmp/aws-08-rds/main.tf` existe (copia del starter o versión arreglada).
- Opcional: `/tmp/aws-08-rds/schema.sql` con el DDL.
- `bash tests/validate.sh /tmp/aws-08-rds` en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: los hallazgos citan **atributos Terraform concretos**, no genéricos.
- **Reproducibilidad**: alguien que lea `TOPOLOGY.md` puede ejecutar los mismos pasos y llegar a la misma topología.
- **Mantenibilidad**: Markdown válido, SQL ejecutable sin errores.

## 8. Validación

```bash
bash tests/validate.sh /tmp/aws-08-rds
```

El validador comprueba **estructura**: existencia de secciones, uso de vocabulario clave (multi-az, backup, security group, IAM, etc.). La corrección semántica la revisas tú contra `solution/REFERENCE.md`.

## 9. Preguntas de reflexión

1. ¿Por qué `multi_az = true` **no** da activo-activo? ¿Qué servicio sí lo da (en AWS, para Postgres)?
2. Si el password está en Secrets Manager con rotación, ¿para qué quieres también IAM auth?
3. ¿Qué cuesta más al mes: multi-AZ en una `db.t4g.small` o una read replica adicional del mismo tamaño?
4. ¿Qué atributo del `main.tf` protege contra un `terraform destroy` accidental?
5. Al modelar `orders`, ¿por qué `(user_id, created_at DESC)` y no un índice sobre `user_id` y otro sobre `created_at` por separado?

## 10. Extensiones

- Añade un `aws_db_parameter_group` con `log_min_duration_statement = 500` y explica qué log vas a terminar auditando.
- Diseña el esquema para que `orders.status` sea un `ENUM` en lugar de `text CHECK` y argumenta trade-offs.
- Añade una read replica (`aws_db_instance` con `replicate_source_db`) y menciona que **no soporta multi-AZ en el reader** salvo que uses Aurora.

## 11. Limpieza

```bash
docker rm -f aws08-pg 2>/dev/null || true
rm -rf /tmp/aws-08-rds
```

Sin recursos AWS para limpiar — nunca se crearon.
