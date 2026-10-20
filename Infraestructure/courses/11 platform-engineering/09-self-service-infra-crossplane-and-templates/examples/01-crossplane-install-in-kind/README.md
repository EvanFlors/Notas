# Ejemplo 01 — Instalar Crossplane en kind

## Objetivo

Mostrar la instalación mínima de Crossplane + `provider-kubernetes` en un cluster kind efímero. **Idempotente**: `run.sh` se puede ejecutar varias veces; **limpio**: `cleanup.sh` elimina todo.

## Qué hace `run.sh`

1. Verifica que `docker`, `kind`, `kubectl`, `helm` estén instalados (sale con `SKIP` si falta alguno).
2. Crea el cluster `plat-09-ex01` si no existe.
3. Instala el chart `crossplane` del repo oficial en el namespace `crossplane-system`.
4. Espera que el Deployment `crossplane` esté `Available=True`.
5. Instala el `Provider` `crossplane-contrib/provider-kubernetes` y espera que esté `Healthy=True`.
6. Crea un `ProviderConfig` apuntando al propio cluster (InClusterConfig) para que los `Object` MRs lo usen por defecto.

Al terminar deberías ver:

```
NAME                             INSTALLED   HEALTHY
provider-kubernetes              True        True
```

y

```
NAME      AGE
default   XsXs
```

(el `ProviderConfig default`).

## Decisión importante

Usamos el provider **`kubernetes`** y no un provider cloud (`aws`, `gcp`, `azure`) a propósito:

- Sin credenciales ni setup previo.
- Sin costo real.
- Los MRs se materializan como recursos K8s nativos del propio cluster, visibles con `kubectl get <kind>`.

El patrón enseñado se traslada 1:1 a providers cloud en producción (ver `theory/lesson.md` §3 y §4).

## Ejecutar

```bash
bash run.sh
```

Si al final ves `OK: crossplane + provider-kubernetes listos`, el ejemplo funciona. Pasa a `examples/02-xrd-namespace-product/`.

## Limpiar

```bash
bash cleanup.sh
```

Elimina el cluster kind y el scratch `/tmp/plat-09-ex01`.
