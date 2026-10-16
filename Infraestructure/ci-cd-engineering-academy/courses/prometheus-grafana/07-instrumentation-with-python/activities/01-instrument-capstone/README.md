# obs-07-01 — Instrument capstone FastAPI service with RED metrics

## 1. Identificación
- **ID:** `obs-07-01-instrument-capstone`
- **Tecnología:** prometheus-grafana
- **Módulo:** 07-instrumentation-with-python
- **Dificultad:** intermediate
- **Duración estimada:** 60 min
- **Tipo:** guided-lab

## 2. Contexto

Recibes un `starter/app.py` que es un servicio FastAPI mínimo del capstone (CRUD muy reducido de `items`). No tiene métricas. Tu tarea: añadirle `/metrics` y un middleware RED **correcto** (cardinalidad acotada, naming conforme) para que el stack Prometheus pueda construir dashboards y alertas.

## 3. Objetivos

- Exponer `/metrics` (vía ruta `@app.get("/metrics")` que llama `generate_latest()`, o `app.mount` + `metrics_path: /metrics/` en Prometheus — pero cuidado con el 307).
- Crear:
  - `http_requests_total{method,path,status_class}` (Counter).
  - `http_request_duration_seconds{method,path}` (Histogram) con buckets explícitos.
- Middleware ASGI que incrementa Counter y observa Histogram al salir.
- `path` debe venir **templatizado** (`/items/{item_id}`), no la URL cruda.
- `status_class` = `2xx`/`4xx`/`5xx`.

## 4. Prerrequisitos

- Python 3.10+
- `pip install fastapi uvicorn prometheus_client httpx`
- Puerto libre (default 8788).
- No requiere Docker.
- Coste: 0.

## 5. Instrucciones

1. Entra en `starter/`.
2. Lee `app.py` — tiene `GET /health`, `GET /items/{item_id}`, `POST /items/`. **No** instrumentes dentro de los handlers; usa middleware.
3. Edita `app.py` para:
   - Importar `Counter`, `Histogram`, `make_asgi_app` de `prometheus_client`.
   - Declarar las dos métricas con los nombres/labels exactos del §3.
   - Montar `app.mount("/metrics", make_asgi_app())`.
   - Añadir un `@app.middleware("http")` que mida duración y cuente requests al terminar.
   - Obtener el `path` desde `request.scope.get("route").path` (fallback `"unmatched"`).
4. Lanza:
   ```bash
   cd starter
   uvicorn app:app --port 8788
   ```
5. En otra terminal:
   ```bash
   curl -s localhost:8788/health
   curl -s localhost:8788/items/1
   curl -s -X POST localhost:8788/items/ -H 'content-type: application/json' -d '{"name":"x"}'
   curl -s localhost:8788/metrics | head -40
   ```
6. Corre el validador: `bash tests/validate.sh`.
7. Si falla, lee el mensaje: te dice qué métrica/label falta.

Si te quedas atascado, mira `solution/` **al final**.

## 6. Resultado esperado

- `curl /metrics` incluye líneas tipo:
  ```
  http_requests_total{method="GET",path="/items/{item_id}",status_class="2xx"} 1
  http_request_duration_seconds_bucket{method="GET",path="/items/{item_id}",le="0.025"} 1
  ```
- Ninguna métrica contiene `path="/items/1"` (sin templatizar).
- `bash tests/validate.sh` imprime `OK`.

## 7. Criterios de aceptación

- Métricas con los nombres y labels exactos definidos.
- `path` templatizado para rutas conocidas; `unmatched` para 404s.
- `status_class` en lugar de código completo.
- `/metrics` responde `200 OK` y formato texto válido.

## 8. Validación

```bash
bash tests/validate.sh
```

Levanta uvicorn, pega a los endpoints, scrape `/metrics`, verifica expectativas.

## 9. Preguntas de reflexión

- ¿Por qué `status_class` reduce coste frente a `status` entero?
- ¿Qué ocurre con la cardinalidad si un bot pide `/foo/{random}` 10.000 veces y usas `request.url.path` como label?
- ¿Por qué el middleware mide en `finally` (y no después de `response = await call_next(...)`)?
- ¿Cómo cambiarías los buckets si tu P99 esperado es 2 s?

## 10. Extensiones

- Añade un `Gauge` `http_requests_inflight{method}` con inc/dec.
- Pre-crea con `.inc(0)` las series de `status_class="5xx"` para que las alertas no sean `absent`.
- Añade un test unitario con `REGISTRY.collect()` que no necesite levantar uvicorn.

## 11. Limpieza

```bash
pkill -f "uvicorn app:app --port 8788" 2>/dev/null || true
```

No hay recursos cloud; sin coste residual.
