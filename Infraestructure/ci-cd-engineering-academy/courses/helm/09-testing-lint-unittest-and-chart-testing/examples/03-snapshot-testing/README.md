# Ejemplo 03 — Snapshot testing

Patrón de **snapshot** con `helm-unittest`: fijamos la salida renderizada esperada y detectamos regresiones silenciosas (por ejemplo, un `_helpers.tpl` que inadvertidamente cambia los labels estándar).

## Cuándo usarlo

- Templates **estables** (no cambian a cada PR).
- Labels estándar o metadata canónica (`_helpers.tpl`).
- Objetos "firma" del chart (el `Deployment` principal).

## Cuándo NO

- Templates muy dinámicos — el snapshot se actualiza en cada PR, nadie lo lee, no detecta nada.

## Estructura

```
demo-app/
├── Chart.yaml
├── values.yaml
├── templates/
│   ├── _helpers.tpl
│   └── service.yaml
└── tests/
    ├── service_snapshot_test.yaml
    └── __snapshot__/
        └── service_snapshot_test.yaml.snap   ← grabado en el primer run
```

## Correr

```bash
helm plugin install https://github.com/helm-unittest/helm-unittest
helm unittest demo-app

# Para regenerar snapshots a propósito (p. ej. tras un cambio esperado):
helm unittest -u demo-app
```

## Nota

El snapshot incluido es ilustrativo — el formato real se genera por el plugin y puede variar de versión a versión. En CI, el `.snap` debe estar committeado al repo para que la comparación tenga referencia.
