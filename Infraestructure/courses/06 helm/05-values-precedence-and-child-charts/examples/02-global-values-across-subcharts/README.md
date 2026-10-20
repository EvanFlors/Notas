# Ejemplo 02 — Global values across subcharts

Un chart padre `parent` con un subchart local `subchart`. Ambos imprimen el mismo valor `global.imageRegistry` para evidenciar que `global` **sí** se propaga, mientras que un valor "normal" del padre **no** cruza la frontera.

## Estructura
```
parent/
├── Chart.yaml
├── values.yaml
├── templates/
│   └── parent-cm.yaml
└── charts/
    └── subchart/
        ├── Chart.yaml
        ├── values.yaml
        └── templates/
            └── child-cm.yaml
```

## Pasos

1. Render con defaults:
   ```bash
   helm template demo ./parent
   ```
   Esperado: ambos ConfigMaps imprimen `imageRegistry: ghcr.io/acme`. El ConfigMap del subchart además imprime `parentOnlyVisible: "<nil>"` demostrando que no puede leer `.Values.appName` del padre.

2. Override transversal del registry:
   ```bash
   helm template demo ./parent --set global.imageRegistry=registry.internal
   ```
   Esperado: ambos ConfigMaps cambian a `registry.internal`.

3. Override solo del padre (no se propaga):
   ```bash
   helm template demo ./parent --set appName=renamed
   ```
   Esperado: el ConfigMap del padre cambia; el del hijo sigue viendo `<nil>` porque `appName` vive solo en el namespace del padre.

## Lectura

- `global:` es la única zona compartida. Útil para registry, storageClass, dominio raíz, flags transversales.
- Un valor "plano" del padre **no** cruza. Si el subchart lo necesita, el padre debe sobrescribirlo con una clave con el nombre del subchart:
   ```yaml
   subchart:
     someKey: shared-value
   ```
