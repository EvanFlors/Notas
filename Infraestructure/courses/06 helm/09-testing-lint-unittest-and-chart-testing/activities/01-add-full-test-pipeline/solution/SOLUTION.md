# Solución — pipeline completo de testing

Esta solución es **una** forma correcta; otras equivalentes también valen.

## Decisiones

- **Matriz:** `v1.31.0`, `v1.30.0`, `v1.29.0` — política *n, n-1, n-2* (3 versiones vivas de Kubernetes).
- **Jobs:** `lint` y `unittest` corren en paralelo como gate barato. `install` requiere ambos; corre la matriz.
- **`fetch-depth: 0`** solo en el job `install` — el único que necesita diff contra `main`.
- **`fail-fast: false`** para ver todas las versiones que fallan.

## Archivos

```
solution/
├── ct.yaml
├── .github/workflows/chart-ci.yaml
└── charts/demo-app/
    ├── Chart.yaml
    ├── values.yaml
    ├── README.md                       ← con sección "Supported Kubernetes versions"
    ├── templates/{deployment, service}.yaml
    └── tests/deployment_test.yaml
```

## Cómo probar la solución localmente

```bash
helm lint --strict charts/demo-app
helm template rel charts/demo-app
helm unittest charts/demo-app
# ct install necesita kind + ct + un diff vs main — típicamente CI only.
```
