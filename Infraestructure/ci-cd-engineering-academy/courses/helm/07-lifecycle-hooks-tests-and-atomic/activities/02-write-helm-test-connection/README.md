# Actividad 02 — Escribir un helm test que haga wget al Service

## 1. Identificación

- **ID:** `helm-07-02-write-helm-test-connection`
- **Tecnología:** `helm`
- **Módulo:** `helm-07-lifecycle-hooks-tests-and-atomic`
- **Dificultad:** advanced
- **Duración estimada:** 40 min
- **Tipo:** independent

## 2. Contexto

El `starter/` contiene el chart `wtest-lab`: un `Deployment` de nginx + un `Service` ClusterIP. **No tiene `templates/tests/`**. Tu trabajo es añadir un manifiesto `templates/tests/test-connection.yaml` (un Pod efímero con `helm.sh/hook: test`) que haga `wget` contra el `Service` y retorne 0 si la app responde.

Esta actividad es **independiente**: no te decimos exactamente el YAML a escribir. Resuelve con la documentación de hooks y chart tests, y con tu intuición. El validador instala el chart y corre `helm test` — si pasa, has acertado.

## 3. Objetivos

- Diseñar un Pod `test` que ejerza un `Service` dentro del cluster.
- Elegir una imagen minimal con `wget` disponible (p. ej. `busybox`).
- Aplicar las anotaciones de hook correctas (`helm.sh/hook: test`, `helm.sh/hook-delete-policy`).
- Construir la URL del `Service` combinando el nombre renderizado del chart (`include "<chart>.fullname"`) y el puerto desde `.Values.service.port`.

## 4. Prerrequisitos

- `helm` ≥ 3.14 (idealmente 4.x), `kubectl`, `kind`.
- Un cluster `kind` corriendo (si no, `kind create cluster --name helm07`).
- No requiere acceso a cloud ni cuesta dinero.

## 5. Instrucciones

1. Copia el starter a tu directorio de trabajo:
   ```sh
   mkdir -p /tmp/helm07-act02
   cp -r starter/wtest-lab /tmp/helm07-act02/
   cd /tmp/helm07-act02/wtest-lab
   ```
2. Inspecciona el chart existente — fíjate en `_helpers.tpl` (hay un `include "wtest-lab.fullname"`) y en `values.yaml` (hay `service.port`).
3. **Crea el archivo** `templates/tests/test-connection.yaml`. Debe:
   - Ser un `apiVersion: v1`, `kind: Pod`.
   - Tener en `metadata.annotations` las anotaciones de hook de un test, con `hook-delete-policy` que elimine el Pod en éxito (y permita rerun).
   - Correr una imagen con `wget` disponible (p. ej. `busybox:1.36`).
   - Hacer `wget --spider` (o equivalente) contra el `Service` del release en el puerto configurado.
   - Tener `restartPolicy: Never` (para que un fallo del comando no haga re-arrancar el Pod).
4. Instala y corre `helm test`:
   ```sh
   helm install wtest . --namespace wtest --create-namespace --wait --timeout 3m
   helm test wtest --namespace wtest
   ```
5. Si todo pasó, corre el validador:
   ```sh
   bash <ruta-a-esta-actividad>/tests/validate.sh /tmp/helm07-act02
   ```

**No consultes `solution/` hasta terminar.**

## 6. Resultado esperado

- `helm test wtest -n wtest` retorna 0 y reporta `Phase: Succeeded`.
- `helm get hooks wtest -n wtest` lista el Pod de test.
- Tras `helm test`, el Pod ha desaparecido del cluster (delete-policy `hook-succeeded`).

## 7. Criterios de aceptación

- Existe `templates/tests/test-connection.yaml`.
- `helm template` renderiza un Pod con `helm.sh/hook: test`.
- `helm install` + `helm test` completan con éxito.

## 8. Validación

```sh
bash tests/validate.sh /tmp/helm07-act02
```

El validador:
- Verifica que `/tmp/helm07-act02/wtest-lab/templates/tests/test-connection.yaml` existe.
- Verifica que el render incluye `helm.sh/hook: test`.
- Instala el chart en un namespace temporal y corre `helm test`; falla si no pasa.

## 9. Preguntas de reflexión

- ¿Por qué `restartPolicy: Never` y no `OnFailure`?
- ¿Qué pasa si tu Pod de test no incluye `hook-delete-policy`? ¿Qué deja en el cluster?
- `wget --spider` solo verifica que haya respuesta HTTP; ¿cómo lo evolucionarías para verificar contenido ("200 OK con body que contenga X")?
- Si quisieras validar también la conectividad a una DB interna, ¿lo harías en el mismo Pod de test o en otro? ¿Por qué?

## 10. Extensiones

- Añadir un segundo Pod de test que use `curl` en lugar de `wget` y valide el body.
- Añadir un `helm.sh/hook-weight` para forzar el orden entre múltiples tests.
- Convertir el Pod en un `Job` con `backoffLimit: 1` y observar la diferencia.

## 11. Limpieza

```sh
helm uninstall wtest -n wtest 2>/dev/null || true
kubectl delete ns wtest --wait=false 2>/dev/null || true
kubectl delete ns helm07-act02 --wait=false 2>/dev/null || true
rm -rf /tmp/helm07-act02
```
