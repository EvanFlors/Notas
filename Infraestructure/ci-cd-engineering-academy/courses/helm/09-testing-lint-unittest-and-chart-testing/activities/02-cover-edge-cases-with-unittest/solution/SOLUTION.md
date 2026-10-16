# Solución — edge cases con helm-unittest

Cobertura de los 5 edge cases distribuida en 3 archivos:

- `demo-app/tests/deployment_test.yaml` — default, override completo, lista vacía, lista no vacía, replica custom.
- `demo-app/tests/ingress_test.yaml` — disabled (0 docs), enabled+nil hosts (0 docs), enabled+hosts (1 doc).
- `demo-app/tests/hpa_test.yaml` — flag booleano `autoscaling.enabled` true/false.

Correr:

```bash
helm unittest demo-app
```

El set es idéntico al de `examples/02-helm-unittest-cases/` — está diseñado para que la actividad coincida con el ejemplo tras resolverla correctamente.
