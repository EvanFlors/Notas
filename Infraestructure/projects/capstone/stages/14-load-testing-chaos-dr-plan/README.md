# Capstone — Etapa 14: Load testing + chaos ligero + DR plan

> Fase 5 del programa. Asume que las etapas 1–13 estan cerradas: la app FastAPI + PostgreSQL corre en Kubernetes bajo Argo CD, con observabilidad (Prometheus/Grafana/Loki/OTel), DevSecOps (ESO/Kyverno/Falco) y una capa de Platform Engineering (Backstage + scorecard + DORA).

## 1. Resumen de la etapa

- **Objetivo**: medir que tanto aguanta el sistema (carga sintetica), introducir fallos controlados (chaos engineering ligero) y dejar escrito un plan de recuperacion ante desastres (DR) con targets de RTO/RPO verificados por un drill real de backup/restore de Postgres.
- **Delta vs etapa 13**: pasamos de instrumentacion/scorecards hacia **ejercicios de resiliencia**. Antes "sabiamos" el estado del sistema; ahora **lo rompemos a proposito** y validamos recuperacion. Primera vez que corremos pruebas de carga sostenidas y que el postgres sufre un restore real desde snapshot.
- **Fuera de scope**: game days multi-equipo, chaos en region multi-az real, DR cross-region con replicacion sincrona, y post-mortem simulado (eso vive en la etapa 15).

## 2. Arquitectura al cierre de esta etapa

```
                    +-------------------+
                    |   k6 / locust     |  (generador de carga, fuera del cluster)
                    +---------+---------+
                              | HTTP /items, /health
                              v
+----------------+      +-----+-----+      +-------------------+
|  chaos-mesh    |----->|  FastAPI  +----->|  PostgreSQL (STS) |
|  (pod-kill,    |      |  Deploy   |      |  + WAL + pgdump   |
|  latency,      |      +-----+-----+      +---------+---------+
|  cpu-stress)   |            |                      |
+----------------+            v                      v
                        Prometheus / Grafana     backups/ (snapshot)
                        (SLO: p95, error-rate)       |
                                                     v
                                            dr/restore-drill (job)
```

Recursos:

- Namespace `app` (FastAPI + Postgres STS, pre-existentes).
- Namespace `chaos-mesh` (instalado para esta etapa; se desinstala al terminar).
- `PodChaos`, `NetworkChaos`, `StressChaos` CRDs apuntando a selectors de `app`.
- Volumen `backups/` (local-first con `hostPath` o PVC) para `pg_dump`.
- Grafana dashboard `capstone-resilience` (reusa el existente de la etapa 11).

## 3. Prerrequisitos verificados

- [ ] FastAPI + Postgres desplegados y accesibles via Service dentro del cluster.
- [ ] Prometheus + Grafana corriendo (etapa 11), con metrica `http_requests_total` y `http_request_duration_seconds_bucket`.
- [ ] Service account del operador de chaos-mesh con RBAC acotado a namespace `app` (no cluster-wide).
- [ ] `kubectl`, `helm` autenticados contra el cluster.
- [ ] Herramientas opcionales (si no estan, los scripts hacen SKIP): `k6`, `kubectl chaos` o `chaosctl`, `pg_dump`, `pg_restore`.

Si falta algo, cerrar la etapa correspondiente antes de continuar. Esta etapa **no instala** FastAPI, Postgres, ni la stack de observabilidad.

## 4. Implementacion guiada

### 4.1 Carga sintetica con k6

Archivo: `load/k6-script.js`. Define 3 escenarios:

1. `smoke` — 1 VU, 1 min, para validar que la URL/endpoint responde.
2. `ramp` — rampa de 0 a 50 VUs en 2 min, sostenido 3 min, baja 1 min.
3. `soak` — 20 VUs constantes por 15 min (solo si `SOAK=1`).

Thresholds (fallan el run si se violan):

- `http_req_failed{expected_response:true}` < 1%.
- `http_req_duration` p95 < 500 ms.

Correr con `load/run-k6.sh http://<app-url>`. Si `k6` no esta instalado, el script hace **SKIP** con exit 0 y un mensaje claro.

### 4.2 Chaos ligero con chaos-mesh

Tres CRDs minimas en `chaos/`:

- `pod-kill.yaml`: `PodChaos` con `action: pod-kill`, `mode: one`, selector del Deployment `fastapi`.
- `latency-inject.yaml`: `NetworkChaos` con `action: delay`, 200ms +/- 50ms, duracion 1m, target hacia el Service de Postgres.
- `cpu-stress.yaml`: `StressChaos` con `cpuWorkers: 2`, carga 80%, duracion 2m, target FastAPI.

Aplicar con `kubectl apply -f chaos/<file>`. El script `chaos/run-experiment.sh <scenario>` encapsula aplicar, esperar duracion, y limpiar.

### 4.3 DR plan + backup/restore drill

