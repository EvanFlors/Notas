# 01 — `static_configs` vs `file_sd_configs`

Dos jobs scrapeando lo mismo (node_exporter), uno estático y otro vía archivo. Luego agregamos un target *en caliente* editando `targets.json` sin recargar Prometheus.

## Levantar

```bash
cd "$(dirname "$0")"
docker compose up -d
# Prometheus en http://localhost:9090
```

## Verificar

```bash
# Ambos jobs deben aparecer con 1 target UP
curl -s localhost:9090/api/v1/targets | grep -o '"job":"[^"]*"' | sort -u
# "job":"node-file"
# "job":"node-static"
```

## Agregar un target "en caliente"

```bash
# Editamos targets.json y agregamos otro target bajo el mismo job
cat > targets.json <<'JSON'
[
  { "targets": ["node:9100"], "labels": { "env": "demo", "source": "file" } },
  { "targets": ["prometheus:9090"], "labels": { "env": "demo", "source": "file", "role": "self" } }
]
JSON
# Esperar hasta 30s (refresh_interval) y revisar
sleep 35
curl -s localhost:9090/api/v1/targets | grep -c '"job":"node-file"'
# → 2
```

El job estático requeriría `docker compose restart prometheus`. El file SD **no**.

## Limpieza

```bash
docker compose down -v
```
