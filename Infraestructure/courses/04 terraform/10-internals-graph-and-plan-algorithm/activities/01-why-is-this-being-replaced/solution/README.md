# Solución — tf-10-01

## Diagnóstico

`terraform show -json plan.out | jq '.resource_changes[].change.replace_paths'`
reporta `[["triggers","boot_ts"]]`. Comparando `before.triggers.boot_ts` con
`after.triggers.boot_ts` (ambos vía `jq`), se ve que el valor cambia entre
corridas del plan: es el resultado de `timestamp()`, que se **reevalúa en
cada `plan`**.

Como `triggers` del `null_resource` está marcado `ForceNew` por el provider,
cualquier cambio en sus valores dispara `delete+create`. Al cambiar el
timestamp cada vez, se propone replace eterno.

## Fix

Eliminar la clave `boot_ts = timestamp()` del `triggers`. La clave `config`
sobrevive y conserva la intención original: recrear cuando la configuración
cambia a mano.

Reglas aplicadas:

- No se usó `lifecycle { ignore_changes }` (eso solo oculta el síntoma).
- No se eliminó el `triggers` entero (la intención era legítima).
- No se cambió el provider ni el tipo de recurso.
