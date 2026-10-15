# EVALUATION — reference answers (modo B)

> Solución de referencia del camino B.

## 1. CRD YAML completa

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: echoes.demo.academy.io
spec:
  group: demo.academy.io
  names:
    plural: echoes
    singular: echo
    kind: Echo
    shortNames: [ec]
  scope: Namespaced
  versions:
    - name: v1alpha1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          required: [spec]
          properties:
            spec:
              type: object
              required: [message]
              properties:
                message:
                  type: string
                  minLength: 1
                  maxLength: 256
            status:
              type: object
              properties:
                observedMessage: { type: string }
                lastReconciledAt: { type: string, format: date-time }
      subresources:
        status: {}
      additionalPrinterColumns:
        - name: Message
          type: string
          jsonPath: .spec.message
        - name: Observed
          type: string
          jsonPath: .status.observedMessage
```

## 2. Pseudocódigo del Reconcile

```
Reconcile(ctx, req):
    echo = Get(Echo, req.NamespacedName)
    if NotFound(echo): return nil     # CR deleted; GC via ownerReferences

    cm = ConfigMap{
        name:      echo.name + "-echo",
        namespace: echo.namespace,
        data:      { "message": echo.spec.message },
    }
    SetControllerReference(owner=echo, child=cm)

    existing = Get(ConfigMap, cm.key)
    if NotFound(existing): Create(cm)
    else if existing.data["message"] != cm.data["message"]:
        existing.data = cm.data
        Update(existing)

    echo.status.observedMessage  = echo.spec.message
    echo.status.lastReconciledAt = now()
    r.Status().Update(echo)           # NOT r.Update()
    return nil
```

## 3. Respuestas

### 3.1 Sin `SetControllerReference`
El `ConfigMap` queda sin padre. Al borrar el `Echo`, el garbage collector no lo elimina y queda huérfano en el namespace para siempre. Se nota la primera vez que un usuario borra un `Echo` y descubre que su `ConfigMap` sigue ahí.

### 3.2 `r.Status().Update` vs `r.Update`
`r.Update` apunta al endpoint principal del recurso. Si la CRD tiene `subresources.status: {}`, el apiserver **ignora** los cambios en `.status` al llegar por `Update`; solo persiste cambios de `spec`/metadata. Para persistir `.status` hay que llamar al endpoint `/status`, que es lo que `r.Status().Update` hace.

### 3.3 Idempotencia
El workqueue puede entregar el mismo item varias veces (resync periódico, reconexión del watcher, retries por errores transitorios). Si `Reconcile` no es idempotente, cada reconciliación extra crea recursos duplicados o corrompe estado.

### 3.4 RBAC
- `demo.academy.io/echoes` → `get, list, watch, update, patch`.
- `demo.academy.io/echoes/status` → `get, update, patch`.
- `""` (core) `configmaps` → `get, list, watch, create, update, patch, delete`.
- `""/events` → `create, patch` si emites Kubernetes Events.
