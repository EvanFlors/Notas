# Solucion de referencia — az-05-01

> Es **una** solucion razonable, no la unica. Usala para autoevaluarte **despues** del intento.

## A. Hallazgos del audit (starter/main.tf)

- **Hallazgo 1 (red):** `public_network_access_enabled = true` en el `azurerm_postgresql_flexible_server`, aun cuando ya hay subnet delegada y private DNS zone. Es un oxymoron: anuncias "private access" pero dejas la superficie publica abierta. **Fix:** `public_network_access_enabled = false`.
- **Hallazgo 2 (auth):** `password_auth_enabled = true` con Entra ID auth tambien activo. En prod se deja **solo** Entra ID (`password_auth_enabled = false`) para forzar que todas las conexiones pasen por tokens de identidad. **Fix:** poner `password_auth_enabled = false` y eliminar `administrator_login` + `administrator_password`.
- **Hallazgo 3 (secretos en IaC):** `administrator_password = "ChangeMe!..."` en texto plano. Nunca commitear passwords; usar `azurerm_key_vault_secret` o `random_password` + Key Vault + Managed Identity.
- **Hallazgo 4 (Azure SQL):** `azurerm_mssql_server` tiene `public_network_access_enabled = true` y **ningun** admin Entra ID configurado — solo SQL login clasico. Falta `azurerm_mssql_server_microsoft_support_auditing_policy` / `azuread_administrator` block (segun version del provider) y Private Endpoint.

## B. ADR Postgres Flexible — Decision

### Contexto

Workload `checkout` multi-tenant, OLTP, latencia objetivo p95 < 50ms intra-region, RPO objetivo <= 15 min, RTO objetivo <= 5 min, trafico moderado (<50 TPS en pico), region primaria `westeurope`.

### Decision

- **Tier**: `GP_Standard_D2s_v3` (General Purpose, 2 vCPU, 8 GiB). B1ms burstable solo para dev.
- **HA**: `high_availability.mode = ZoneRedundant` con standby en zone 2. RPO ~ 0 (sincrono), RTO 60-120 s por failover automatico.
- **Red**: Private access via subnet delegada + `private_dns_zone_id` + `public_network_access_enabled = false`.
- **Auth**: `active_directory_auth_enabled = true`, `password_auth_enabled = false`. Admin es el grupo Entra ID `db-admins` (object_id en variable, no en IaC).
- **Backups**: `backup_retention_days = 14` (balance coste/recuperacion), `geo_redundant_backup_enabled = false` (RPO cross-region no es requisito). Si cambiara, serian Auto-Failover Groups o replicacion.

### Consecuencias

- Coste base ~140 USD/mes region europea (con HA Zone-Redundant anade ~40%).
- Cualquier app que necesite el server debe estar en la misma VNet (o peered) y resolver via la private DNS zone.
- Ninguna conexion con password; la Managed Identity del consumidor debe tener rol `pg_read_all_data` o similar via `GRANT` sobre grupos Entra ID.

### Alternativas descartadas

1. **B-series burstable**: barato pero sin HA. Rechazado para prod.
2. **Public access + firewall por IP**: operacionalmente fragil (IPs de outbound de Container Apps son dinamicas), expone superficie publica innecesaria. Rechazado.
3. **Azure SQL Database serverless**: viable pero el equipo tiene expertise Postgres y el modelo de datos es relacional estandar. Ver seccion D.

## C. Esquema SQL + indice

```sql
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

-- Indice compuesto: acelera "ultimas N orders de un usuario" (la query mas
-- comun en el frontend). Sin el, Postgres hace seq scan + sort cuando el
-- usuario tiene muchos orders.
CREATE INDEX idx_orders_user_created ON orders(user_id, created_at DESC);

CREATE TABLE order_items (
  order_id         BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  sku              TEXT   NOT NULL,
  qty              INTEGER NOT NULL CHECK (qty > 0),
  unit_price_cents INTEGER NOT NULL CHECK (unit_price_cents >= 0),
  PRIMARY KEY (order_id, sku)
);
```

El indice `idx_orders_user_created (user_id, created_at DESC)` acelera `SELECT * FROM orders WHERE user_id=$1 ORDER BY created_at DESC LIMIT 20`. El PK `(id)` no sirve para esa query. Para `order_items` la PK compuesta `(order_id, sku)` ya cubre la query "items de una order".

## D. Comparativa Azure SQL vs Postgres Flexible

| Aspecto | Postgres Flexible | Azure SQL Database |
|---------|-------------------|---------------------|
| Motor | Postgres 16 OSS | SQL Server managed |
| Expertise equipo | **Si** (ya conocen Postgres) | Reaprender T-SQL, SSMS |
| Private access nativo | **Si** (subnet delegada) | Private Endpoint (equivalente) |
| Entra ID auth | **Si** | **Si** |
| HA | ZoneRedundant | Zone-redundant Premium / BusinessCritical |
| Backups | 7-35 dias, geo-redundant opcional | 7-35 dias, PITR + LTR |
| Serverless | No (B-series es "cheap", no serverless) | **Si** (auto-pause) |
| Coste minimo util | ~15 USD B1ms | ~5 USD Basic (no apto prod) |
| multi-AZ RPO/RTO | ~0 / 60-120 s | ~0 / 30 s (Premium) |
| Lock-in | Bajo (OSS) | Medio-alto (T-SQL + servicio) |

**Decision**: Postgres Flexible. El equipo ya domina Postgres; el modelo relacional no necesita features T-SQL especificas; el lock-in es menor; HA Zone-Redundant cumple el RPO/RTO; el Security Group de red se traduce a NSG en la subnet delegada. Azure SQL solo tendria sentido si el equipo viniera de SQL Server o si necesitase serverless auto-pause para entornos efimeros.
