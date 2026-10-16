# Ejemplo 01 — Loki + Alloy + Grafana local

Stack mínimo reproducible con **docker-compose**: Loki (receptor), Grafana Alloy (agente), Grafana (UI) y una app Python que loguea JSON por stdout.

## Qué muestra

- **Alloy** descubre los contenedores de Docker, extrae labels estables (`app`, `env`) y envía stdout a Loki.
- **Loki** corre en modo `monolithic` con filesystem storage (ok para labs).
- **Grafana** llega preprovisionado con Loki como data source.

## Levantar

```bash
docker compose up -d
# espera ~15s a que Loki inicialice
open http://localhost:3000      # user: admin / admin
```

En Grafana → **Explore** → Loki → query:

```logql
{app="demo-app"}
{app="demo-app"} |= "ERROR"
{app="demo-app"} | json | level="error"
sum(rate({app="demo-app"} |= "ERROR" [1m]))
```

## Archivos

- `docker-compose.yaml` — Loki + Alloy + Grafana + demo-app.
- `loki-config.yaml` — Loki monolithic, filesystem storage, retención 24 h.
- `alloy-config.alloy` — scrape de `docker` + envío a Loki.
- `grafana-datasources.yaml` — provisioning del data source Loki.
- `demo-app/app.py` — loguea JSON cada 2 s, 1 de cada 10 líneas es `ERROR`.

## SKIP gracefully

Si `docker` o `docker compose` no están disponibles, el ejemplo lo detecta y aborta con mensaje claro:

```bash
bash check.sh    # script que verifica prerequisitos y hace smoke test
```

## Limpieza

```bash
docker compose down -v
```
