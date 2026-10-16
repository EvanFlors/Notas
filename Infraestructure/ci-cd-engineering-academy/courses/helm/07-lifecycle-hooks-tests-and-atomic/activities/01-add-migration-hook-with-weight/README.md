# Actividad 01 — Añadir hook de migración con weight y delete-policy

## 1. Identificación

- **ID:** `helm-07-01-add-migration-hook-with-weight`
- **Tecnología:** `helm`
- **Módulo:** `helm-07-lifecycle-hooks-tests-and-atomic`
- **Dificultad:** advanced
- **Duración estimada:** 50 min
- **Tipo:** guided-lab

## 2. Contexto

El `starter/` contiene un chart `migration-lab` con un `Deployment` y un `Job` llamado `migrate-schema`. El `Job` está declarado como un recurso **regular**, no como un hook. En producción esto significa que el `Job` se aplica *en paralelo* con el `Deployment` y Helm no espera a que la migración complete antes de arrancar los Pods de la nueva versión. Es un bug clásico.

Tu tarea: convertir ese `Job` en un **hook** `pre-install,pre-upgrade` correcto, con el weight y la delete-policy apropiados.

## 3. Objetivos

- Convertir un `Job` regular en un hook con las anotaciones correctas.
- Elegir un **weight** que exprese "esto debe correr antes".
- Aplicar `before-hook-creation,hook-succeeded` como delete-policy.
- Verificar la diferencia con `helm get manifest` (no aparece) vs `helm get hooks` (sí aparece).

## 4. Prerrequisitos

- `helm` ≥ 3.14 (idealmente 4.x).
- `kubectl` apuntando a un cluster `kind` o similar funcional.
- `kind` (si no hay cluster, crear uno: `kind create cluster --name helm07`).
- No requiere acceso a cloud ni cuesta dinero.

## 5. Instrucciones

1. **Setup del directorio de trabajo:**
   ```sh
   mkdir -p /tmp/helm07-act01
   cp -r starter/migration-lab /tmp/helm07-act01/
   cd /tmp/helm07-act01/migration-lab
   ```
2. **Inspeccionar el estado inicial:**
   ```sh
   helm template demo .
   ```
   Observa que el `Job` `migrate-schema` sale junto con el `Deployment`. No tiene anotación `helm.sh/hook`.
3. **Modificar `templates/migrate-job.yaml`:**
   - Añadir en `metadata.annotations` las anotaciones:
     - `"helm.sh/hook": pre-install,pre-upgrade`
     - `"helm.sh/hook-weight": "-5"` (debe correr *antes* de otros hooks de la misma fase si los hubiera; weight negativo es idiomático para "early").
     - `"helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded`
4. **Re-renderizar y validar que las anotaciones están presentes:**
   ```sh
   helm template demo .
   ```
5. **Instalar y verificar:**
   ```sh
   helm install demo . --namespace lab --create-namespace --wait --timeout 3m
   helm get manifest demo -n lab | grep -c migrate-schema   # debe ser 0
   helm get hooks   demo -n lab | grep -c migrate-schema    # debe ser >= 1
   ```
6. **Validar automáticamente:**
   ```sh
   bash <ruta-a-esta-actividad>/tests/validate.sh /tmp/helm07-act01
   ```

## 6. Resultado esperado

- `helm template` muestra el `Job` con las tres anotaciones de hook.
- Tras `helm install`, `helm get manifest` **no** incluye el `Job` (es un hook, no un recurso del release).
- `helm get hooks` sí lo lista con `kind: Job`.
- El `Job` corre antes del `Deployment`; el `Deployment` queda `Ready`.

## 7. Criterios de aceptación

- Anotaciones `helm.sh/hook`, `helm.sh/hook-weight`, `helm.sh/hook-delete-policy` presentes y con los valores especificados.
- `helm install` completa sin error con `--wait`.
- El validador reporta `OK: 1/1`.

## 8. Validación

```sh
bash tests/validate.sh /tmp/helm07-act01
```

El validador:
- Verifica que `/tmp/helm07-act01/migration-lab` existe con el chart.
- Hace `helm template` y comprueba las anotaciones en el `Job`.
- Hace `helm install` en un namespace temporal `helm07-act01`, comprueba `helm get hooks` vs `helm get manifest`, y uninstala.

## 9. Preguntas de reflexión

- ¿Qué pasaría si olvidaras `pre-upgrade` y solo pusieras `pre-install`? ¿Cuándo se rompe el sistema?
- ¿Qué pasa si no usas `before-hook-creation` y re-corres el upgrade dos veces seguidas?
- ¿Por qué `backoffLimit: 0` es la convención para `Job` de migración? ¿Qué quieres evitar?
- Si la migración tarda 20 min, ¿afecta tu valor de `--timeout`? ¿Y la decisión hook vs `initContainer`?

## 10. Extensiones

- Añadir un `pre-upgrade` hook adicional que haga un backup (`pg_dump`) con weight `-10` para que corra antes de la migración (sin necesidad de otro `backoffLimit`).
- Modelar el fallo: cambiar el comando del `Job` a `exit 1` y observar que el upgrade falla y el `Deployment` **no** se actualiza.
- Añadir `hook-failed` a la delete-policy y observar qué cambia respecto a la depuración.

## 11. Limpieza

```sh
helm uninstall demo -n lab 2>/dev/null || true
kubectl delete ns lab --wait=false 2>/dev/null || true
kubectl delete ns helm07-act01 --wait=false 2>/dev/null || true
rm -rf /tmp/helm07-act01
```
