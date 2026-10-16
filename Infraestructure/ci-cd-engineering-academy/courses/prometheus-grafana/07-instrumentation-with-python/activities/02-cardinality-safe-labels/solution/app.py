"""Reference solution — cardinality-safe labels.

Fixes applied vs starter:
  - Dropped: user_id, request_id, service_name, item_id.
  - Replaced raw status by status_class ("2xx"/"4xx"/"5xx").
  - Kept: method, path (templated).
  - High-cardinality info (user_id, request_id) belongs in logs/traces,
    not in metric labels.
"""

from __future__ import annotations

import time

from fastapi import FastAPI, Header, HTTPException, Request
from prometheus_client import (
    CONTENT_TYPE_LATEST,
    Counter,
    Histogram,
    generate_latest,
)
from starlette.responses import Response

app = FastAPI(title="good-items")


@app.get("/metrics")
def metrics_handler():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

REQUESTS = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "path", "status_class"],
)
LATENCY = Histogram(
    "http_request_duration_seconds",
    "Request latency",
    ["method", "path"],
    buckets=(0.005, 0.01, 0.05, 0.1, 0.5, 1.0),
)


def _status_class(code: int) -> str:
    return f"{code // 100}xx"


def _templated_path(request: Request) -> str:
    route = request.scope.get("route")
    if route is not None and getattr(route, "path", None):
        return route.path
    return "unmatched"


@app.middleware("http")
async def record(request: Request, call_next):
    method = request.method
    start = time.perf_counter()
    status = 500
    try:
        response = await call_next(request)
        status = response.status_code
        return response
    finally:
        elapsed = time.perf_counter() - start
        path = _templated_path(request)
        LATENCY.labels(method=method, path=path).observe(elapsed)
        REQUESTS.labels(
            method=method, path=path, status_class=_status_class(status)
        ).inc()


@app.get("/health")
def health():
    return {"ok": True}


@app.get("/items/{item_id}")
def get_item(item_id: int, x_user_id: str | None = Header(default=None)):
    if item_id < 0:
        raise HTTPException(status_code=400, detail="negative id")
    return {"id": item_id, "owner": x_user_id or "anonymous"}


@app.post("/items/")
def create_item():
    return {"ok": True}
