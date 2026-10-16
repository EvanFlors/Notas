# Lección: Instrumentation with Python

> **ID:** `obs-07-instrumentation-with-python` · **Nivel:** intermedio · **Duración:** 4 h
> **Prerrequisitos:** `obs-03-metric-types-and-naming`, `obs-04-promql-fundamentals`.

---

## 1. Introducción intuitiva

Si tu servicio no se mide a sí mismo, lo mide tu usuario. La diferencia entre enterarte de un problema por un dashboard o por un cliente enfadado se decide en el momento de **instrumentar**. Un servicio Python bien instrumentado expone, en un endpoint `/metrics`, cuántas peticiones ha procesado, cuántas fallaron, cuánto tardaron, cuánta memoria usa, y cualquier señal específica del dominio (p. ej. "cuántos pagos aprobados por minuto"). Prometheus pasa a leer ese endpoint cada 15 s y, a partir de ahí, todo el stack (dashboards, alertas, SLOs) vive de esa información.

El reto no es técnico (`pip install prometheus_client` y 20 líneas de código), es **de diseño**: qué métricas emites, con qué tipo, con qué nombre, y sobre todo con **qué labels**. Un error aquí no causa un fallo visible el día del release; causa, meses después, una explosión de cardinalidad que satura la TSDB. Instrumentar es un ejercicio de disciplina.

Este módulo cubre la librería oficial (`prometheus_client`), la integración con FastAPI/Starlette (lo normal hoy en Python), el modo multiproceso para gunicorn, exemplars para enlazar con traces y cómo testear métricas sin levantar HTTP.

---

## 2. La librería `prometheus_client`

### 2.1 Instalación y colectores default

```bash
pip install prometheus_client
```

Al importar la librería, el `REGISTRY` global registra automáticamente tres colectores:

- `ProcessCollector` → métricas del proceso Unix (`process_cpu_seconds_total`, `process_resident_memory_bytes`, `process_open_fds`, `process_start_time_seconds`).
- `PlatformCollector` → `python_info{version=...}` como gauge constante.
- `GCCollector` → `python_gc_collections_total`, `python_gc_objects_collected_total`, `python_gc_objects_uncollectable_total` por generación.

Esto es trabajo gratis: sin instrumentar nada tuyo, ya tienes CPU, RSS, FDs y GC. No lo deshabilites a menos que haya razón explícita (p. ej. worker efímero donde no aporta nada).

### 2.2 Los cuatro tipos de instrumento

```python
from prometheus_client import Counter, Gauge, Histogram, Summary
```

**Counter** — monótono, siempre crece. Se usa casi siempre con `rate()` o `increase()`.

```python
http_requests_total = Counter(
    "http_requests_total",
    "Total HTTP requests served",
    labelnames=["method", "path", "status"],
)
http_requests_total.labels(method="GET", path="/api/items", status="200").inc()
```

**Gauge** — sube y baja. Representa un valor instantáneo (temperatura, conexiones activas, tamaño de cola).

```python
inflight_requests = Gauge("http_requests_inflight", "In-flight HTTP requests")
inflight_requests.inc()        # al entrar
inflight_requests.dec()        # al salir
# o inflight_requests.set(42)
```

**Histogram** — observa valores (típicamente latencia) y los distribuye en buckets acumulativos. Expone `_bucket`, `_sum`, `_count`.

```python
http_request_duration_seconds = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds",
    labelnames=["method", "path"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0),
)
http_request_duration_seconds.labels("GET", "/api/items").observe(0.042)
```

Elegir **buckets** es un acto de diseño: para APIs HTTP, los defaults de la librería suelen quedarse largos (hasta 10 s). Un juego típico para microservicios P50~20 ms, P99~500 ms sería `(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0)`. Debe cubrir con holgura por abajo el P50 y por arriba el P99 esperado.

**Summary** — como histogram pero calcula los cuantiles **en el cliente**, por target. Expone `metric{quantile="0.5"}`, etc.

