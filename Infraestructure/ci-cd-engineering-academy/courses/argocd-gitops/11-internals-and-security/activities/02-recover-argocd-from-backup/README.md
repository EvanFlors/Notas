# Actividad 02 — Recuperar Argo CD completo desde backup

## 1. Identificación

- **ID:** `argo-11-02-recover-argocd-from-backup`
- **Tecnología:** `argocd-gitops`
- **Módulo:** `11-internals-and-security`
- **Dificultad:** advanced
- **Duración estimada:** 90 min
- **Tipo:** independent

## 2. Contexto

Tu Argo CD de dev gestiona N Applications. Mañana algo pasa: alguien borra el ns `argocd`, un upgrade falla, o migras a otro cluster. En GitOps "el estado está en Git" — pero la configuración de Argo CD (Projects, repo creds, cluster creds, Applications), **no**. Esa es la que debes poder reconstruir en minutos.

Esta actividad te pone en el papel de SRE del día del incidente. No te damos el runbook — lo diseñas y lo ejecutas. Al terminar, un script independiente verifica que todas las Applications vuelven a `Synced/Healthy` sin que las re-crees a mano.

## 3. Objetivos

- Elegir e implementar **una** estrategia de backup entre:
  - **A.** Velero del ns `argocd` (ver Ejemplo 03).
  - **B.** `argocd admin export` + `kubectl get secret -n argocd -o yaml`.
  - **C.** Una mezcla razonada (p. ej. Velero + export como *belt and suspenders*).
- Hacer el backup **antes** del desastre.
- Ejecutar el desastre: `kubectl delete ns argocd --wait=true`.
- Restaurar y dejar `kubectl -n argocd get apps` idéntico al pre-desastre, con todas `Synced/Healthy`.
- Documentar RTO (tiempo total desde el desastre hasta todas sanas).

## 4. Prerrequisitos

- Haber completado la actividad 01 (tienes un Argo CD operativo + endurecido).
- Al menos **2 Applications** en `argocd` (si no, créalas con `argocd app create` apuntando a repos públicos — una `guestbook` del repo `argocd-example-apps` sirve).
- Si eliges Velero: tenerlo instalado (ver Ejemplo 03).
- Si eliges `argocd admin export`: `argocd` CLI logueado como admin **antes** del desastre.
- **Costo:** $0.

## 5. Instrucciones

> Esta es una actividad *independiente*. No te damos el paso-a-paso. Las pistas de abajo son el máximo que recibes.

### 5.1 Preparación

```bash
bash courses/argocd-gitops/11-internals-and-security/activities/02-recover-argocd-from-backup/starter/bootstrap.sh /tmp/argo-11-02
```

El bootstrap:

- Verifica cluster + Argo CD + que haya >=2 Applications.
- Guarda un snapshot pre-desastre de los nombres de `Application` y sus `syncStatus/healthStatus` en `/tmp/argo-11-02/pre-disaster.apps`. El validador comparará contra este snapshot.
- Deja `/tmp/argo-11-02/work/` para que lo uses como scratch.

### 5.2 Diseñar tu runbook

Antes de tocar nada, escribe en `/tmp/argo-11-02/work/RUNBOOK.md` (markdown libre) los pasos que vas a seguir:

1. Qué estrategia (A / B / C).
2. Qué comando(s) para el backup.
3. Qué comando(s) para el desastre.
4. Qué comando(s) para el restore.
5. Qué verificas al final.

Guardar el runbook es parte del entregable — una recuperación improvisada no cuenta.

### 5.3 Ejecutar

Sigue tu runbook. Al llegar al "desastre", **sí**: `kubectl delete ns argocd` o `kubectl -n argocd delete applications --all && kubectl delete ns argocd`. No tengas miedo — el backup es tu red.

Pistas:

- Si usas Velero: `velero restore create --from-backup <name> --wait --existing-resource-policy update`. Si el ns no existe, Velero lo re-crea.
- Si usas `argocd admin export`: necesitarás reinstalar Argo CD vanilla primero (`kubectl apply -n argocd -f install.yaml`), **esperar** a que arranque, y luego `argocd admin import - < export.yaml`. Los Secrets (`argocd-secret`, `argocd-initial-admin-secret`, repo/cluster creds) NO vienen en el export — hazles backup aparte con `kubectl get secret -n argocd -o yaml > secrets.yaml` **antes** del desastre.
- Si recreas Argo CD limpio, la contraseña de admin será nueva — por eso guarda el `argocd-secret` original (bcrypt del password) **antes** del desastre si quieres el mismo password.

### 5.4 Validar

```bash
bash courses/argocd-gitops/11-internals-and-security/activities/02-recover-argocd-from-backup/tests/validate.sh
```

El validador comprueba:

1. El ns `argocd` existe y tiene Argo CD corriendo.
2. Las Applications del snapshot pre-desastre **todas** existen tras el restore.
3. Todas están `Synced` y `Healthy`.
4. Existe `/tmp/argo-11-02/work/RUNBOOK.md` con contenido no trivial.

## 6. Resultado esperado

- `kubectl -n argocd get apps` muestra el mismo set que el snapshot pre-desastre.
- `kubectl -n argocd get apps -o json | jq '.items[] | {name:.metadata.name, sync:.status.sync.status, health:.status.health.status}'` → todas `Synced` y `Healthy`.
- `RUNBOOK.md` describe tu estrategia y los pasos ejecutados.

## 7. Criterios de aceptación

- **Reproducibilidad**: tu runbook puede ejecutarlo otro miembro del equipo sin asistencia.
- **Correctness**: no re-creas Applications a mano — vienen del backup.
- **Honestidad del RTO**: anota el tiempo real, incluyendo tus fumbles.
- **Idempotencia del validador**: puede correrse N veces y da el mismo resultado.

## 8. Validación

Automatizada: `bash tests/validate.sh`.

## 9. Preguntas de reflexión

- ¿Por qué el estado de Argo CD cabe en un backup de namespace y el de un sistema con base de datos (Postgres de GitLab, por ejemplo) no?
- Si tu restore pone de vuelta `argocd-secret` con un `server.secretkey` *distinto* del vigente, ¿qué pasa con los JWT project tokens emitidos?
- ¿Qué backup corre más riesgo de desincronización con la realidad: Velero diario o `argocd admin export` on-demand? ¿Por qué?
- Si pierdes también el **cluster target** (no solo el control-plane de Argo CD), ¿qué cambia en tu runbook?
- Imagina que el restore tarda 20 min y mientras tanto el equipo quiere desplegar. ¿Qué contingencia das? (Pista: `kubectl apply` directo documentado para emergencia.)

## 10. Extensiones

- Script-ifica tu runbook y añádelo a un repo de "ops-runbooks" del propio Argo CD.
- Escribe una `CronJob` que haga `argocd admin export` diario y suba a un bucket.
- Mide RTO en frío (cluster entero perdido): crea un nuevo kind, restaura, mide.
- Añade un health-check post-restore que valide no solo que Apps estén `Healthy`, sino que **endpoints de la app** respondan 200.

## 11. Limpieza

```bash
rm -rf /tmp/argo-11-02
# Si creaste cluster solo para esto:
# kind delete cluster --name argo-11-02
```
