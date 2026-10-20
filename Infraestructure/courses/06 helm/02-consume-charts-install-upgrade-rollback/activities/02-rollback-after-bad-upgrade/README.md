# helm-02-02 — Rollback después de un upgrade roto

## 1. Identificación

- **ID:** `helm-02-02-rollback-after-bad-upgrade`
- **Tecnología:** helm
- **Módulo:** `02-consume-charts-install-upgrade-rollback`
- **Dificultad:** beginner
- **Duración estimada:** 50 min
- **Tipo:** independent

## 2. Contexto

El escenario clásico: un chart está instalado y funcionando; aplicas un upgrade con un cambio de configuración que resulta estar roto; el release queda en mal estado; necesitas **devolverlo al estado anterior** con disciplina usando `helm history` + `helm rollback`.

El validador no te dirá los comandos exactos. Confirma solo el estado final: hay un release con **tres o más revisiones**, la **última es un rollback a la revisión 1** (su contenido coincide con el de la revisión 1), y los recursos en el cluster reflejan el estado restaurado.

## 3. Objetivos

Al terminar deberías poder:

- Diseñar un upgrade "problemático" controlado (sin romper el cluster), confirmar el problema, y revertirlo.
- Leer `helm history` como un log para elegir el target de rollback.
- Explicar por qué el rollback **crea una revisión nueva** en vez de "borrar" la mala.

## 4. Prerrequisitos

- Un cluster local kind corriendo.
- `helm` ≥ 3.14, `kubectl` ≥ 1.28, Docker.
- Haber completado `helm-02-01` (instalación básica con `--version` y `--namespace`).
- Sin costo monetario.

Si falta cualquier herramienta o no hay cluster, el validador imprime `SKIP`.

## 5. Instrucciones

Trabaja en `/tmp/helm-02-02/`. **No te damos los comandos exactos.** Resuelve el reto con el contenido de la lección.

### Reto

1. Elige un chart "benigno" para experimentar (recomendado: `bitnami/nginx` o `ingress-nginx/ingress-nginx` — cualquiera sirve).
2. Instálalo como release `broken-app` en el namespace `rollback-lab` (créalo con `--create-namespace`), con una versión del chart **explícita** (`--version <SemVer>`). Esta es la **revisión 1 — el "buen estado"**.
3. Haz un `helm upgrade` que introduzca un **cambio de configuración claramente erróneo** sin que el `helm upgrade` falle de entrada. Dos recetas válidas (usa UNA):
   - **Receta A — imagen inexistente**: `--set image.tag=this-tag-does-not-exist-9999` (o el equivalente del chart que escojas, p. ej. `controller.image.tag`). Los Pods nuevos quedarán en `ImagePullBackOff` o `ErrImagePull`.
   - **Receta B — réplicas absurdas**: `--set replicaCount=0` (o `controller.replicaCount=0`). El Deployment escala a cero y el servicio deja de responder.
   Este será la **revisión 2 — el "mal estado"**.
4. **Confirma el problema**: con `kubectl get pods` o `kubectl get deploy` demuestra que algo no está bien respecto a la revisión 1 (pods no Ready, 0 réplicas, imagen rara, etc.).
5. Mira `helm history broken-app -n rollback-lab`. Identifica cuál es la revisión "buena".
6. Haz `helm rollback` a la revisión 1 (con `--wait`).
7. Verifica que ahora hay **al menos 3 revisiones**, la última en `deployed` y con `DESCRIPTION` empezando por `Rollback to`.
8. Verifica que los valores de la última revisión coinciden con los de la revisión 1 (`helm get values ... --revision N`).
9. Guarda `/tmp/helm-02-02/snapshot.md` con **estas secciones** (el validador busca los encabezados):

```markdown
# snapshot helm-02-02

## history
<salida de: helm history broken-app -n rollback-lab>

## values-rev1
<salida de: helm get values broken-app -n rollback-lab --revision 1>

## values-last
<salida de: helm get values broken-app -n rollback-lab --revision N (donde N es la última)>

## release-secrets
<salida de: kubectl get secret -n rollback-lab -l owner=helm>
```

