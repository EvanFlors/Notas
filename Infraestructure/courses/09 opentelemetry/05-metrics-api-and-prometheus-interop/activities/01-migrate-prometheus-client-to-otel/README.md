# otel-05-01 — Migrar un servicio Flask de `prometheus_client` a OTel Metrics API

## 1. Identificación
- **ID:** `otel-05-01-migrate-prometheus-client-to-otel`
- **Tecnología:** opentelemetry
- **Módulo:** `05-metrics-api-and-prometheus-interop`
- **Dificultad:** intermediate
- **Duración estimada:** 75 min
- **Tipo:** guided-lab

## 2. Contexto

El equipo mantiene un servicio Flask instrumentado con `prometheus_client` desde hace años. La organización está adoptando OpenTelemetry para traces y quiere unificar también métricas bajo OTel para habilitar **exemplars** y poder redirigir backends en el Collector sin cambios de código.

El paso 1 de esa migración es cambiar la librería de métricas de la app **sin perder** `/metrics` scrapeable: Prometheus debe seguir viendo las mismas series (quizá con nombres equivalentes) sin cambios en su configuración.

## 3. Objetivos

- Leer y entender el `starter/app.py` (Flask + `prometheus_client`).
- Reescribir `starter/app.py` para que las métricas se emitan vía OTel API, manteniendo expuesto `/metrics`.
- Preservar temporalidad **cumulative** (default y lo correcto para Prometheus).
- Confirmar con `tests/validate.sh` que las métricas aparecen con nombre y labels correctos.
- Dejar una nota corta (`solution/DECISIONS.md` o similar) explicando por qué cumulative y qué pasaría con delta.

## 4. Prerrequisitos

- Python 3.10+.
- Paquetes:
  ```bash
  pip install flask opentelemetry-api opentelemetry-sdk opentelemetry-exporter-prometheus prometheus_client
  ```
- `curl`, `bash`.
- Sin costos cloud. Todo local.

## 5. Instrucciones

1. Instalar dependencias (ver arriba).
2. Correr el starter tal cual para comprobar que funciona:
   ```bash
   cd starter
   python3 app.py &   # arranca en :8080
   curl -s http://127.0.0.1:8080/hello
   curl -s http://127.0.0.1:8080/metrics | grep -E 'http_(requests|request_duration)'
   ```
   Notar los nombres de métricas (`http_requests_total`, `http_request_duration_seconds_bucket`).
3. Reemplazar el bloque de `prometheus_client` por configuración OTel:
   - `MeterProvider` con `PrometheusMetricReader`.
   - Mantener el servidor HTTP de métricas (puede seguir siendo `prometheus_client.start_http_server`, que lee del mismo `REGISTRY` que `PrometheusMetricReader` usa internamente).
   - Nombrar las métricas con la convención OTel (puntos) de modo que al exportarse salgan como `http_requests_total` y `http_request_duration_seconds` (los puntos se convierten a underscores y OTel añade `_total` a los Counter).
4. Añadir atributos equivalentes a los labels: `http.request.method`, `http.route`, `http.response.status_code`.
5. Validar con `bash tests/validate.sh` (ver sección 8).
6. Escribir `solution/DECISIONS.md` con:
   - Por qué cumulative.
   - Qué pasaría si alguien cambiara a delta.
   - Qué otras métricas migrarías después y cuáles dejarías en `prometheus_client` por ahora.

> **Hint:** el reader OTel-Prom escribe en el `REGISTRY` global de `prometheus_client`, por eso basta con `start_http_server(8080)` para seguir exponiendo `/metrics` sin montar tu propio handler.

## 6. Resultado esperado

- `GET /hello` responde `{"ok": true}`.
- `GET /metrics` devuelve texto Prometheus que incluye como mínimo:
  - `http_server_requests_total` (o `http_requests_total`) con labels/attributes de método, ruta y status.
  - `http_server_request_duration_seconds_bucket` (o `http_request_duration_seconds_bucket`) con buckets.
- Nota `DECISIONS.md` con 5–10 líneas sobre temporalidad.

## 7. Criterios de aceptación

- **Funcionalidad:** `tests/validate.sh` termina en `OK` (o `SKIP` si faltan deps opcionales).
- **Calidad:** el código no mantiene en paralelo las dos librerías para las **mismas** métricas (nada de doble emisión).
- **Reproducibilidad:** basta `pip install` + `python3 app.py` + `bash tests/validate.sh`.
- **Mantenibilidad:** las métricas se declaran una sola vez a nivel módulo.

## 8. Validación

```bash
# Validar la solución (lo que corre el CI del curso)
APP_DIR=./solution bash tests/validate.sh

# Validar tu propio avance en starter/
APP_DIR=./starter bash tests/validate.sh
```

El script arranca la app, hace algunas requests y verifica que `/metrics` expone contadores e histogramas con los nombres esperados. Si faltan dependencias (`flask`, `opentelemetry-exporter-prometheus`), termina con `SKIP` sin fallar.

## 9. Preguntas de reflexión

1. ¿Qué pasa si eliminas el `PrometheusMetricReader` y dejas solo un `PeriodicExportingMetricReader` + OTLP exporter? ¿Cómo cambia el modelo de scrape?
2. ¿Por qué el nombre OTel `http.server.requests` se convierte en `http_server_requests_total` al salir a Prometheus?
3. Si otro servicio del equipo mantiene `prometheus_client` y emite `http_requests_total` con las mismas labels, ¿qué verá Prometheus al scrapear ambos?
4. ¿Cuándo tiene sentido **no** migrar y mantener `prometheus_client`?
5. ¿Qué habría que configurar en el Collector para transformar la temporalidad si un backend StatsD exigiese delta?

## 10. Extensiones

- Añadir un **View** que redefina los buckets del histograma a `[0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]`.
- Añadir un `ObservableGauge` para "requests en vuelo" (contador atómico interno).
- Reemplazar `PrometheusMetricReader` por `PeriodicExportingMetricReader` + `OTLPMetricExporter` apuntando a un Collector local; mantener el reader Prom en paralelo durante la transición y luego borrarlo.
- Añadir exemplars grabando el histograma dentro de un span (requiere setup de TracerProvider como en el example 03).

## 11. Limpieza

- Matar la app: `pkill -f 'python3 app.py'` o `fg` + `Ctrl+C` si quedó en foreground.
- `/tmp/otel05-*` se auto-limpia (los scripts usan `trap`).
- Si usaste un venv dedicado: `deactivate` y borrarlo.
