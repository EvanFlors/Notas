# k8s-14-01 — Escribir un operador Echo con Kubebuilder

## 1. Identificación
- **ID:** `k8s-14-01-write-echo-operator-with-kubebuilder`
- **Tecnología:** kubernetes
- **Módulo:** `14-operators-and-crds`
- **Dificultad:** advanced
- **Duración estimada:** 180 min
- **Tipo:** mini-project

## 2. Contexto

Vas a construir un operador mínimo — pero *de verdad* — que reconcilia una CRD `Echo` creando un `ConfigMap` con su mensaje. Es el "hello world" del operator pattern y entrena todo lo esencial: diseñar el CRD, implementar `Reconcile`, establecer `ownerReferences`, actualizar `status`, probarlo contra un cluster real.

Si no tienes toolchain Go instalado, el starter degrada grácilmente a un **modo documentación**: escribirás la CRD YAML y el pseudocódigo del `Reconcile` en `EVALUATION.md` (sic — reutilizamos el nombre), y los tests aceptan ese entregable alternativo.

## 3. Objetivos

Al terminar debes poder:

- Explicar qué habilita `subresources.status: {}` en un CRD.
- Escribir un `Reconcile` idempotente que crea-o-actualiza un recurso hijo.
- Establecer `ownerReferences` correctamente para que el GC haga su trabajo.
- Actualizar `status` sin pisar `spec`.
- Degradar a documentación cuando la toolchain falta.

## 4. Prerrequisitos

- **Software**:
  - `kubectl` (siempre).
  - `kind` (recomendado) o `k3d` para cluster local.
  - **Camino A (recomendado)**: Go ≥ 1.22, `kubebuilder` ≥ 4.x.
  - **Camino B (fallback)**: ninguno extra — solo editor de texto.
- **Permisos**: Docker/Podman local para kind. Sin AWS/GCP.
- **Costos**: cero.

Comprueba:

```bash
kubectl version --client
kind version
go version         # opcional
kubebuilder version   # opcional
```

## 5. Instrucciones

### Setup

```bash
cd starter/
bash setup.sh          # detecta Go/Kubebuilder y te dice qué camino tomar
```

El script decide:
- Si encuentra Go + Kubebuilder → copia el scaffold a `/tmp/k8s-14-echo-operator/` y te deja listos la CRD base + el `Reconcile` con TODOs.
- Si no → te deja en modo documentación: edita `EVALUATION.md` en el starter.

### Camino A — Implementación con Kubebuilder

1. Lee `starter/kubebuilder-scaffold/api/v1alpha1/echo_types.go`. Entiende qué campos tiene `EchoSpec` y `EchoStatus`.
2. Lee `starter/kubebuilder-scaffold/internal/controller/echo_controller.go`. Verás TODOs marcados `// TODO (student)`.
3. Implementa el `Reconcile` para:
   - Leer el `Echo`.
   - Construir el `ConfigMap` deseado con `data["message"] = echo.Spec.Message` y nombre `<echo-name>-echo`.
   - Establecer `ctrl.SetControllerReference(&echo, cm, r.Scheme)`.
   - Crear-o-actualizar el `ConfigMap`.
   - Actualizar `status.observedMessage` y `status.lastReconciledAt` vía `r.Status().Update(...)`.
4. Prueba contra kind:

```bash
cd /tmp/k8s-14-echo-operator
make install                   # aplica la CRD
make run &                     # corre el controller fuera del cluster
kubectl apply -f config/samples/demo_v1alpha1_echo.yaml
kubectl get echoes
kubectl get configmap hello-echo -o yaml
```

5. Edita el `Echo` (`kubectl edit echo hello` y cambia el mensaje) y verifica que el ConfigMap se actualiza.
6. Borra el `Echo` y verifica que el `ConfigMap` desaparece (garbage collection via ownerReferences).

### Camino B — Modo documentación

Si `setup.sh` no detectó Go/Kubebuilder, edita `starter/EVALUATION.md` siguiendo las secciones marcadas. Debes:

1. Escribir la **CRD YAML completa** para `Echo` (puedes basarte en `examples/01-crd-echo-controller/crd-echo.yaml`).
2. Escribir el **pseudocódigo del `Reconcile`** con los pasos: fetch, build desired, SetControllerReference, create-or-update, StatusUpdate.
3. Responder las **preguntas de reflexión**.
4. Opcionalmente aplica la CRD a kind y crea un CR, aunque sin controller no haga nada.

### Validación

```bash
bash tests/validate.sh
```

El script detecta tu modo y valida en consecuencia.

## 6. Resultado esperado

**Camino A**: operador corriendo (`make run`), CR `hello` creado, ConfigMap `hello-echo` presente con `data.message` igual al `spec.message`, `status.observedMessage` igual también, GC verificado.

**Camino B**: `starter/EVALUATION.md` con las secciones requeridas completas y la CRD aplicada opcionalmente.

## 7. Criterios de aceptación

- CRD con `subresources.status: {}` y printer columns.
- `Reconcile` idempotente (ejecutarlo múltiples veces sin crear duplicados).
- `ownerReferences` establecidos → borrado en cascada.
- `status` actualizado vía `/status`, no vía `Update` del objeto completo.
- Pseudocódigo (si camino B) menciona los 4 pasos clave.

## 8. Validación

```bash
bash tests/validate.sh
```

Salida esperada: `RESULT: OK (mode: A)` o `RESULT: OK (mode: B)`.

## 9. Preguntas de reflexión

1. ¿Qué pasa si olvidas `SetControllerReference`? ¿Cuándo se nota?
2. ¿Qué pasa si llamas `r.Update(ctx, &echo)` en vez de `r.Status().Update(ctx, &echo)`?
3. ¿Por qué el `Reconcile` debe ser idempotente aunque haya watchers que lo disparan solo en cambios?
4. ¿Por qué el starter no corre el operador *dentro* del cluster inicialmente (usa `make run` local)? ¿Cuándo pasarías a desplegarlo in-cluster?
5. ¿Cómo probarías el `Reconcile` sin cluster (envtest)?

## 10. Extensiones

- Añade un **finalizer** para loggear un mensaje antes del delete.
- Añade un **watcher** sobre `ConfigMap` para que si alguien edita el CM a mano, el controller lo reponga.
- Añade **métricas Prometheus** (`reconcile_total`, `reconcile_errors_total`).
- Versiona la CRD a `v1beta1` y escribe un **conversion webhook** no-op.
- Añade tests con **envtest** en `internal/controller/echo_controller_test.go`.

## 11. Limpieza

```bash
# si creaste un cluster kind
kind delete cluster --name k8s-14-echo-op

# scratch dir
rm -rf /tmp/k8s-14-echo-operator
```