```python
# Rara vez lo quieres:
req_size = Summary("http_request_size_bytes", "Request size")
req_size.observe(len(body))
```

> **Regla práctica:** prefiere **Histogram** salvo caso justificado. Los cuantiles de un Summary no son agregables cross-instance (no puedes "sumar" el P99 de 10 pods). Un Histogram sí, vía `histogram_quantile(0.99, sum(rate(..._bucket[5m])) by (le, ...))`.

### 2.3 Patrones ergonómicos: decoradores y context managers

Los tres instrumentos que miden duración ofrecen helpers:

```python
@http_request_duration_seconds.labels("POST", "/api/pay").time()
def pay(req): ...

with http_request_duration_seconds.labels("GET", "/api/items").time():
    do_work()

@inflight_requests.track_inprogress()
def handler(req): ...
```

Útil para scripts y jobs. Para servidores HTTP, lo normal es usar middleware (ver §5).

---

## 3. Naming y unidades

El módulo `obs-03` ya cubrió la convención. Resumen aplicado:

- Formato: `<namespace>_<subsystem>_<name>_<unit>`, snake_case, singular salvo que termine en `_total`.
- Sufijos obligatorios por tipo:
  - Counter → `_total` (p. ej. `http_requests_total`).
  - Histogram/Summary de duración → `_seconds` (nunca `_ms`).
  - Histogram/Summary de tamaño → `_bytes`.
  - Gauge de ratio → `_ratio` (0–1, nunca porcentajes).
- `help` claro: *de qué unidad y en qué sistema*. "HTTP request latency in seconds, measured at ASGI middleware".

Mezclar unidades es un bug silencioso: una métrica `http_latency` sin sufijo acaba conteniendo milisegundos en un servicio y segundos en otro.

---

## 4. Exposición HTTP del endpoint `/metrics`

### 4.1 `start_http_server` — opción standalone

Para procesos sin servidor HTTP propio (worker, job, CLI de larga duración):

```python
from prometheus_client import start_http_server
start_http_server(9100)   # arranca thread en :9100/metrics
```

Levanta un `http.server` dedicado en un thread separado. Útil para no mezclar métricas con tu puerto productivo.

### 4.2 Integración ASGI (FastAPI / Starlette)

Para apps ASGI, la librería incluye `make_asgi_app`:

```python
from fastapi import FastAPI
from prometheus_client import make_asgi_app

app = FastAPI()
app.mount("/metrics", make_asgi_app())
```

Esto monta un sub-app ASGI que atiende el scrape. **Caveat importante**: `app.mount("/metrics", ...)` en FastAPI/Starlette responde `307 Temporary Redirect` cuando el cliente pide `/metrics` sin la barra final (envía a `/metrics/`). Prometheus **no sigue redirects**, así que tu scrape devuelve vacío. Dos soluciones:

1. Añadir un `app.get("/metrics")` que invoca `generate_latest()` directamente:

   ```python
   from prometheus_client import CONTENT_TYPE_LATEST, generate_latest
   from starlette.responses import Response

   @app.get("/metrics")
   def metrics():
       return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
   ```

2. Configurar el `scrape_config` de Prometheus con `metrics_path: /metrics/` (con slash). Preferible la opción 1: contrato con `/metrics` plano y sin sorpresas.

El handler devuelve `Content-Type: text/plain; version=0.0.4; charset=utf-8` (formato Prometheus text) o, si el cliente envía `Accept: application/openmetrics-text`, OpenMetrics con exemplars.

### 4.3 Integración WSGI (Flask, antiguas apps)

```python
from prometheus_client import make_wsgi_app
from werkzeug.middleware.dispatcher import DispatcherMiddleware
app = DispatcherMiddleware(flask_app, {"/metrics": make_wsgi_app()})
```

### 4.4 Puerto separado vs mismo puerto

