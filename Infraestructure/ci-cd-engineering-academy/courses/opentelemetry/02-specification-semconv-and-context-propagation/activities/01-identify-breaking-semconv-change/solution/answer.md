# Reference answer — otel-02-01

## A) Classification per service

### service-a (SDK 1.15.0, old)

Attributes emitted:

- `http.method`           → **DEPRECATED** → `http.request.method`
- `http.status_code`      → **DEPRECATED** → `http.response.status_code`
- `http.url`              → **DEPRECATED** → `url.full`
- `http.target`           → **DEPRECATED** → `url.path`
- `http.host`             → **DEPRECATED** → `server.address`
- `http.flavor`           → **DEPRECATED** → `network.protocol.version`

All six are old-style; **100% deprecated**.

### service-b (SDK 1.26.0, new)

Attributes emitted:

- `http.request.method`         → **CURRENT**
- `http.response.status_code`   → **CURRENT**
- `url.full`                    → **CURRENT**
- `url.path`                    → **CURRENT**
- `url.scheme`                  → **CURRENT**
- `server.address`              → **CURRENT**
- `server.port`                 → **CURRENT**
- `network.protocol.version`    → **CURRENT**

All current; nothing to migrate.

### service-c (SDK 1.21.0, mixed / dual-emit)

Emits **both** sets simultaneously:

- Old: `http.method`, `http.status_code`, `http.url`
- New: `http.request.method`, `http.response.status_code`, `url.full`, `url.path`, `server.address`

This is the transitional mode activated by `OTEL_SEMCONV_STABILITY_OPT_IN=http/dup`.

## B) Which is old / new / mixed

- **old**: service-a
- **new**: service-b
- **mixed (dual-emit)**: service-c

## C) Deprecated → current renames detected

| Deprecated           | Current                        |
|----------------------|--------------------------------|
| `http.method`        | `http.request.method`          |
| `http.status_code`   | `http.response.status_code`    |
| `http.url`           | `url.full`                     |
| `http.target`        | `url.path`                     |
| `http.scheme`        | `url.scheme`                   |
| `http.host`          | `server.address`               |
| `http.flavor`        | `network.protocol.version`     |

## D) Migration plan (4 steps, with dual-emit and cutoff)

1. **Dashboards first (defensive)**: actualizar paneles de Grafana para usar `coalesce` o `OR` entre `http.request.method` y `http.method` (y análogamente para status/url/host). Esto garantiza que **ambos** nombres se ven mientras dura la ventana. Deploy en producción antes de tocar un solo SDK.

2. **Upgrade escalonado con dual-emit**: para cada servicio, actualizar el SDK a una versión intermedia que soporte `OTEL_SEMCONV_STABILITY_OPT_IN=http/dup`. Esto hace que emita **ambos** sets (como service-c). Rollout gradual (canary + wave) con observación de métricas por panel para detectar regresiones.

3. **Verificación de cobertura**: durante al menos 2 semanas, confirmar que **todos** los servicios emiten los nombres nuevos (query en el backend: contar spans con `http.request.method` presente, debería ser 100% del tráfico HTTP). Alertar si algún servicio queda atrás.

4. **Cutoff**: una vez que el 100% de los servicios emite dual, apagar la emisión vieja (`OTEL_SEMCONV_STABILITY_OPT_IN=http`). Simultáneamente, retirar de los dashboards los paneles `OR` dejando sólo los nombres **nuevos**. Documentar el cambio en el runbook.

**Criterio de cutoff**: `0 spans con http.method durante 7 días consecutivos` y aprobación del equipo de observabilidad.
