# Reconcile pseudocode — Echo controller

Pseudo-Go para que se entienda sin depender del framework exacto.

```
Reconcile(ctx, req):
    # 1. Fetch the CR.
    echo = Get(Echo, req.NamespacedName)
    if NotFound(echo):
        return Done        # CR deleted; owned ConfigMap is GC'd via ownerReferences

    # 2. Build the desired child object.
    cm = ConfigMap{
        name:      echo.name + "-echo",
        namespace: echo.namespace,
        data:      { "message": echo.spec.message },
        labels:    { "app.kubernetes.io/managed-by": "echo-operator",
                     "echoes.demo.academy.io/name":  echo.name },
    }
    SetControllerReference(owner=echo, child=cm)   # ownerRef + blockOwnerDeletion

    # 3. Create or update (idempotent).
    existing = Get(ConfigMap, cm.key)
    if NotFound(existing):
        Create(cm)
    else if existing.data["message"] != cm.data["message"]:
        existing.data = cm.data
        Update(existing)

    # 4. Update status via the /status subresource.
    echo.status.observedMessage   = echo.spec.message
    echo.status.lastReconciledAt  = now()
    SetCondition(echo, type="Ready", status="True", reason="Reconciled",
                 message="ConfigMap in sync")
    StatusUpdate(echo)              # NOT a plain Update()

    return Done
```

## Puntos de atención

- **IgnoreNotFound** en el `Get` inicial: el watch puede dispararse justo después del delete.
- **SetControllerReference**: sin eso, borrar el `Echo` deja el `ConfigMap` colgando.
- **CreateOrUpdate** idempotente: `Reconcile` se puede ejecutar muchas veces por minuto.
- **`StatusUpdate` separado**: olvidarlo es el bug #1 de operadores novatos — el `/status` necesita su propio call.
- **Resync periódico**: aunque no haya eventos, el controller re-reconcilia cada `SyncPeriod` para corregir drift que el watcher no vio.

## Qué faltaría en un operador "serio"

- Finalizer para hacer cleanup antes del delete.
- Watcher sobre `ConfigMap` para re-reconciliar si alguien lo edita a mano.
- Métricas Prometheus (`reconcile_total`, `reconcile_errors_total`, histogram de duración).
- Leader election si corres >1 réplica del operador.
- Rate limiting y backoff en el workqueue.
- Validating/mutating webhooks para defaults e invariantes.