- **Mismo puerto** (`/metrics` montado en la app) → sencillo, menos ingress, pero `/metrics` queda expuesto detrás del mismo LB/Ingress que la API.
- **Puerto separado** (`start_http_server(9100)`) → aislas scrape de tráfico productivo, el LB solo expone el puerto productivo. Preferido en producción con K8s si tu `ServiceMonitor` sabe apuntar al puerto del sidecar/metrics.

En el capstone usamos el mismo puerto por simplicidad local, y conmutaremos a puerto separado al desplegar en K8s.

---

## 5. Middleware RED en el borde

El patrón RED (Rate, Errors, Duration) requiere tres métricas, instrumentadas **al borde** del servicio (antes de que entre la lógica de negocio, después de que salga la respuesta):

```python
import time
from fastapi import FastAPI, Request
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest
from starlette.responses import Response

REQUESTS = Counter(
    "http_requests_total",
    "Total HTTP requests served",
    ["method", "path", "status"],
)
LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["method", "path"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0),
)

app = FastAPI()


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.middleware("http")
async def red_metrics(request: Request, call_next):
    start = time.perf_counter()
    response = await call_next(request)
    elapsed = time.perf_counter() - start
    path = request.scope.get("route").path if request.scope.get("route") else "unmatched"
    LATENCY.labels(request.method, path).observe(elapsed)
    REQUESTS.labels(request.method, path, str(response.status_code)).inc()
    return response
```

Dos sutilezas:

1. **`path` templatizado, no la URL cruda**. `request.scope["route"].path` te da `/items/{id}`, no `/items/42`. Si usas `request.url.path` tienes cardinalidad infinita en producción.
2. **`unmatched`** como fallback para 404 y rutas no registradas evita que cada URL inventada por un escáner cree una serie nueva.

---

## 6. Labels dinámicos y disciplina de cardinalidad

Cada combinación única de valores de labels **es una serie nueva**. Una serie "cuesta" RAM proporcionalmente en Prometheus. Por eso:

**Correcto como label:**
- `method` (GET/POST/… → cardinalidad acotada ~10).
- `path` **templatizado** (p. ej. `/items/{id}` → cardinalidad = número de rutas, ~decenas).
- `status` o `status_class` (200, 404, 5xx → cardinalidad ~20 o ~5).
- `endpoint`, `handler`, `queue_name`, `topic`, `job`, `tenant` (si es acotado).

**Nunca como label:**
- `user_id`, `email`, `account_id` → millones de valores.
- `request_id`, `trace_id`, `span_id` → infinito (uno por petición).
- `path` **sin templatizar** (`/items/42`, `/items/43`...) → infinito.
- `timestamp` → infinito.
- `user_agent` sin normalizar → miles.
- Mensajes de error libres → infinito.

La regla operativa: antes de añadir una label, pregúntate *¿cuántos valores distintos puede tomar en 30 días?*. Si no sabes acotarlo, no es label.

**Qué hacer con información alta-cardinalidad**: va a **logs** (Loki) o a **traces** (Tempo), no a métricas. Un `trace_id` como *exemplar* (ver §9) sí es válido porque no multiplica series.

---

## 7. No abusar de `Summary`

Un `Summary` calcula cuantiles **por target** y los expone directamente:

```
myapp_latency{quantile="0.5"}  0.042
myapp_latency{quantile="0.99"} 0.400
```

Problemas:
- Para calcular el P99 global de 10 pods, no puedes "promediar" los P99 locales. Es matemáticamente inválido.
- Los cuantiles los configura cada proceso (`quantiles=[(0.5, 0.05), (0.99, 0.001)]`) y recalibrar implica rebuild.
- Agrega CPU (sliding window de observaciones).

**Prefiere Histogram.** Sus buckets son aditivos: `sum(rate(http_latency_bucket[5m])) by (le)` → `histogram_quantile(0.99, …)` → P99 global correcto.

