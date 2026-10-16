# Ejemplo 02 — Variables y templating

Dashboard que demuestra **chained variables** y **repetición de paneles**.

Variables:
- `job` — `query` sobre `label_values(up, job)`, con `All` (`.+`).
- `instance` — `query` dependiente: `label_values(up{job=~"$job"}, instance)`.
- `interval` — `custom`: `1m, 5m, 15m, 1h`.

Un panel se **repite** por cada valor de `$instance` seleccionado.

## Levantar
```bash
cd examples/02-variables-and-templating
docker compose up -d
# Grafana: http://localhost:3001  (admin / admin)
```

Entra al dashboard *Variables demo* y cambia los dropdowns. Observa:
- Al cambiar `job`, la lista de `instance` se refresca (chaining).
- Al seleccionar varios `instance`, el panel se repite.
- `$interval` cambia la ventana de `rate()`.

## Parar
```bash
docker compose down -v
```
