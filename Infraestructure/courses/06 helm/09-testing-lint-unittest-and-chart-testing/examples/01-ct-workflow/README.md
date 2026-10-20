# Ejemplo 01 — Workflow GHA con chart-testing

Workflow de referencia que corre las **4 capas** de validación sobre todos los charts bajo `charts/`:

1. `helm lint --strict`
2. `helm template` (dry render)
3. `helm unittest`
4. `ct install` sobre `kind` en matriz de **3 versiones** de Kubernetes

## Estructura

```
.
├── .github/workflows/chart-ci.yaml   ← pipeline
├── ct.yaml                           ← config de chart-testing
└── charts/demo-app/                  ← chart mínimo de ejemplo
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
        ├── deployment.yaml
        └── service.yaml
```

## Puntos a notar

- **`fetch-depth: 0`** en el checkout del job `install` — sin esto `ct` no puede comparar contra `main` y no detecta charts cambiados.
- **`fail-fast: false`** — queremos ver qué versiones específicas fallan, no abortar al primer error.
- **`matrix.k8s`** incluye `n`, `n-1`, `n-2`. Edítala según tu política de soporte.
- `lint` y `unittest` son el **gate barato** (segundos). `install` es el **gate caro** (minutos por versión).
- El `ct.yaml` fija `chart-dirs: [charts]` y `target-branch: main`.

## Prueba local

Si tienes `helm`, `helm-unittest` y `ct` instalados:

```bash
helm lint --strict charts/demo-app
helm template rel charts/demo-app
helm unittest charts/demo-app        # requiere plugin helm-unittest
ct lint --config ct.yaml --target-branch main --all   # --all porque no hay history
```

Para `ct install` necesitas `kind` + un cluster corriendo.

## SKIP graceful

El workflow no se *skipea* automáticamente — en CI real queremos que las herramientas estén. Para reproducir el pipeline en local sin tener todo instalado, revisa el `README.md` de la actividad 01 que incluye detección y mensajes claros.