Único caso defensible para Summary: una métrica interna que *solo* interesa en el pod (p. ej. latencia de una cola in-process observada por el runbook del pod) y donde los buckets ya se usaron para otra cosa.

---

## 8. Buenas prácticas (checklist operativo)

- **Medir en el borde**: el middleware ASGI/WSGI observa lo que el usuario ve. Instrumentar handlers individualmente duplica trabajo y pierde errores de framework.
- **Unidades consistentes**: siempre segundos y bytes. Siempre sufijo. Nunca `_ms` ni `_mb`.
- **Nombres estables**: una métrica es un *contrato*. Renombrarla rompe dashboards y alertas.
- **No instrumentes dos veces el mismo evento**: elegirás un número u otro cuando divergen.
- **No introduzcas labels "por si acaso"**: cada label es permanente en espíritu.
- **No uses el `path` crudo**: templatiza o normaliza.
- **No pongas el status completo si solo necesitas la clase**: `status_class="2xx"` reduce 50× la cardinalidad vs `status="200"` para alertas basadas en error rate.
- **No olvides contadores de errores con `_total`** aunque sean `0` en reposo: si no se inicializan, la serie no existe y `rate()` da vacío. Usa `.labels(...).inc(0)` tras arrancar para "pre-crear" la serie si lo necesitas (debate: ver §12).

---

## 9. Exemplars (vínculo métrica ↔ trace)

Un **exemplar** adjunta a una observación un `trace_id` (y otros labels de bajo cardinalidad). Prometheus lo almacena fuera-de-serie: no incrementa cardinalidad. En Grafana, al explorar el histograma, puedes "saltar" al trace de un sample lento concreto.

Requisitos:
- Formato OpenMetrics (el cliente envía `Accept: application/openmetrics-text`).
- `Histogram.observe(value, exemplar={"trace_id": tid})`.
- Un trace activo (OTel), de donde obtienes `tid`.

```python
from opentelemetry import trace
span = trace.get_current_span()
tid = format(span.get_span_context().trace_id, "032x") if span else None
exemplar = {"trace_id": tid} if tid else None
LATENCY.labels("GET", "/items").observe(elapsed, exemplar)
```

Casos típicos: investigar el bump del P99 → clicar un exemplar del bucket `0.5` → aterrizar en Tempo con el span lento.

---

## 10. Modo multiproceso (gunicorn / uwsgi)

Cuando un servidor WSGI/ASGI ejecuta **N workers** (p. ej. gunicorn `--workers 4`), cada worker tiene su propio proceso Python y, por tanto, su propio `REGISTRY` en memoria. Prometheus solo scrapea *un* endpoint, servido por *un* worker: verías solo las métricas de 1/N peticiones.

Solución: **modo multiproceso**. La librería persiste contadores/gauges/histograms en archivos `.db` (uno por proceso) en un directorio compartido, y el `MultiProcessCollector` los une al servir `/metrics`.

```bash
export PROMETHEUS_MULTIPROC_DIR=/tmp/prom_multiproc
mkdir -p "$PROMETHEUS_MULTIPROC_DIR"
rm -f "$PROMETHEUS_MULTIPROC_DIR"/*.db
```

```python
# wsgi.py
from prometheus_client import CollectorRegistry, multiprocess, make_asgi_app
# Importante: NO montar make_asgi_app() con REGISTRY default; usa uno nuevo.
registry = CollectorRegistry()
multiprocess.MultiProcessCollector(registry)
metrics_app = make_asgi_app(registry=registry)
app.mount("/metrics", metrics_app)
```

Y en el hook de muerte del worker, limpia su archivo:

```python
# gunicorn.conf.py
from prometheus_client import multiprocess
def child_exit(server, worker):
    multiprocess.mark_process_dead(worker.pid)
```

