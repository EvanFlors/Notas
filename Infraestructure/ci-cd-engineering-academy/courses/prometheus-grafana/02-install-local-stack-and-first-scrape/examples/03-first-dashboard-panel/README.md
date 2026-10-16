# Ejemplo 03 — Primer panel manual en Grafana

## Concepto que demuestra

El flujo **manual** (y por lo tanto efímero) para construir el primer panel en Grafana. Es el "walkthrough didáctico" que todo estudiante hace una vez para entender la UI antes de pasarse a provisioning.

Usamos un stack mínimo (**Prometheus solo scrapea a sí mismo**) para que la atención esté en Grafana, no en los targets.

## Archivos

```
03-first-dashboard-panel/
├── README.md
├── compose.yaml
└── prometheus/
    └── prometheus.yml
```

## Pasos (hazlo tú con el mouse)

```
cd examples/03-first-dashboard-panel
docker compose up -d
```

1. Abre `http://localhost:3000` y entra con `admin/admin`.
2. *Connections → Data sources → Add new → Prometheus*.
   - URL: `http://prometheus:9090`
   - *Save & test* → debe decir "Successfully queried the Prometheus API".
3. *Explore* (ícono de brújula a la izquierda). Query: `up`. Debería devolver 1 serie (`{job="prometheus", instance="localhost:9090"} 1`).
4. *Dashboards → New → New dashboard → + Add visualization → Prometheus*.
5. En la query, escribe:
   ```
   rate(prometheus_http_requests_total[1m])
   ```
   (es tráfico HTTP interno del propio Prometheus; siempre hay porque Grafana lo está consultando).
6. En el panel options a la derecha, pon *Title: Prometheus HTTP req/s*. Pulsa *Apply*.
7. *Save dashboard* (ícono disquete). Nombre: `My first dashboard`.

## Qué observar

- Cuando guardas el dashboard, Grafana lo almacena en SU base de datos interna (SQLite) montada en `/var/lib/grafana`.
- Si haces `docker compose down -v`, **el dashboard desaparece**: el volumen `grafana-data` se borró y con él toda la configuración "a mano".
- El ejemplo 02 muestra la ruta sostenible: ese mismo dashboard versionado como JSON + provisioning file.

## Limpieza

```
docker compose down -v
```

## Siguiente paso sugerido

Exporta el dashboard que acabas de hacer a JSON (*Dashboard settings → JSON Model → Copy*) y colócalo en el esquema del ejemplo 02 (`grafana/dashboards/<name>.json`). Esa es exactamente la mecánica real de "dashboard as code".
