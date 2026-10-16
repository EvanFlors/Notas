# Ejemplo 03 — Limpiando labels con relabel

Un mismo `node_exporter` scrapeado con **dos configuraciones distintas** para que se vea la diferencia que hace el relabel sobre el conjunto de labels y la cardinalidad.

## Qué muestra

- `prometheus-before.yml` scrapea sin relabel: aparecen labels crudos (`instance=node-exporter:9100`), ninguna convención `env`/`team`, y una métrica de alta cardinalidad del propio exporter (`node_scrape_collector_duration_seconds` tiene un label por *colector*).
- `prometheus-after.yml`:
  - Renombra `instance` a `node1`.
  - Añade `env=lab`, `team=platform`.
  - Dropea `promhttp_metric_handler_requests_total` (métrica interna poco útil en dev) vía `metric_relabel_configs`.
  - Dropea labels `collector` de métricas internas del exporter.

## Cómo correr

Primero, versión "cruda":

```bash
cd examples/03-relabel-tidy-labels
PROM_FILE=prometheus-before.yml docker compose up -d
curl -s 'http://localhost:9090/api/v1/label/__name__/values' | head -c 400
curl -s 'http://localhost:9090/api/v1/query?query=count(up)'
docker compose down -v
```

Luego, versión limpia:

```bash
PROM_FILE=prometheus-after.yml docker compose up -d
curl -s 'http://localhost:9090/api/v1/query?query=count({__name__=~"promhttp_metric_handler_requests_total"})'
# Debe devolver 0 (métrica dropeada).
curl -s 'http://localhost:9090/api/v1/query?query=up{env="lab",team="platform"}'
# Debe devolver 2 (prometheus + node-exporter).
```

## Limpieza

```bash
docker compose down -v
```

## Notas

- Comparar el conteo total de series con `prometheus_tsdb_head_series` entre ambas versiones es el ejercicio clave de este ejemplo.
- Las reglas `labeldrop` que atacan labels concretos (no métricas enteras) son menos destructivas y suelen ser el primer paso antes de un drop total.
