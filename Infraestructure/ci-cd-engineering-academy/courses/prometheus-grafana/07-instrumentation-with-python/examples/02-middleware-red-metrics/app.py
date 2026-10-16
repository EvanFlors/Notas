"""FastAPI app with an ASGI middleware emitting RED metrics (Rate, Errors, Duration).

Highlights:
  - Templated path label (/items/{id}, not /items/42).
  - 'unmatched' fallback for 404s to avoid cardinality explosion.
  - status_class ('2xx', '4xx', '5xx') instead of status code.
  - Inflight gauge for in-flight requests.
"""

from __future__ import annotations

import time

from fastapi import FastAPI, HTTPException, Request
from prometheus_client import (
    CONTENT_TYPE_LATEST,
    Counter,
    Gauge,
    Histogram,
    generate_latest,
)
from starlette.responses import Response

app = FastAPI(title="obs-07 example 02")


@app.get("/metrics")
def metrics_handler():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

REQUESTS = Counter(
    "http_requests_total",
    "Total HTTP requests served",
    ["method", "path", "status_class"],
)
LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["method", "path"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0),
)
INFLIGHT = Gauge(
    "http_requests_inflight",
    "In-flight HTTP requests",
    ["method"],
)


def _status_class(status: int) -> str:
    return f"{status // 100}xx"


def _templated_path(request: Request) -> str:
    route = request.scope.get("route")
    if route is not None and getattr(route, "path", None):
        return route.path
    return "unmatched"


@app.middleware("http")
async def red_metrics(request: Request, call_next):
    method = request.method
    INFLIGHT.labels(method=method).inc()
    start = time.perf_counter()
    try:
        response = await call_next(request)
        status = response.status_code
    except Exception:
        status = 500
        raise
    finally:
        elapsed = time.perf_counter() - start
        path = _templated_path(request)
        LATENCY.labels(method=method, path=path).observe(elapsed)
        REQUESTS.labels(method=method, path=path, status_class=_status_class(status)).inc()
        INFLIGHT.labels(method=method).dec()
    return response


@app.get("/items/{item_id}")
def get_item(item_id: int):
    if item_id < 0:
        raise HTTPException(status_code=400, detail="negative id")
    return {"id": item_id}


@app.get("/health")
def health():
    return {"ok": True}
