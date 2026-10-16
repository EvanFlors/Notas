# Starter — obs-05-02

Levanta el stack sucio y edita **solo** `prometheus.yml`:

```bash
docker compose up -d
sleep 15
curl -s 'http://localhost:9090/targets'
```

Objetivos (ver README de la actividad):

- `env="lab"` y `team="sre"` en todas las series.
- `instance="node1"` para el job `node`.
- `instance = URL` para el job `blackbox`.
- Dropear `promhttp_metric_handler_requests_total` y `promhttp_metric_handler_requests_in_flight`.

Recarga sin bajar el stack:

```bash
curl -X POST http://localhost:9090/-/reload
```
