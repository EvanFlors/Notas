# Ejemplo 03 — CloudNativePG (CNPG) overview

Walkthrough de **CloudNativePG** como ejemplo de operador *maduro* para una pieza compleja (Postgres HA). Objetivo: ver cómo se expone todo el conocimiento operativo detrás de **un único CR** `Cluster`.

## Qué es

- Operador open source (Apache 2.0) para Postgres en Kubernetes.
- Proyecto incubado en CNCF; cadencia de releases frecuente; mantenido por EnterpriseDB y comunidad.
- CRs principales: `Cluster`, `Pooler` (PgBouncer), `Backup`, `ScheduledBackup`, `Database`.

Modelo mental: declaras `Cluster` con instancias, storage, backup, y CNPG materializa Pods + Services + PVCs + Secrets + PodDisruptionBudget, hace streaming replication, elige primary y hace failover automático.

## Instalación de referencia

```bash
# Verificar la versión vigente antes de ejecutar.
kubectl apply --server-side -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.24/releases/cnpg-1.24.0.yaml

kubectl -n cnpg-system rollout status deploy/cnpg-controller-manager
```

## `Cluster` de ejemplo

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: pg-demo
  namespace: default
spec:
  instances: 3                 # 1 primary + 2 standbys
  imageName: ghcr.io/cloudnative-pg/postgresql:16.4
  primaryUpdateStrategy: unsupervised
  storage:
    size: 10Gi
    storageClass: standard
  bootstrap:
    initdb:
      database: app
      owner: app
  monitoring:
    enablePodMonitor: true
  backup:
    barmanObjectStore:
      destinationPath: s3://my-bucket/pg-demo
      s3Credentials:
        accessKeyId:
          name: s3-creds
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: s3-creds
          key: SECRET_ACCESS_KEY
    retentionPolicy: "30d"
```

Lo que CNPG hace a partir de ese CR:

1. Crea un StatefulSet-equivalente con 3 Pods de Postgres (CNPG no usa StatefulSet nativo — gestiona Pods directamente para controlar bootstrapping y failover).
2. Crea Services `pg-demo-rw` (primary) y `pg-demo-ro` (standbys read-only).
3. Provisiona PVCs por instancia.
4. Inicializa el cluster con `initdb`.
5. Configura replicación streaming con slots.
6. Genera Secrets para `app` y para `postgres` superuser.
7. Habilita `PodMonitor` para Prometheus Operator.
8. Programa WAL archiving continuo a S3 vía Barman.
9. Vigila la salud y hace failover si el primary cae.

## Operaciones comunes como CRs

| Operación | CR |
|---|---|
| Backup on-demand | `kind: Backup` |
| Backups programados | `kind: ScheduledBackup` |
| Restore a nuevo cluster | `Cluster` con `bootstrap.recovery.source` |
| Pool de conexiones | `kind: Pooler` (PgBouncer) |
| Crear base de datos lógica | `kind: Database` |

Todo versionado, auditado por GitOps, revisado como código.

## Qué observar

- **Un solo CR** colapsa docenas de recursos nativos + runbooks operativos.
- El `status` del `Cluster` dice *de verdad* qué pasa: `currentPrimary`, `targetPrimary`, `phase`, `instancesStatus`.
- Failover es responsabilidad del operador — no de tu equipo a las 3 AM.
- Backups están **primera clase**: no hay excusa de "se nos olvidó configurarlos".

## Qué NO resuelve

- No es un reemplazo de un DBA para esquemas complejos, tuning avanzado, planes de consultas, migraciones mayores.
- Si tu RTO/RPO es *decisivo*, igual quieres managed Postgres (RDS, Cloud SQL) donde el proveedor firma el SLA.
- Operar Postgres multi-región requiere diseño adicional (replicación lógica, conflict resolution).

## Lectura recomendada

- Docs: https://cloudnative-pg.io/documentation/
- CNCF project page: https://www.cncf.io/projects/cloudnative-pg/
- Comparativa con Zalando operator: ver `activities/02-evaluate-postgres-operators/`.