- `dr/DR-PLAN.md`: ADR con RTO/RPO declarados (RTO 30 min, RPO 15 min para esta etapa local-first) y procedimiento manual + automatizado.
- `dr/postgres-backup.sh`: ejecuta `pg_dump` dentro del pod de postgres, timestamped, comprimido, verificado con `pg_restore --list`.
- `dr/postgres-restore-drill.sh`: levanta un postgres **sidecar** desechable, restaura el ultimo dump, hace `SELECT count(*)` sobre las tablas canonicas de la app y limpia. **No toca** el postgres de produccion.

Ambos scripts hacen SKIP si `pg_dump`/`kubectl` no estan disponibles.

### 4.4 Observar

Durante los experimentos de chaos y las corridas de k6, mirar:

- Grafana `capstone-resilience` (p95, error rate, saturation CPU/mem).
- Logs via Loki filtrados por `namespace=app` + nivel `error`.
- Alertas de Prometheus (deben disparar y re-silenciarse automaticamente al finalizar).

## 5. Actividades del estudiante

Tres actividades, cada una con `activity.yaml`, `README.md`, `tests/validate.sh`:

| # | ID | Tipo | Resumen |
|---|------|-------|--------|
| 01 | `cap-14-01-k6-smoke-and-soak` | guided-lab | Correr `k6` contra la app, interpretar thresholds, declarar baseline. |
| 02 | `cap-14-02-chaos-mesh-pod-kill-latency-cpu` | independent | Diseñar y correr los 3 experimentos, documentar blast radius y recovery time. |
| 03 | `cap-14-03-dr-backup-restore-drill` | debug | Ejecutar backup, simular perdida, correr drill de restore y medir RTO/RPO reales vs los declarados. |

## 6. Entregables

- `load/k6-script.js` + `load/run-k6.sh` versionados.
- 3 CRDs chaos-mesh en `chaos/` + `chaos/run-experiment.sh`.
- `dr/DR-PLAN.md` con RTO/RPO firmados.
- Al menos un backup realizado en `backups/` + evidencia del drill de restore exitoso.
- Captura (manual) del dashboard Grafana durante el run de k6 y durante al menos un experimento de chaos.

## 7. Pruebas y criterios de aceptacion

- [ ] `load/run-k6.sh` corre sin error si k6 esta presente, o emite SKIP controlado si no.
- [ ] `kubectl apply -f chaos/*.yaml` es rechazado por el API server si chaos-mesh no esta instalado (comportamiento esperado); si esta instalado, los experimentos corren y terminan solos.
- [ ] `dr/postgres-backup.sh` produce un archivo `backups/pg-YYYYMMDD-HHMMSS.sql.gz` valido (verificado con `pg_restore --list`).
- [ ] `dr/postgres-restore-drill.sh` termina con `RESULT: drill ok` **y** la tabla canonica (`items`) tiene al menos 1 fila despues del restore.
- [ ] Validadores de las 3 actividades reportan `RESULT: 0 issue(s)`.

## 8. Costos y limpieza

- **Costos**: USD 0 si local-first (kind/minikube) y pg_dump a disco local. En un cluster EKS/GKE/AKS, los experimentos de chaos no suman costo propio; la carga sostenida de k6 contra un endpoint publico podria disparar egress (vigilar).
- **Limpieza**:

```bash
# chaos
kubectl delete -f chaos/ --ignore-not-found
helm uninstall chaos-mesh -n chaos-mesh || true
kubectl delete ns chaos-mesh --ignore-not-found

# load
rm -rf load/results/

# dr
rm -rf backups/
```

- Guard-rail: nunca correr `soak` contra un endpoint pagado por consumo sin un budget alert previo.

## 9. Riesgos y mitigaciones

| Riesgo | Mitigacion |
|--------|------------|
| Chaos escala fuera del namespace `app` y afecta `kube-system`. | Selector por label `app.kubernetes.io/part-of=capstone`; RBAC del operador acotado; `mode: one` siempre. |
| k6 soak satura el egress del laptop/CI. | Soak solo con `SOAK=1`, documentado; thresholds abortan temprano. |
| Restore drill sobrescribe la DB de produccion. | Drill levanta un pod **nuevo** en namespace temporal; nunca apunta al Service de produccion. |

Hints progresivos si el estudiante se atasca: ver cada `README.md` de actividad, seccion 5.5.

## 10. Puente con la siguiente etapa

- La etapa 15 (postmortem simulado + runbook definitivo) **consume** las trazas y los dashboards generados aqui: durante un experimento de chaos se dispara una alerta → se simula el incidente → se escribe el postmortem.
- Dejar corriendo: Prometheus, Grafana, Loki, Argo CD, la app.
- Apagar: chaos-mesh (desinstalar) y cualquier carga de k6 persistente.
- Cliffhanger: *¿Que tan honesto es tu runbook si nadie lo ejecuto nunca bajo presion?*

## Referencias

Ver `resources/links.md`.
