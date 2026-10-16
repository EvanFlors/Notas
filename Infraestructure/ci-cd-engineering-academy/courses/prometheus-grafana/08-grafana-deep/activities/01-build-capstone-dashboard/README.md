# obs-08-01 — Construir y provisionar el dashboard RED

## 1. Identificación
- **ID:** `obs-08-01-build-capstone-dashboard`
- **Tecnología:** prometheus-grafana
- **Módulo:** `08-grafana-deep`
- **Dificultad:** intermediate
- **Duración estimada:** 90 min
- **Tipo:** guided-lab

## 2. Contexto
El capstone (una API HTTP) necesita su dashboard RED (Rate / Errors / Duration). En este lab lo construyes **desde el JSON** y lo provisionas con YAML, para que viva en el repo y no en SQLite de Grafana.

## 3. Objetivos
- Un dashboard con `uid` fijo, 6 paneles cubriendo RED, 1 variable `query` y 1 variable `custom`.
- Provisioning con `allowUiUpdates: false` → badge **Provisioned** en Grafana.
- Validación automatizada que verifica estructura del JSON y presencia de los paneles.

## 4. Prerrequisitos
- Docker + Docker Compose.
- Puertos libres `3000`, `9090` (puedes cambiarlos en `docker-compose.yml`).
- Software: `jq`, `bash`.
- Costos: ninguno (todo local).

## 5. Instrucciones

1. Copia el starter a un workspace tuyo (o trabaja ahí mismo):
   ```bash
   cd starter/
   docker compose up -d
   # Prometheus: http://localhost:9090
   # Grafana:    http://localhost:3000   (admin/admin)
   ```
2. Abre `grafana/dashboards/red.json`. Está **incompleto**: tiene sólo 2 paneles (rate y stat). Debes añadir:
   - `gauge` con `histogram_quantile(0.95, ...)` sobre `prometheus_http_request_duration_seconds_bucket`.
   - `heatmap` con los buckets por `le` (formato `heatmap`).
   - `table` con `topk(10, ...)` por `handler`.
   - `state-timeline` con `up` por `instance`.
3. Añade dos variables en `templating.list`:
   - `job` tipo `query` → `label_values(up, job)` (multi, includeAll).
   - `interval` tipo `custom` con valores `1m,5m,15m,1h`.
4. Usa `$job` y `$__rate_interval` (o `$interval`) en las expresiones.
5. Guarda, espera 30 s (`updateIntervalSeconds`) y recarga Grafana. El dashboard debe tener el badge **Provisioned**.
6. Ejecuta la validación:
   ```bash
   bash ../tests/validate.sh
   ```

## 6. Resultado esperado
- `starter/grafana/dashboards/red.json` con **6 paneles** y **2 variables**.
- Dashboard visible en Grafana → *Capstone → RED — capstone*.
- `validate.sh` termina con `RESULT: OK`.

## 7. Criterios de aceptación
- `uid` del dashboard **fijo** (no auto-generado).
- Al menos 1 panel por cada tipo: `timeseries`, `stat`, `gauge`, `heatmap`, `table`, `state-timeline`.
- Variables `job` y `interval` presentes.
- Legend format con `{{...}}` en el panel timeseries.
- Dashboard no editable por UI (`allowUiUpdates: false`).

## 8. Validación
```bash
bash tests/validate.sh
```
Si Docker no está corriendo o Grafana no está disponible, los chequeos de "runtime" se **skipean** con mensaje; los chequeos estáticos del JSON corren siempre.

## 9. Preguntas de reflexión
- ¿Por qué fijar `uid`? ¿Qué se rompe si no lo fijas y re-provisionas?
- ¿Qué pasa si usas `$__interval` en vez de `$__rate_interval` para `rate()`?
- ¿Por qué `heatmap` necesita `format: heatmap` en el target?
- ¿Cómo cambiarías el dashboard para 20 servicios sin duplicarlo?

## 10. Extensiones
- Añadir un `bar chart` con errores por `code` (`4xx` vs `5xx`).
- Añadir una transformación `reduce` sobre la tabla para mostrar sólo el valor "last".
- Añadir un panel `status-history` con el estado horario del servicio.

## 11. Limpieza
```bash
cd starter/
docker compose down -v
```
