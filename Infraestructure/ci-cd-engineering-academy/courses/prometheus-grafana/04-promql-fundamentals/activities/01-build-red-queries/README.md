# obs-04-01-build-red-queries — Construir el trio RED en PromQL

## 1. Identificación

- **ID:** `obs-04-01-build-red-queries`
- **Tecnología:** prometheus-grafana
- **Módulo:** 04-promql-fundamentals
- **Dificultad:** beginner
- **Duración estimada:** 60 min
- **Tipo:** guided-lab

## 2. Contexto

El método **RED** (*Rate, Errors, Duration*, Tom Wilkie) es el núcleo mínimo para observar un servicio HTTP. Casi todo dashboard de "producto" en una empresa que use Prometheus parte de estas 3 queries. En este lab vas a construirlas tú, usando una app Python FastAPI del capstone como referencia conceptual.

## 3. Objetivos

- Escribir la query **Rate** agregada por `job`.
- Escribir la query **Errors** como ratio 5xx/total con operadores binarios.
- Escribir la query **Duration** como p95 usando `histogram_quantile` con `le` en el `by`.
- Validar sintaxis con `promtool` (si está disponible) o ejecutar contra Prometheus en vivo.

## 4. Prerrequisitos

- Conocimientos: haber leído `theory/lesson.md` de este módulo.
- Software: `bash`, `grep` POSIX. Opcional: `promtool` (CLI de Prometheus) o un Prometheus corriendo en `http://localhost:9090` (p. ej. el compose del módulo `obs-02`).
- Infraestructura: ninguna requerida. Si no tienes `promtool` ni servidor, el validador reporta SKIP y la actividad se completa con revisión manual.
- Permisos: ninguno.
- Costos potenciales: **cero**.

## 5. Instrucciones

1. Copia `starter/queries.promql` a tu propio archivo de trabajo si quieres (opcional).
2. Edita `starter/queries.promql` y reemplaza cada `TODO:` con la query correcta.

   El `/metrics` del servicio expone (fragmento ilustrativo):
   ```
   # TYPE http_requests_total counter
   http_requests_total{job="api", method="GET",  path="/users", code="200"} 1234
   http_requests_total{job="api", method="POST", path="/users", code="500"} 5
   # TYPE http_request_duration_seconds histogram
   http_request_duration_seconds_bucket{job="api", le="0.1"} 900
   http_request_duration_seconds_bucket{job="api", le="0.25"} 980
   http_request_duration_seconds_bucket{job="api", le="0.5"} 1000
   http_request_duration_seconds_bucket{job="api", le="+Inf"} 1000
   http_request_duration_seconds_count{job="api"} 1000
   http_request_duration_seconds_sum{job="api"} 95.0
   ```

3. Pistas (sin dar la solución):
   - **Rate**: `sum by (...) (rate(... [5m]))`.
   - **Errors**: ratio de `code=~"5.."` sobre total; usa un operador `/` y mismo `by` en ambos lados.
   - **Duration (p95)**: `histogram_quantile(0.95, sum by (le, ...) (rate(..._bucket[5m])))`.

4. Ejecuta la validación:
   ```bash
   bash tests/validate.sh
   ```

5. Si tienes el stack de `obs-02` levantado, exporta `PROM_URL=http://localhost:9090` y vuelve a correr `tests/validate.sh` — intentará consultar en vivo cada query.

## 6. Resultado esperado

- `starter/queries.promql` ya no contiene la cadena `TODO:` en ninguna línea de query (solo en comentarios de instrucciones si decides dejarlos).
- Las 3 queries pasan la validación de forma (grep) y, si `promtool` está disponible, pasan `promtool check rules`.

## 7. Criterios de aceptación

- **Funcionalidad**: las 3 queries son matemáticamente válidas sobre los tipos de métrica indicados.
- **Calidad**: el `by (...)` conserva solo las dimensiones útiles; en Duration incluye `le`.
- **Seguridad**: no se exponen datos sensibles (no aplica aquí).
- **Reproducibilidad**: `bash tests/validate.sh` da el mismo resultado en cualquier máquina con el mismo starter.
- **Mantenibilidad**: cada query se puede leer en una pantalla.

## 8. Validación

```bash
bash tests/validate.sh           # SKIP, promtool, o live según entorno
PROM_URL=http://localhost:9090 bash tests/validate.sh   # live si Prometheus está arriba
```

El script escribe archivos temporales en `/tmp/promql-01-*` y los limpia al salir.

## 9. Preguntas de reflexión

1. ¿Por qué `rate()` necesita `[5m]` (o similar) y no un instante puntual?
2. ¿Qué pasa si pones `by (job)` en lugar de `by (le, job)` dentro de `histogram_quantile`?
3. ¿Por qué conviene **evitar `irate` en alertas** aunque dé una curva más "fresca"?
4. Si en producción ves ratio de errores = 0 aunque hay 5xx en logs: ¿qué 3 cosas comprobarías primero?
5. ¿Cuándo convertirías alguna de estas queries en **recording rule**?

## 10. Extensiones

- Añadir una query p50 además de p95 y una media `_sum/_count`.
- Partir Errors por `path` para detectar un endpoint específico roto.
- Añadir una 4ª query de "requests por segundo normalizados por réplica" usando join `on (job) group_left` con `kube_deployment_spec_replicas`.

## 11. Limpieza

El script de validación limpia su propio scratch (`/tmp/promql-01-*`). Nada que apagar si no levantaste Prometheus.
