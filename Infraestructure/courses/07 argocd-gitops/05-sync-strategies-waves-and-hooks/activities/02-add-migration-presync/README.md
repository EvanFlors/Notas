# Actividad 02 — Añadir un hook PreSync de migración

## 1. Identificación

- **ID:** `argo-05-02-add-migration-presync`
- **Tecnología:** `argocd-gitops`
- **Módulo:** `05-sync-strategies-waves-and-hooks`
- **Dificultad:** intermediate
- **Duración estimada:** 60 min
- **Tipo:** independent

## 2. Contexto

El `starter/` contiene un pequeño "app bundle" en `app/`:

- `app/deployment.yaml` — un `Deployment` que (ficticiamente) requiere que un schema de BD esté migrado antes de que sus pods arranquen.
- `app/service.yaml` — su `Service`.

No hay ningún `Job` de migración. Tu tarea: **crear un `Job` en `app/` que corra como hook `PreSync`** antes del rollout del `Deployment`.

Un operador senior te revisará el PR mirando específicamente:

1. La anotación `argocd.argoproj.io/hook: PreSync`.
2. Delete-policy correcta: `BeforeHookCreation,HookSucceeded`.
3. `backoffLimit: 0` y `restartPolicy: Never`.
4. Que el `Job` sea idempotente (una re-ejecución no rompe nada — el comando puede ser un `echo` o un `sleep` para el lab, lo que importa es la *forma*).

Esta actividad es **independent**: no te damos los pasos exactos. La teoría §6 y el `examples/03-presync-migration-job/` te dan todo lo necesario para resolverla sin ver la solución.

## 3. Objetivos

- Crear un recurso `Job` con las anotaciones de hook correctas.
- Elegir una delete-policy que combine idempotencia (re-sync no duplica) con retención de logs en fallo.
- Argumentar en 2 líneas por qué `backoffLimit: 0` es importante aquí.

## 4. Prerrequisitos

- `kubectl` instalado.
- Python 3 + PyYAML (para el validador estructural). Si falta, el validador saltará esos checks.
- Un cluster `kind` **opcional**: el validador aplicará los manifests con `--dry-run=server` si hay cluster y Argo CD; si no, SKIP.
- Sin costos.

## 5. Instrucciones

1. **Preparar el workspace:**

   ```sh
   mkdir -p /tmp/argo05-act02
   cp -r starter/* /tmp/argo05-act02/
   cd /tmp/argo05-act02
   ```

2. **Añadir un nuevo archivo** `app/migration-job.yaml` con:
   - `apiVersion: batch/v1`, `kind: Job`, `metadata.name: migrate`.
   - `metadata.namespace: presync-lab`.
   - Las anotaciones de hook (ver teoría §6).
   - `spec.backoffLimit: 0`.
   - `spec.template.spec.restartPolicy: Never`.
   - Un container con `image: busybox:1.36` y un `command` que simule la migración (p. ej. `sh -c "echo migrating; sleep 2; echo done"`).

3. **(Opcional) Probar en kind con Argo CD:**

   ```sh
   # Asume que ya publicaste app/ en un repo accesible por Argo CD y creaste la Application.
   kubectl -n presync-lab get jobs,pods
   # Debes ver el Job migrate completando ANTES de que arranquen los pods del Deployment.
   ```

4. **Validar:**

   ```sh
   bash <ruta-a-esta-actividad>/tests/validate.sh /tmp/argo05-act02
   ```

## 6. Resultado esperado

- Existe un archivo `app/migration-job.yaml` con un `Job` llamado `migrate`.
- El `Job` tiene las anotaciones:
  - `argocd.argoproj.io/hook: PreSync`
  - `argocd.argoproj.io/hook-delete-policy: BeforeHookCreation,HookSucceeded`
- `spec.backoffLimit: 0`.
- `spec.template.spec.restartPolicy: Never`.
- El validador reporta `RESULT: >=5 passed / 0 failed`.

## 7. Criterios de aceptación

- **Funcional:** el `Job` renderiza como YAML válido y, aplicado a un cluster con Argo CD, se ejecuta como hook antes del `Deployment`.
- **Correctness:** las cuatro propiedades listadas arriba están presentes y con los valores exactos.
- **Documentación:** el estudiante puede explicar por qué `backoffLimit: 0` es necesario y por qué `HookSucceeded` sin `HookFailed` es el default sensato.

## 8. Validación

```sh
bash tests/validate.sh /tmp/argo05-act02
```

El validador:
- Busca `app/migration-job.yaml`.
- Parsea el YAML y verifica las cuatro propiedades.
- Si hay cluster + Argo CD CRDs, aplica con `--dry-run=server` como humo adicional.
- SKIP de los checks de cluster si no hay.

## 9. Preguntas de reflexión

- ¿Por qué no usar un `initContainer` en el `Deployment` para la migración? Da dos razones concretas.
- Si tu migración tarda 15 min y el `--sync-timeout` default es 5 min, ¿qué pasa? ¿Cómo lo arreglas?
- ¿Qué cambia si pones `HookFailed` en la delete-policy? ¿Cuándo lo querrías?
- Si tienes dos hooks `PreSync` (backup + migrate), ¿cómo garantizas que el backup corra ANTES del migrate?

## 10. Extensiones

- Añadir un segundo hook `PreSync` de backup con `argocd.argoproj.io/sync-wave: "-10"` (el migrate quedaría en wave `-5`).
- Añadir un hook `PostSync` que haga un smoke `wget` al `Service` y falle si el status no es `200`.
- Añadir un hook `SyncFail` que mande una notificación (puede ser un `Job` con `echo "notify slack"`).

## 11. Limpieza

```sh
# Si aplicaste a un cluster:
kubectl delete ns presync-lab --wait=false 2>/dev/null || true
# Siempre:
rm -rf /tmp/argo05-act02
```