### Pistas (no es la solución)

- `helm upgrade --install` sigue siendo la forma correcta de hacer el paso 2 y 3 (idempotencia).
- Si tu `helm upgrade` del paso 3 falla al render (p. ej. un typo en una key que el chart valida con `required`), no te servirá — necesitas un fallo **en runtime**, no en render. Las dos recetas de arriba hacen exactamente eso.
- El validador tolera que uses `--wait` o no en el paso 3 (receta A puede dar timeout; receta B no fallará). Lo que importa es que haya revisión 2.
- Para la receta A puede que necesites `--atomic=false` (es el default) para que no se auto-revierta antes de que puedas hacer el rollback a mano.

### Validar

```bash
bash courses/helm/02-consume-charts-install-upgrade-rollback/activities/02-rollback-after-bad-upgrade/tests/validate.sh
```

## 6. Resultado esperado

- `helm history broken-app -n rollback-lab` muestra **≥ 3 filas**.
- La fila con la revisión más alta está en `deployed` y su `DESCRIPTION` empieza por `Rollback to`.
- `helm get values --revision 1` y `helm get values --revision <última>` son **iguales**.
- `/tmp/helm-02-02/snapshot.md` existe con las 4 secciones esperadas.

## 7. Criterios de aceptación

- `tests/validate.sh` imprime `RESULT: PASS`.
- No eliminaste manualmente ningún Secret `sh.helm.release.v1.*`.
- Puedes explicar por qué `kubectl get secret -n rollback-lab -l owner=helm` muestra **N** Secrets donde N == número de revisiones, y por qué la última corresponde al estado "vivo".

## 8. Validación

```bash
bash courses/helm/02-consume-charts-install-upgrade-rollback/activities/02-rollback-after-bad-upgrade/tests/validate.sh
```

## 9. Preguntas de reflexión

1. ¿Por qué el `helm rollback` **crea** una revisión nueva en lugar de marcar la mala como "deshecha"? Da un argumento operacional (auditoría) y uno técnico (idempotencia).
2. En la receta A (imagen inexistente), el `helm upgrade` dio OK aunque los Pods nunca estuvieron Ready. ¿Qué flag(s) harían que el `helm upgrade` NO declare éxito en ese caso?
3. ¿Qué diferencia habría si antes del upgrade "roto" hubieras pasado `--atomic`? ¿Habrías necesitado hacer `helm rollback` a mano?
4. Si en lugar de un rollback hubieras hecho un `helm upgrade` revirtiendo los valores "a mano" (volver a `image.tag` o `replicaCount` sanos), ¿qué diferencia operativa hay respecto a `helm rollback`?
5. En el `kubectl get secret` del snapshot, cuenta los Secrets. ¿Cuál es `deployed` y cuáles `superseded`? Verifícalo con `kubectl get secret ... -o jsonpath='{.items[*].metadata.labels.status}'`.

## 10. Extensiones

- Repite el ejercicio pero añadiendo `--atomic --wait` al upgrade "roto" (receta A). Mira la historia: ¿qué estados ves?
- Simula "pérdida de estado": haz `kubectl delete secret -n rollback-lab sh.helm.release.v1.broken-app.v2` y mira cómo cambia `helm history`. Reconstruye la historia haciendo nuevos upgrades.
- Instala el plugin [helm-diff](https://github.com/databus23/helm-diff) y, antes del rollback, corre `helm diff rollback broken-app 1` — un diff real de lo que va a cambiar.

## 11. Limpieza

```bash
helm uninstall broken-app -n rollback-lab
kubectl delete namespace rollback-lab --ignore-not-found
rm -rf /tmp/helm-02-02
# Si creaste el cluster solo para esto:
# kind delete cluster --name helm-02
```
