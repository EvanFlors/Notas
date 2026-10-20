# DR Plan — Capstone (etapa 14)

> ADR + runbook. Vive bajo control de versiones. Cualquier cambio a RTO/RPO exige review de dos personas y re-ejecucion del drill.

## 1. Alcance

Postgres de la app FastAPI, namespace `app` del cluster capstone (local-first via kind, o single-AZ en EKS/GKE/AKS si cloud-permitido). No cubre la stack de observabilidad (es rehidratable desde Git via Argo CD) ni la capa de Backstage.

## 2. Targets

| Metrica | Target | Como se mide |
|---------|--------|--------------|
| **RTO** (Recovery Time Objective) | **30 min** | Tiempo entre "incidente declarado" y "app sirviendo lectura+escritura con datos restaurados". |
| **RPO** (Recovery Point Objective) | **15 min** | Datos aceptables de perder. Implica backups con frecuencia <= 15 min **o** WAL archiving continuo. En esta etapa local-first corremos `pg_dump` cada 15 min via CronJob. En cloud real, se usaria PITR (point-in-time recovery) con WAL streaming a S3/GCS. |
| **Backup retention** | 7 dias en caliente, 30 dias en S3/GCS/Blob si cloud-permitido. | Lifecycle rules + script `postgres-backup.sh`. |
| **Drill cadence** | **Mensual**, obligatorio. | Resultado versionado en `backups/drill-log.md`. |

Si en un drill se mide RTO > 30 min o se descubre que RPO > 15 min, se declara **failed drill** y se abre issue bloqueante.

## 3. Decisiones (ADR en linea)

- **ADR-DR-001**: usamos `pg_dump` logico (no `pg_basebackup`) en la etapa local-first porque el dataset es pequeño (< 1 GB), la portabilidad entre versiones es util educativamente, y el tiempo de restore es aceptable.
- **ADR-DR-002**: el restore drill corre sobre un **postgres nuevo** en namespace `drill-<ts>`, nunca sobre el postgres de produccion. Esto evita incidentes "el drill borro los datos reales" (clasico).
- **ADR-DR-003**: no hay replica sincrona en esta etapa. El trade-off: RPO 15 min es peor que un setup con replicacion streaming (RPO ~ 0), pero evitamos complejidad hasta la etapa que lo justifique por SLA real.
- **ADR-DR-004**: los backups se cifran en reposo solo cuando cloud-permitido (SSE-S3/KMS). En local-first viven en disco; no almacenar PII real en esta etapa.

## 4. Procedimiento — backup

Automatico (CronJob k8s, cada 15 min):

```bash
dr/postgres-backup.sh
```

Produce `backups/pg-YYYYMMDD-HHMMSS.sql.gz`, verifica integridad con `pg_restore --list` y escribe una linea en `backups/backup-log.txt`.

Manual (ad-hoc antes de un cambio riesgoso):

```bash
NAMESPACE=app POD=postgres-0 dr/postgres-backup.sh
```

## 5. Procedimiento — restore drill

Automatico (mensual, o antes de cualquier cambio de version mayor de Postgres):

```bash
dr/postgres-restore-drill.sh
```

Pasos internos:

1. Localiza el ultimo backup en `backups/`.
2. Crea namespace `drill-<timestamp>`.
3. Levanta un pod `postgres:16-alpine` nuevo con PVC efimero.
4. `pg_restore` dentro del pod.
5. `SELECT count(*) FROM items;` — debe retornar > 0.
6. Mide tiempo total (RTO empirico).
7. Elimina el namespace temporal.
8. Appendea una linea a `backups/drill-log.md` con timestamp, backup usado, RTO medido y veredicto.

Si el drill falla, **no** se borra el namespace temporal — queda para forensics.

## 6. Procedimiento — restore REAL (incidente)

Solo bajo paging del on-call. Antes de ejecutar:

1. Declarar incidente en el canal `#capstone-incidents`.
2. Confirmar que el postgres de produccion esta efectivamente perdido (no un falso positivo). Un restore mal invocado es su propio incidente.
3. Snapshot forense del volumen actual (si existe).

Ejecucion:

```bash
# 1. Escalar fastapi a 0 para evitar escrituras durante el restore.
kubectl -n app scale deploy/fastapi --replicas=0

# 2. Levantar postgres nuevo (misma version mayor que el perdido).
kubectl -n app apply -f ../examples/postgres-sts.yaml

# 3. Copiar el dump y restaurar.
kubectl -n app cp backups/pg-<ts>.sql.gz postgres-0:/tmp/pg.sql.gz
kubectl -n app exec postgres-0 -- bash -c "gunzip -c /tmp/pg.sql.gz | pg_restore -d capstone -U postgres"

# 4. Volver a escalar fastapi.
kubectl -n app scale deploy/fastapi --replicas=2
```

Cerrar incidente cuando: healthchecks verdes, k6 smoke pasa, grafana reporta trafico normal.

## 7. Pruebas de validacion

- Mensualmente: `dr/postgres-restore-drill.sh` **debe** terminar con `RESULT: drill ok`.
- Trimestralmente: hacer un game day donde una persona distinta del on-call corre el restore real contra un cluster desechable, cronometrando.

## 8. Owners

- Backup CronJob: equipo platform.
- Drill: equipo que oper opera la app.
- Approval de cambios a RTO/RPO: dos reviewers del equipo platform.
