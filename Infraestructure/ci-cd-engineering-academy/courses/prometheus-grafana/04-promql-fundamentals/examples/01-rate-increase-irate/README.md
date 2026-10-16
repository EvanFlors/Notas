# Ejemplo 01 — `rate` vs `irate` vs `increase`

Comparación lado a lado sobre el mismo counter `http_requests_total`.

## Qué muestra

Las tres funciones responden preguntas distintas:

| Pregunta | Función |
|----------|---------|
| ¿Cuántos requests por segundo, suavizado? | `rate(x[5m])` |
| ¿Cuántos requests en total en los últimos 5 min? | `increase(x[5m])` |
| ¿Qué tan rápido está yendo *ahora mismo*? | `irate(x[1m])` |

## Queries

Ver [`queries.promql`](queries.promql).

## Cómo ejecutarlo

Dos modos:

1. **Con Prometheus corriendo** (ideal; p. ej. el stack `obs-02`):
   ```bash
   bash run.sh
   ```
2. **Con `promtool` instalado pero sin servidor**: `run.sh` valida la sintaxis de las queries con `promtool check rules`.

Si ninguno de los dos está disponible, `run.sh` **SKIPea** con mensaje claro (exit 0).

## Lectura esperada

- `rate(http_requests_total[5m])` → ~constante bajo tráfico estable.
- `irate(http_requests_total[1m])` → curva mucho más ruidosa, sensible al último par de muestras.
- `increase(http_requests_total[5m])` → ~ `rate × 300`.