Caveats importantes:
- **Gauges** no son agregables sin ambigüedad entre procesos. Debes declarar un `multiprocess_mode`: `"all"` (serie por pid), `"liveall"` (solo pids vivos), `"min"`, `"max"`, `"sum"`, `"livesum"`, `"mostrecent"`. Elegir según semántica (p. ej. "inflight requests" → `sum`).
- **Default collectors** (process, GC, platform) se emiten por proceso del scrape handler; no reflejan a los workers. En multiproceso suele desactivarse `ProcessCollector` default y exponerlo aparte.
- `PROMETHEUS_MULTIPROC_DIR` debe estar en un tmpfs/volumen local; NFS mata rendimiento.

---

## 11. Testing con `REGISTRY.collect()`

Las métricas se pueden testear sin levantar HTTP: `REGISTRY.collect()` devuelve un iterable de `Metric` (familias de métricas), y cada familia tiene `.samples` (lista de `Sample(name, labels, value, timestamp, exemplar)`).

```python
# tests/test_metrics.py
from prometheus_client import REGISTRY

def _value(name, labels=None):
    labels = labels or {}
    for metric in REGISTRY.collect():
        for sample in metric.samples:
            if sample.name == name and all(sample.labels.get(k) == v for k, v in labels.items()):
                return sample.value
    return None


def test_counter_increments():
    from app import REQUESTS   # tu módulo
    before = _value("http_requests_total",
                    {"method": "GET", "path": "/health", "status": "200"}) or 0
    REQUESTS.labels("GET", "/health", "200").inc()
    after = _value("http_requests_total",
                   {"method": "GET", "path": "/health", "status": "200"})
    assert after == before + 1
```

Alternativa pythonica: `generate_latest(REGISTRY).decode()` devuelve el `/metrics` como string; sobre ese string puedes buscar sub-strings esperados en tests de aceptación. Útil para asegurar que *existen* las métricas RED con los labels esperados.

Para tests aislados (sin que el `REGISTRY` global ensucie entre tests), crea un `CollectorRegistry()` propio y pásalo a las métricas:

```python
from prometheus_client import CollectorRegistry, Counter
reg = CollectorRegistry()
c = Counter("x_total", "x", ["k"], registry=reg)
```

---

## 12. Operaciones y antipatterns comunes

**Pre-crear series "cero" o no**: una métrica con labels no aparece hasta la primera observación. Si tu alerta hace `rate(errors_total[5m]) > 0` y en reposo la serie no existe, la query es `absent()` (no cero). Alternativas:
- Alertar sobre `rate(requests_total{status=~"5.."}[5m]) / rate(requests_total[5m])` (el denominador siempre existe).
- Inicializar explícitamente con `.labels(...).inc(0)` al arrancar.
- Usar `or on() vector(0)` en la query.

**Reload de código y pérdida de métricas**: en dev, uvicorn `--reload` crea un nuevo proceso y pierde el `REGISTRY`. No es bug, es naturaleza del hot reload.

**Cambio de buckets** en una `Histogram` ya desplegada: cambia la serie. Los paneles basados en los buckets viejos quedan vacíos tras el deploy. Trata los buckets como contrato.

**Instrumentación duplicada por capas**: si usas `prometheus-fastapi-instrumentator` o similar *y* middleware propio, acabas emitiendo dos familias de métricas (`http_requests_total` y `http_request_duration_seconds` desde la librería y desde ti). Elige uno.

**Scrape de `/metrics` lento**: millones de series por proceso → segundos de serialización → scrape timeout. Si tu `/metrics` tarda > 1 s, revisa cardinalidad.

**Secreto filtrado en una label**: cualquier string que inyectes como valor de label aparece en Prometheus para siempre (dentro de la retención). Jamás metas tokens, cookies, mensajes de usuario o errores crudos.

Con esto cierras el ciclo: tipo correcto → nombre y unidad correctos → labels con cardinalidad acotada → exposición (puerto o mount) → multiproceso si aplica → tests → scrape visible en Prometheus → base para dashboards (`obs-08`) y alertas (`obs-09`).
