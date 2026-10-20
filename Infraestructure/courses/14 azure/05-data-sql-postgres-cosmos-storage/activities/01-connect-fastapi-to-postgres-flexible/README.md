# az-05-01 — Postgres Flexible + Azure SQL (plan + Postgres local) y ADR de topologia

> **Duracion:** ~90 min.
> **Tipo:** guided-lab (hay un `starter/` con `main.tf` que auditar + `postgres:16` local).
> **Coste real:** 0 USD. **No** aplicaremos nada contra Azure.

## 1. Contexto

Tu equipo esta disenando un workload nuevo: una API de pedidos (`checkout`) multi-tenant que necesita Postgres transaccional. Un companero ha preparado un `main.tf` draft con un **Postgres Flexible Server** y, aparte, un **Azure SQL Database** (que no vas a desplegar — es para la comparativa). Te pide que:

1. **Audites** el `main.tf` como si fueras a aprobar el PR.
2. Pruebes el esquema contra un **Postgres local en Docker** (no quiere pagar la hora del Flexible Server mientras itera).
3. Dejes la decision por escrito en un **ADR TOPOLOGY.md** que justifique por que elegis Postgres Flexible y no Azure SQL para este caso.

## 2. Objetivos de aprendizaje

- Leer HCL `azurerm_postgresql_flexible_server` y `azurerm_mssql_server` y detectar atributos faltantes.
- Ejecutar `terraform init` + `terraform plan` sin credenciales (fallara pidiendo subscription — es esperado).
- Modelar un esquema OLTP minimo (`users`, `orders`, `order_items`) en Postgres 16, con FKs e indices razonables.
- Escribir un ADR estructurado con las 4 secciones estandar.

## 3. Preparacion

```bash
mkdir -p /tmp/az-05-pg
cp starter/main.tf /tmp/az-05-pg/main.tf
cd /tmp/az-05-pg
```

(Opcional, para validar HCL) `terraform init && terraform plan -input=false`. Al no tener subscription real, `plan` fallara al leer datos de Azure — es esperado. Lo que validamos aqui es solo la sintaxis HCL.

## 4. Paso 1 — Auditar el `main.tf`

Lee `main.tf` entero. Identifica al menos **dos hallazgos**: uno en seguridad de red (ingress/public access) y otro en autenticacion. Pistas:

- Como esta el `public_network_access_enabled` del Postgres Flexible?
- Hay subnet delegada? Private DNS zone?
- Como es la autenticacion (password / Entra ID / ambas)?
- Que falta en el `azurerm_mssql_server`?

Anota en un bloc los hallazgos. Luego los documentaras en `TOPOLOGY.md`.

## 5. Paso 2 — Postgres local en Docker

Levanta Postgres 16 local para modelar sin pagar Azure:

```bash
docker run -d --name az05-pg \
  -e POSTGRES_PASSWORD=lab -e POSTGRES_USER=lab -e POSTGRES_DB=appdb \
  -p 55432:5432 postgres:16
```

Conecta y crea el esquema OLTP:

```bash
docker exec -i az05-pg psql -U lab -d appdb <<'SQL'
CREATE TABLE users (
  id          BIGSERIAL PRIMARY KEY,
  email       TEXT NOT NULL UNIQUE,
  name        TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE orders (
  id          BIGSERIAL PRIMARY KEY,
  user_id     BIGINT NOT NULL REFERENCES users(id),
  status      TEXT NOT NULL CHECK (status IN ('pending','paid','shipped','cancelled')),
  total_cents INTEGER NOT NULL CHECK (total_cents >= 0),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_orders_user_created ON orders(user_id, created_at DESC);

CREATE TABLE order_items (
  order_id         BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  sku              TEXT   NOT NULL,
  qty              INTEGER NOT NULL CHECK (qty > 0),
  unit_price_cents INTEGER NOT NULL CHECK (unit_price_cents >= 0),
  PRIMARY KEY (order_id, sku)
);
SQL
```

(Opcional) Guarda ese bloque en `/tmp/az-05-pg/schema.sql` para que quede evidencia.

## 6. Paso 3 — Escribir `TOPOLOGY.md`

Crea `/tmp/az-05-pg/TOPOLOGY.md` con **4 secciones** (A, B, C, D):

### A. Hallazgos del audit (minimo 2)

Lista cada hallazgo con: que vi, por que es un problema, como lo arreglaria. Usa literalmente la palabra `Hallazgo` para cada uno (el validador la cuenta).

### B. ADR de topologia Postgres Flexible

Decide y justifica:

- **Tier**: `GP_Standard_D2s_v3` vs `B1ms` burstable (prod vs dev).
- **HA**: `ZoneRedundant` vs `SameZone` vs sin HA. **RPO/RTO** esperados.
- **Private access** (subnet delegada) vs public con firewall. Por que uno u otro.
- **Auth**: Entra ID auth + password_auth deshabilitado, con rol asignado al grupo `db-admins`.
- **Backups**: `backup_retention_days` 7 vs 14 vs 35. Geo-redundant si/no.
- Al menos **dos nombres de atributos Terraform** citados textualmente (ej. `public_network_access_enabled`, `delegated_subnet_id`, `high_availability`, `backup_retention_days`, `active_directory_auth_enabled`, `password_auth_enabled`).

### C. Esquema SQL + justificacion de indices

Pega el DDL o referencia `schema.sql`. Justifica **al menos un indice** (que query acelera, por que no vale el PK).

### D. Comparativa Azure SQL vs Postgres Flexible para este workload

Tabla o parrafo que decida y justifique. Debe mencionar `Postgres` y uno de: `multi-AZ` / `multi-az`, `Security Group`, `IAM auth` / `IAM database authentication` o equivalente Azure (Entra ID), `backup` / `snapshot` / `retention`, y `RPO` o `RTO`.

## 7. Paso 4 — Validar

```bash
bash tests/validate.sh /tmp/az-05-pg
```

Debe terminar con `OK: estructura valida`.

## 8. Limpieza

```bash
docker rm -f az05-pg 2>/dev/null || true
rm -rf /tmp/az-05-pg
```

## 9. Que se evalua

- Hallazgos **razonables** (no inventados).
- ADR legible, con decision, consecuencia, alternativa descartada.
- Esquema SQL correcto (FKs, CHECK, indice justificado).
- Comparativa honesta Azure SQL vs Postgres Flexible (no sesgada).
- El validador estructural en verde.

## 10. Solucion de referencia

`solution/REFERENCE.md` contiene una version resuelta. Usala **despues** de intentar el ejercicio.
