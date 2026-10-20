# Ejemplo 01 — Compose: Prometheus + Grafana + node_exporter

## Concepto que demuestra

El **stack mínimo útil** de observabilidad local: Prometheus scrapea a sí mismo y a un `node_exporter`; Grafana queda listo para apuntar a Prometheus. Todo con un único `compose.yaml`.

## Archivos

```
01-compose-prom-grafana-node/
├── README.md
├── compose.yaml
└── prometheus/
    └── prometheus.yml
```

## Cómo correrlo

```
cd examples/01-compose-prom-grafana-node
docker compose up -d
docker compose ps
```

Verificación rápida:

```
# Prometheus healthy
curl -fsS http://localhost:9090/-/healthy

# node_exporter responde
curl -fsS http://localhost:9100/metrics | head -20

# Grafana responde
curl -fsS http://localhost:3000/api/health
```

Y en el navegador:

- `http://localhost:9090/targets` — los 2 jobs (`prometheus`, `node`) en `UP`.
- `http://localhost:9090/graph?g0.expr=up` — tres series en `1`.
- `http://localhost:3000` — login `admin/admin` (demo).

## Qué observar

1. **DNS del proyecto**: en `prometheus.yml` el target del segundo job es `node-exporter:9100`, no `localhost:9100`. Ese nombre lo resuelve la red del proyecto de Compose.
2. **`external_labels: stack: obs-02-example-01`**: toda métrica que salga de este Prometheus (al federar, remote-write o alertar) llevará esa etiqueta. Es cómo se identifica el origen en setups multi-cluster.
3. **Volumen `prom-data`**: la TSDB persiste entre `up`/`down`; solo `down -v` la borra.
4. **node_exporter mount `/`**: para que vea paths reales del host (en Docker Desktop sigue siendo el VM-wrapper; en Linux es el host).

## Limpieza

```
docker compose down -v
```
