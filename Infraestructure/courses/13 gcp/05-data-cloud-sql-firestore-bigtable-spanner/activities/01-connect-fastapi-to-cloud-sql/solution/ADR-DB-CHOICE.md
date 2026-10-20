# ADR 001 — Motor de base de datos para `checkout` en GCP

## Estado

Aceptado.

## Contexto

El servicio `checkout` procesa pagos: SLA 99.9%, picos de ~400 req/s, dataset activo < 500 GiB a 12 meses vista, patrones de acceso OLTP clasicos (lecturas por `order_id`, escritura al confirmar, batch nocturno de conciliacion). El equipo ya opera Postgres en AWS RDS y quiere **cero reaprendizaje de SQL**. Compliance exige datos **en Europa** (`europe-west1`). El pipeline publica contra un project GCP via Workload Identity Federation (sin keys), y la DB nunca debe exponerse a internet.

## Decision

Usar **Cloud SQL Postgres 15** en `europe-west1` con las siguientes propiedades:

- `availability_type = REGIONAL` (HA activa-pasiva en 2 zonas).
- `ipv4_enabled = false` y acceso **exclusivamente via Cloud SQL Auth Proxy**.
- `point_in_time_recovery_enabled = true` + backups diarios (ventana 02:00 UTC).
- `database_flags: cloudsql.iam_authentication = on` + usuario Postgres mapeado a una service account `checkout-cloud-sql-client` con `roles/cloudsql.client` (sin password Postgres estatico).

**AlloyDB** queda documentada como ruta de escalado posterior, no como opcion inicial.

## Consecuencias

Positivas:
- **Coste bajo** para el tamaño actual (~90 EUR/mes HA regional en `db-custom-2-7680`).
- **Operacion familiar** para el equipo (Postgres estandar; psql, extensiones comunes, migraciones).
- **Seguridad por default**: sin IP publica, autenticacion via IAM, TLS mutuo via proxy.
- **PITR** permite recuperar al segundo cualquier incidencia en los ultimos 7 dias.

Negativas:
- Un unico primary (write) por region: si en 18 meses abrimos un segundo PoP en US, Cloud SQL no da **tx globales**; habria que replantear (ver "Alternativas").
- `cloud-sql-proxy` es una pieza mas que mantener (sidecar en Cloud Run; en GKE requiere ajustes de init).

## Alternativas

1. **AlloyDB Postgres-compatible**: descartada ahora. Da ~4x rendimiento OLTP y HTAP opcional, pero el **piso de coste** es varios x mas alto y el workload actual **no satura** Cloud SQL. Reevaluar si el p95 de query sostenido supera 200 ms o si write TPS pasa de 150 por instancia. Postgres-compatible pero **no drop-in** (algunas extensiones).
2. **Spanner**: descartado. Daria SQL globalmente consistente, pero el workload es single-region y single-write; el precio minimo (~65 USD/mes solo por 100 PU) y el reaprendizaje de **tablas interleaved** son un sobreprecio injustificado por ahora. Reconsiderar si el requisito pasa a *multi-region con tx fuertes*.
3. **Self-managed Postgres en GCE**: descartada. Ahorra ~30% en infra pura pero empeora SLA (sin HA automatica), aumenta carga operativa (parches, backups, failover manual) y nos deja fuera del patron **Auth Proxy + IAM auth** nativo. Mal trade-off para una API critica.
