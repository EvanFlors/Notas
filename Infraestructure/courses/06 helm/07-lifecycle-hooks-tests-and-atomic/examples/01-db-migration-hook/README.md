# Example 01 — DB migration como hook

Chart mínimo que demuestra el patrón canónico: un `Job` con `helm.sh/hook: pre-install,pre-upgrade` corre antes de que el `Deployment` sea aplicado. Si el `Job` falla, el install/upgrade falla.

## Render local (sin cluster)

```sh
helm template demo .
```

Buscar en el output el `Job` llamado `demo-migration-hook-demo-migrate` **antes** del `Deployment` (en el orden del YAML renderizado) y las anotaciones:

```yaml
"helm.sh/hook": pre-install,pre-upgrade
"helm.sh/hook-weight": "-5"
"helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
```

## Install en kind

```sh
helm install demo . --namespace demo --create-namespace --wait
# Observar: el Job completa primero; luego arranca el Deployment.
kubectl -n demo get jobs,pods
helm get hooks demo -n demo
```

Nota: con la delete-policy `hook-succeeded`, el `Job` **desaparece** del cluster poco después de completarse. Es el comportamiento esperado.

## Simular fallo

Editar `values.yaml` y cambiar `args` a algo como `["sh", "-c", "exit 1"]`. Luego:

```sh
helm upgrade demo . --namespace demo
```

El upgrade falla. El `Job` fallido queda in situ (`hook-failed` no está en la policy) para que puedas `kubectl logs job/...` y depurar.

## Limpieza

```sh
helm uninstall demo --namespace demo
kubectl delete namespace demo
```
