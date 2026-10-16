# Ejemplo 01 — Scrape de `node_exporter`

Stack mínimo que demuestra la pieza más clásica del ecosistema: Prometheus + `node_exporter`.

## Qué muestra

- Un `scrape_config` con `static_configs` apuntando a `node-exporter:9100`.
- Métricas de hardware/OS listas para consultar (`node_cpu_seconds_total`, `node_memory_MemAvailable_bytes`, `node_filesystem_free_bytes`).
- Un relabel didáctico que añade label `env="demo"` a todas las series del job.

## Cómo correr

```bash
cd examples/01-node-exporter-scrape
docker compose up -d
# Esperar ~10 s a que Prometheus haga el primer scrape.
open http://localhost:9090/targets   # job 'node' en estado UP
```

## Queries que valen la pena

```promql
# % de CPU en modo system a 5 min
rate(node_cpu_seconds_total{mode="system"}[5m])

# Memoria disponible absoluta
node_memory_MemAvailable_bytes

# Load average 1 min
node_load1
```

## Limpieza

```bash
docker compose down -v
```

## Notas

- `node_exporter` corre en contenedor por didáctica; en producción se instala **en el host** para que mida el host, no el contenedor. Para mediciones reales montarías `/proc`, `/sys` y `/` del host como bind mounts.
- El label `env="demo"` no viene del exporter: lo inyecta Prometheus vía `relabel_configs` con `action: replace` y `target_label: env`.
