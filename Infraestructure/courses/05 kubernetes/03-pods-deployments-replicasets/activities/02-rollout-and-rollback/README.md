# k8s-03-02 — Rollouts encadenados y rollback a revisión intermedia

## 1. Identificación

- **ID:** `k8s-03-02-rollout-and-rollback`
- **Tecnología:** kubernetes
- **Módulo:** `03-pods-deployments-replicasets`
- **Dificultad:** beginner
- **Duración estimada:** 45 min
- **Tipo:** independent

## 2. Contexto

En producción, cuando un rollout va mal, lo que se hace **primero** no es diagnosticar: es **revertir**. A veces hay que revertir no "a la anterior" sino "a la de hace dos", porque la anterior también introdujo un problema distinto. Esta actividad simula ese flujo: tres rollouts consecutivos con imágenes diferentes, y rollback a la **revisión 2** usando `kubectl rollout undo --to-revision=2`.

A diferencia de la actividad 01, aquí no te damos un starter con huecos ni te decimos cada comando. Lo que debes dejar funcionando está especificado por el validador — tu trabajo es llegar ahí.

## 3. Objetivos

Al terminar deberías poder:

- Encadenar varios rollouts (`kubectl set image`) sobre el mismo Deployment.
- Leer `kubectl rollout history` y mapear revisiones a imágenes.
- Revertir a una revisión concreta con `kubectl rollout undo --to-revision=N`.
- Verificar que el estado final del Deployment refleja la revisión destino.

## 4. Prerrequisitos

- Haber completado `k8s-03-01-deploy-fastapi` (reutilizas el patrón de Deployment).
- `kubectl` ≥ 1.28 con cluster local accesible.

Si no hay cluster, el validador imprime `SKIP` y sale 0.

## 5. Instrucciones

Trabaja en `/tmp/k8s-03-02/`:

```bash
mkdir -p /tmp/k8s-03-02 && cd /tmp/k8s-03-02
```

### Lo que debes lograr

En el namespace `k8s-03-02`, dejar un Deployment llamado `rollout-demo` con estas propiedades verificables:

- 3 réplicas Ready.
- Imagen actual del contenedor `web`: **`nginx:1.26-alpine`**.
- Historial con **≥ 4 revisiones**.
- Debe haber habido al menos una operación `rollout undo` (puedes anotarla como `change-cause`).

### Camino sugerido (no es la única solución)

1. Crea el namespace `k8s-03-02` y aplica un Deployment inicial `rollout-demo` con imagen **`nginx:1.25-alpine`**, 3 réplicas, strategy `RollingUpdate`, `maxSurge: 1`, `maxUnavailable: 0`, selector/labels `app: rollout-demo`.
2. Rollout a **`nginx:1.26-alpine`** → `kubectl set image ...`. Anota `change-cause`. `rollout status`.
3. Rollout a **`nginx:1.27-alpine`** → igual.
4. Rollout a **`nginxdemos/hello:plain-text`** → igual.
5. `kubectl rollout history deployment/rollout-demo -n k8s-03-02` → identifica qué revisión tiene `nginx:1.26-alpine` (debería ser la 2 si seguiste el orden anterior).
6. `kubectl rollout undo deployment/rollout-demo -n k8s-03-02 --to-revision=<N>`.
7. `kubectl rollout status ...`.
8. Verifica con `kubectl get deployment rollout-demo -n k8s-03-02 -o jsonpath='{.spec.template.spec.containers[0].image}'` que la imagen es `nginx:1.26-alpine`.

**Nota sobre el comportamiento de `--to-revision`**: tras `undo --to-revision=N`, la revisión N "se mueve" al final del historial como una revisión nueva (no la verás con el número N; verás una nueva al final con el mismo template). Esto es correcto.

### Validar

```bash
bash courses/kubernetes/03-pods-deployments-replicasets/activities/02-rollout-and-rollback/tests/validate.sh
```

## 6. Resultado esperado

- `kubectl get deployment rollout-demo -n k8s-03-02 -o jsonpath='{.spec.template.spec.containers[0].image}'` → `nginx:1.26-alpine`.
- `kubectl rollout history deployment/rollout-demo -n k8s-03-02` → ≥ 4 líneas de revisión.
- `kubectl rollout status deployment/rollout-demo -n k8s-03-02` → `successfully rolled out`.
- 3 Pods `Running` bajo `-l app=rollout-demo`.

## 7. Criterios de aceptación

- La imagen final sale de un **`rollout undo`**, no de un `set image nginx:1.26-alpine` nuevo (eso crearía una revisión más alta y sería trampa en el espíritu de la actividad; aunque el validador acepta el estado, el objetivo pedagógico es ejercitar `undo`).
- Hay anotaciones `kubernetes.io/change-cause` en al menos un rollout (buena práctica — no la verifica el validador pero quedará evaluado si pides revisión humana).
- Limpieza del namespace al terminar.

## 8. Validación

```bash
bash courses/kubernetes/03-pods-deployments-replicasets/activities/02-rollout-and-rollback/tests/validate.sh
```

El script imprime `SKIP` (exit 0) si no hay `kubectl` o no hay cluster.

## 9. Preguntas de reflexión

1. Tras `undo --to-revision=2`, ¿sigue existiendo la "revisión 2" en el historial? Explica qué pasó con sus números.
2. Si en vez de `--to-revision=2` hubieras hecho `kubectl set image web=nginx:1.26-alpine`, el estado final sería el mismo. ¿Por qué entonces nos molestamos en aprender `undo`?
3. Con `revisionHistoryLimit: 2`, ¿habrías podido hacer `undo --to-revision=1`? ¿Qué habría devuelto el apiserver?
4. En un pipeline de CI/CD, ¿quién debería emitir el `rollout undo`? ¿El pipeline mismo? ¿Un humano? ¿Argo Rollouts?

## 10. Extensiones

- Anota cada rollout con `kubernetes.io/change-cause` y verifica que aparece en `rollout history`.
- Haz un rollout a una imagen inexistente (`nginx:does-not-exist`). Observa el `ImagePullBackOff` en el Pod nuevo. Revierte sin tocar nada más.
- Pausa un rollout a mitad (`kubectl rollout pause`), hazle `set image` + `set env` + `set resources`, luego `resume`. Verifica que es **una** sola revisión nueva.

## 11. Limpieza

```bash
kubectl delete namespace k8s-03-02 --ignore-not-found
rm -rf /tmp/k8s-03-02
```
