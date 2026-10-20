# Ejemplo 02 — Probes HTTP con `blackbox_exporter`

Demuestra el patrón "exporter como proxy": Prometheus **no** scrapea el target final, scrapea al `blackbox_exporter` pasándole la URL por query param. El resultado son métricas sintéticas sobre la *disponibilidad* del target.

## Qué muestra

- Un `job_name: blackbox_http` con `metrics_path: /probe`.
- Relabel que:
  1. Copia `__address__` (la URL del target) a `__param_target`.
  2. Copia `__param_target` a `instance` (label legible).
  3. Reescribe `__address__` apuntando al blackbox-exporter.
- Métricas resultantes: `probe_success`, `probe_duration_seconds`, `probe_http_status_code`, `probe_ssl_earliest_cert_expiry`.

## Cómo correr

```bash
cd examples/02-blackbox-probe
docker compose up -d
# Esperar ~15 s a que corra el primer probe.
open http://localhost:9090/graph
```

Query útil:

```promql
probe_success                               # 1 = OK, 0 = fail
probe_http_status_code                      # p. ej. 200, 301, 500
probe_duration_seconds                      # latencia end-to-end
(probe_ssl_earliest_cert_expiry - time()) / 86400   # días hasta expirar
```

## Limpieza

```bash
docker compose down -v
```

## Notas

- Blackbox probes miden **tiempo total** incluyendo DNS + TCP + TLS + HTTP; para desagregar hay `probe_dns_lookup_time_seconds` y `probe_http_duration_seconds{phase=...}`.
- En producción se corre un `blackbox_exporter` por región/VPC para medir *desde donde los usuarios están*.
- Los módulos (`http_2xx`, `tcp_connect`, `icmp`, etc.) se definen en `blackbox.yml`. Aquí se usa el default `http_2xx`.
