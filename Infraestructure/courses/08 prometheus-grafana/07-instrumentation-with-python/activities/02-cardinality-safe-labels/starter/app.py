"""BAD instrumentation on purpose.

Several labels blow up cardinality. Audit and fix the metrics so that
tests/validate.sh passes. Do not remove endpoints or change their contract.
"""

from __future__ import annotations

import time
import uuid

from fastapi import FastAPI, Header, HTTPException, Request
from prometheus_client import (
    CONTENT_TYPE_LATEST,
    Counter,
    Histogram,
    generate_latest,
)
from starlette.responses import Response

app = FastAPI(title="bad-items")


@app.get("/metrics")
def metrics_handler():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

# PROBLEM: user_id and item_id are unbounded (per-user, per-row).
# PROBLEM: request_id is unique per request (infinite cardinality).
# PROBLEM: raw status instead of status_class.
# PROBLEM: service_name is a constant — useless as a label.
REQUESTS = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "path", "status", "user_id", "request_id", "service_name"],
)
# PROBLEM: user_id on a histogram is especially bad (buckets * users series).
LATENCY = Histogram(
    "http_request_duration_seconds",
    "Request latency",
    ["method", "path", "user_id", "item_id"],
    buckets=(0.005, 0.01, 0.05, 0.1, 0.5, 1.0),
)


def _templated_path(request: Request) -> str:
    route = request.scope.get("route")
    if route is not None and getattr(route, "path", None):
        return route.path
    return "unmatched"


@app.middleware("http")
async def record(request: Request, call_next):
    method = request.method
    user_id = request.headers.get("x-user-id", "anonymous")
    request_id = str(uuid.uuid4())
    item_id = request.path_params.get("item_id", "none") if request.path_params else "none"
    start = time.perf_counter()
    status = 500
    try:
        response = await call_next(request)
        status = response.status_code
        return response
    finally:
        elapsed = time.perf_counter() - start
        path = _templated_path(request)
        LATENCY.labels(method=method, path=path, user_id=user_id, item_id=str(item_id)).observe(elapsed)
        REQUESTS.labels(
            method=method,
            path=path,
            status=str(status),
            user_id=user_id,
            request_id=request_id,
            service_name="bad-items",
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
