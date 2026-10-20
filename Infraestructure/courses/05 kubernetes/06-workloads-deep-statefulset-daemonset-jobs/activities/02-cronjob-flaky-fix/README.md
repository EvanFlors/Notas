# k8s-06-02 — `CronJob` con overlaps: diagnosticar y arreglar (debug)

## 1. Identificación

- **ID:** `k8s-06-02-cronjob-flaky-fix`
- **Tecnología:** kubernetes
- **Módulo:** `06-workloads-deep-statefulset-daemonset-jobs`
- **Dificultad:** intermediate
- **Duración estimada:** 45 min
- **Tipo:** independent (debug)

## 2. Contexto

Un compañero ha dejado desplegado un `CronJob` en el cluster que, según él, "corre cada minuto y hace una limpieza rápida". En realidad el comando tarda **~90 s** (más que el intervalo), y como el `concurrencyPolicy` es `Allow` (el default), empiezan a solaparse ejecuciones. En producción esto habría corrompido estado compartido; aquí, por suerte, solo verás una pila creciente de Pods.

Debes:

1. Reproducir el problema aplicando el `starter/cronjob.yaml`.
2. **Diagnosticar** el overlap observando `kubectl get jobs` tras un par de minutos.
3. **Elegir** entre `Forbid` o `Replace` y aplicar el fix (sin cambiar el `schedule` ni el comando: no es tu rol).
4. Fijar un `startingDeadlineSeconds` razonable para no acumular ejecuciones si el scheduler se atrasa.

Esta es una actividad **independiente**: no se te da la solución paso a paso. Hay un `solution/` para que te verifiques *después*, no antes.

## 3. Objetivos

- Reconocer un patrón de overlap en un `CronJob`.
- Elegir conscientemente `concurrencyPolicy` según el tipo de carga.
- Justificar `startingDeadlineSeconds`.

## 4. Prerrequisitos

- Cluster `kind` corriendo.
- `kubectl` configurado.
- Un namespace limpio donde trabajar. Usaremos `cronjob-lab`:
  ```bash
  kubectl create namespace cronjob-lab --dry-run=client -o yaml | kubectl apply -f -
  ```
- 5 min para observar el overlap y 5 min más tras el fix para verificar.
- Sin costo.

## 5. Instrucciones

> **No** cambies el nombre del `CronJob` (`slow-cleanup`) ni el namespace (`cronjob-lab`). El validador los busca por nombre.

### Paso 1 — reproducir el problema

```bash
kubectl apply -f starter/cronjob.yaml
# El CronJob corre cada 1 min y cada ejecución tarda ~90 s.
```

Espera 3 minutos y observa:

```bash
kubectl -n cronjob-lab get cronjob slow-cleanup
kubectl -n cronjob-lab get jobs
kubectl -n cronjob-lab get pods
kubectl -n cronjob-lab describe cronjob slow-cleanup | tail -30
```

Deberías ver **varios Pods corriendo simultáneamente**. Ese es el bug.

### Paso 2 — diagnosticar

En `/tmp/k8s-06-02/diagnostico.md` escribe:

```markdown
# Diagnóstico

- Síntoma observado:
- Causa raíz (campo del manifest + comportamiento del controller):
- Opciones de fix consideradas (Forbid vs Replace, por qué una u otra):
- Fix aplicado:
```

El validador comprueba que el archivo existe y menciona `concurrencyPolicy`.

### Paso 3 — aplicar el fix

**Edita** el `CronJob` para:

- Cambiar `concurrencyPolicy` a **`Forbid`** o **`Replace`** (tú decides, justifica en el `diagnostico.md`).
- Fijar `startingDeadlineSeconds` a un valor razonable (entre 10 y 300).

**No** cambies:

- `schedule` (sigue siendo `*/1 * * * *`).
- El comando (sigue tardando ~90 s — el fix *no* es acelerar el job).
- El `namespace` (`cronjob-lab`) ni el `name` (`slow-cleanup`).

Aplica con `kubectl apply -f <tu-manifest>.yaml`.

### Paso 4 — verificar

Espera 3 minutos tras aplicar el fix y verifica que **no haya más de un Pod activo a la vez**:

```bash
kubectl -n cronjob-lab get pods -l job-name --field-selector=status.phase=Running
```

### Paso 5 — validar

```bash
bash /ruta/al/repo/courses/kubernetes/06-workloads-deep-statefulset-daemonset-jobs/activities/02-cronjob-flaky-fix/tests/validate.sh
```

## 6. Resultado esperado

- `kubectl -n cronjob-lab get cronjob slow-cleanup -o jsonpath='{.spec.concurrencyPolicy}'` devuelve `Forbid` **o** `Replace`.
- `kubectl -n cronjob-lab get cronjob slow-cleanup -o jsonpath='{.spec.startingDeadlineSeconds}'` devuelve un número en el rango `[10, 300]`.
- Tras varios minutos no hay más de **un** Pod del CronJob corriendo a la vez (si elegiste `Forbid`, puede incluso haber cero mientras se solapa; si `Replace`, siempre a lo sumo uno).
- `/tmp/k8s-06-02/diagnostico.md` existe y menciona `concurrencyPolicy`.

## 7. Criterios de aceptación

- `tests/validate.sh` imprime `RESULT: PASS`.
- No tocaste el `schedule` ni el nombre del CronJob.
- `diagnostico.md` tiene justificación coherente de **por qué** elegiste `Forbid` vs `Replace`.

## 8. Validación

```bash
bash courses/kubernetes/06-workloads-deep-statefulset-daemonset-jobs/activities/02-cronjob-flaky-fix/tests/validate.sh
```

## 9. Preguntas de reflexión

1. Para un job que **sincroniza estado desde una API externa** (lo que importa es la foto más reciente), ¿qué eliges, `Forbid` o `Replace`? ¿Por qué?
2. Para un job que **procesa una cola transaccional idempotente**, ¿cambiaría tu elección?
3. ¿Qué pasa si pones `startingDeadlineSeconds: 10` y el scheduler está caído 2 minutos? ¿Y con `startingDeadlineSeconds` sin definir?
4. El `schedule` dice `*/1 * * * *` pero no hay `timeZone`. ¿En qué horario corre si tu reloj está en Madrid?
5. `concurrencyPolicy: Allow` nunca es la respuesta correcta — ¿verdadero o falso? Justifica.

## 10. Extensiones

- Añade `successfulJobsHistoryLimit: 1` y `failedJobsHistoryLimit: 1` y observa cómo cambia `kubectl get jobs`.
- Prueba `kubectl patch cronjob slow-cleanup -p '{"spec":{"suspend":true}}'` y verifica que no se crean nuevos Jobs.
- Añade `activeDeadlineSeconds: 60` al jobTemplate y mira qué pasa cuando un Pod sobrepasa ese tiempo.

## 11. Limpieza

```bash
kubectl delete namespace cronjob-lab --ignore-not-found
rm -rf /tmp/k8s-06-02
```
