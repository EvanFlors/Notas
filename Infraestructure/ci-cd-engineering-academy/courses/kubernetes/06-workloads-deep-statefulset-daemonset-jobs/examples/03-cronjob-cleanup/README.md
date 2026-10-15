# Ejemplo 03 — `CronJob` de limpieza

## Concepto que demuestra

- `CronJob` con `schedule` tipo cron.
- `concurrencyPolicy: Forbid` para evitar overlaps.
- `startingDeadlineSeconds` para controlar qué ocurre con ventanas perdidas.
- Historial (`successfulJobsHistoryLimit`, `failedJobsHistoryLimit`).
- `ttlSecondsAfterFinished` para GC automático de los Jobs hijos.

## Contexto

Un patrón recurrente: una tarea de mantenimiento (limpiar archivos temporales, resetear un contador, exportar métricas) que debe correr cada X. Lo mínimo: un `CronJob`. Lo *bien hecho*: elegir `concurrencyPolicy` conscientemente y fijar `startingDeadlineSeconds`.

## Objetivo

Al terminar sabrás:

- Cómo luce un `CronJob` sano.
- Cómo observar las ejecuciones.
- Cómo pausarlo (`suspend`) y reanudarlo.

## Prerrequisitos

- Cluster `kind` corriendo.
- Paciencia para esperar un minuto a ver la primera ejecución (el cron corre cada 1 min).

## Ejecución

```bash
kubectl apply -f manifests/cleanup.yaml

# Mira el CronJob
kubectl get cronjob cleanup

# Espera ~70 s a la primera ejecución
sleep 70
kubectl get jobs -l 'batch.kubernetes.io/cronjob-name=cleanup' \
  || kubectl get jobs       # fallback por si la label no está en tu versión

# Logs del Job más reciente
LAST=$(kubectl get jobs --sort-by=.metadata.creationTimestamp -o name | tail -n1)
POD=$(kubectl get pods -l job-name="${LAST#job.batch/}" -o name | head -n1)
kubectl logs "$POD"
```

Prueba `suspend`:

```bash
kubectl patch cronjob cleanup --type merge -p '{"spec":{"suspend":true}}'
# Espera un par de minutos — no se crean nuevos Jobs.
kubectl patch cronjob cleanup --type merge -p '{"spec":{"suspend":false}}'
```

## Resultado esperado

- `kubectl get cronjob cleanup` muestra `SCHEDULE */1 * * * *`, `SUSPEND False`.
- Tras ~1 min, aparecen `Job`s hijos cada minuto.
- Los logs del Pod muestran `[cleanup] running at ... UTC`.
- A los ~2 min solo quedan como máximo 3 Jobs completados (por `successfulJobsHistoryLimit: 3`).

## Preguntas de reflexión

1. Cambia `concurrencyPolicy` a `Allow` y pon el comando a `sleep 180`. ¿Qué pasa?
2. ¿Qué pasa si el nodo donde corre el CronJob controller está caído 10 min? ¿Qué hace `startingDeadlineSeconds: 30`?
3. ¿Por qué el `restartPolicy` del Pod debe ser `OnFailure` o `Never`, nunca `Always`?
4. Para un backup nocturno a las 2 am hora de Madrid, ¿qué pondrías en `schedule` y en `timeZone`?

## Limpieza

```bash
kubectl delete -f manifests/cleanup.yaml --ignore-not-found
# Por si quedan jobs huérfanos
kubectl delete jobs -l 'batch.kubernetes.io/cronjob-name=cleanup' --ignore-not-found
```
