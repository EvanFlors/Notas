"""Capstone solution — instrumented items service with RED metrics."""

from __future__ import annotations

import time

from fastapi import FastAPI, HTTPException, Request
from prometheus_client import (
    CONTENT_TYPE_LATEST,
    Counter,
    Histogram,
    generate_latest,
)
from pydantic import BaseModel
from starlette.responses import Response

app = FastAPI(title="capstone-items")


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


def _status_class(code: int) -> str:
    return f"{code // 100}xx"


def _templated_path(request: Request) -> str:
    route = request.scope.get("route")
    if route is not None and getattr(route, "path", None):
        return route.path
    return "unmatched"


@app.middleware("http")
async def red_metrics(request: Request, call_next):
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


_items: dict[int, dict] = {}
_next_id = 1


class ItemIn(BaseModel):
    name: str


@app.get("/health")
def health():
    return {"ok": True}


@app.get("/items/{item_id}")
def get_item(item_id: int):
    if item_id not in _items:
        raise HTTPException(status_code=404, detail="not found")
    return _items[item_id]


@app.post("/items/")
def create_item(item: ItemIn):
    global _next_id
    item_id = _next_id
    _next_id += 1
    _items[item_id] = {"id": item_id, "name": item.name}
    return _items[item_id]
