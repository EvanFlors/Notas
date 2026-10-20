# obs-07-02 — Cardinality-safe labels (independent)

## 1. Identificación
- **ID:** `obs-07-02-cardinality-safe-labels`
- **Tecnología:** prometheus-grafana
- **Módulo:** 07-instrumentation-with-python
- **Dificultad:** intermediate
- **Duración estimada:** 45 min
- **Tipo:** independent

## 2. Contexto

Heredas un microservicio FastAPI escrito por "alguien" (una versión temprana tuya, probablemente). Expone `/metrics` y a primera vista parece bien instrumentado: tiene `Counter` y `Histogram`, usa middleware, los nombres respetan la convención. Pero el equipo de plataforma te advierte: *"desde que desplegamos ese servicio, Prometheus consume 3× más RAM y las queries sobre su histograma son lentísimas"*.

Tu trabajo es **auditar `/metrics`, identificar los labels con cardinalidad peligrosa, y corregirlos** sin perder la señal útil para dashboards y alertas.

## 3. Objetivos

- Detectar visualmente labels de alta cardinalidad.
- Decidir, para cada label problemático, si **eliminarlo**, **mapearlo a una categoría acotada** o **mover la información a logs/traces**.
- Dejar las métricas lo bastante útiles para calcular RED (rate/errors/duration) por `method`+`path`.
- Hacer pasar el validador automático.

## 4. Prerrequisitos

- Haber hecho `obs-07-01-instrument-capstone`.
- Python 3.10+, `fastapi`, `uvicorn`, `prometheus_client`.
- Puerto libre (default 8789).
- Coste: 0.

## 5. Instrucciones

> Esta es una actividad **independiente**: la solución NO está en este README. En `solution/` hay una versión de referencia que puedes consultar al final.

1. Lee `starter/app.py` entero. Fíjate en:
   - Nombres de las métricas.
   - Lista `labelnames=[...]`.
   - Qué valores se pasan a `.labels(...)`.
2. Levanta la app y pégale con el *stress generator* incluido:
   ```bash
   cd starter
   uvicorn app:app --port 8789 &
   sleep 1
   python3 stress.py            # genera tráfico con 50 user_ids y 50 item_ids
   curl -s localhost:8789/metrics | wc -l
   ```
3. Observa cuántas líneas tiene `/metrics`. Antes de la corrección: **cientos** o miles de series por un servicio de 3 endpoints. Después: decenas.
4. Edita `starter/app.py`:
   - Elimina los labels de alta cardinalidad.
   - Si pierdes información útil (p. ej. el tipo de usuario), reemplaza por una categoría acotada (p. ej. `user_tier` con valores `free|pro|enterprise`).
   - Preserva: `method`, `path` (templatizado), un indicador de estado (`status` o `status_class`).
5. Vuelve a lanzar y repite el conteo: `wc -l /metrics` debe bajar drásticamente.
6. Corre el validador: `bash tests/validate.sh`.

### Pistas (no la solución)

- Hay **más de un** label peligroso. Al menos tres.
- Un label de 1 valor fijo tampoco aporta: considera eliminarlo.
- La información "trace para investigar" NO va como label: va como exemplar (fuera de alcance aquí; aquí basta con quitarla).

## 6. Resultado esperado

- `/metrics` tiene **≤ 60 series** (contando buckets) tras ejercitar el *stress generator*.
- Ninguna métrica tiene labels `user_id`, `request_id`, `trace_id`, `email`, `item_id` como label.
- Las métricas RED siguen permitiendo calcular `rate(http_requests_total[1m])` por `path`.
- `bash tests/validate.sh` imprime `OK`.

## 7. Criterios de aceptación

- Sin labels de alta cardinalidad.
- Las métricas conservan los labels necesarios para dashboards RED (`method`, `path`, estado).
- El path es templatizado (nunca `/items/42`).

## 8. Validación

```bash
bash tests/validate.sh
```

El validador:
1. Levanta la app.
2. Simula tráfico con muchos `user_id`/`item_id`.
3. Lee `/metrics` y falla si:
   - Encuentra labels prohibidos.
   - La serie `http_request_duration_seconds_bucket` explota (> 500 líneas).
   - Faltan los labels mínimos para RED.

## 9. Preguntas de reflexión

- ¿Por qué `user_id` como label de un histograma es *especialmente* malo (vs un counter)?
- ¿Dónde va entonces la información de "qué usuario sufrió esta latencia"?
- ¿Cómo detectarías cardinality explosion en producción? (pista: `prometheus_tsdb_head_series`, `topk(10, count by (__name__)({__name__!=""}))`).
- ¿Cuándo tiene sentido `tenant_id` como label aunque sean cientos de tenants?

## 10. Extensiones

- Añade un exemplar al histograma con `trace_id` (requiere OTel setup; opcional).
- Escribe un test con `REGISTRY.collect()` que falle si se añade un label nuevo sin review.
- Diseña una `metric_relabel_configs` en Prometheus que **dropee** una métrica si aparece con `user_id`.

## 11. Limpieza

```bash
pkill -f "uvicorn app:app --port 8789" 2>/dev/null || true
```
