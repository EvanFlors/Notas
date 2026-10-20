# Ejemplo 03 — Provisioning completo

Demuestra provisionar en un sólo arranque:
- **Data source** Prometheus con `uid` fijo.
- **Folder** `Platform` por YAML.
- **Dashboard** `platform-health` como JSON montado.
- **Alert rule** de Grafana ("instance down") desde YAML.
- **Contact point** `console-webhook` + policy por defecto.

Los dashboards aparecen con badge **Provisioned** y la regla aparece en *Alerting → Alert rules*.

## Levantar
```bash
cd examples/03-provisioning-dashboards
docker compose up -d
# Grafana: http://localhost:3002  (admin / admin)
```

## Qué inspeccionar
- *Dashboards → Platform → Platform health* — badge "Provisioned".
- *Alerting → Alert rules* — regla `InstanceDown` cargada.
- *Alerting → Contact points* — `console-webhook`.
- *Alerting → Notification policies* — ruteo por defecto hacia el contact point.

## Parar
```bash
docker compose down -v
```
