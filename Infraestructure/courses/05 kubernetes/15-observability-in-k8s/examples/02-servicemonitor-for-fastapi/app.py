"""Minimal FastAPI app with Prometheus /metrics endpoint.

Educational: shows how to mount the Prometheus ASGI app on the same port as the
application, which keeps the Service definition in Kubernetes simple (one port).
"""
from __future__ import annotations

import random
import time

from fastapi import FastAPI, HTTPException
from prometheus_client import Counter, Histogram, make_asgi_app

REQUESTS = Counter(
    "http_requests_total",
    "Total HTTP requests",
    labelnames=("app", "handler", "method", "status"),
)
LATENCY = Histogram(
    "http_request_duration_seconds",
    "Request latency",
    labelnames=("app", "handler", "method"),
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0),
)

app = FastAPI(title="fastapi-metrics")
app.mount("/metrics", make_asgi_app())


def _observe(handler: str, method: str, status: int, elapsed: float) -> None:
    REQUESTS.labels(app="fastapi", handler=handler, method=method, status=str(status)).inc()
    LATENCY.labels(app="fastapi", handler=handler, method=method).observe(elapsed)


@app.get("/")
def root():
    start = time.perf_counter()
    time.sleep(random.uniform(0.005, 0.05))
    _observe("/", "GET", 200, time.perf_counter() - start)
    return {"ok": True}


@app.get("/healthz")
def healthz():
    _observe("/healthz", "GET", 200, 0.001)
    return {"status": "ok"}


@app.get("/boom")
def boom():
    start = time.perf_counter()
    _observe("/boom", "GET", 500, time.perf_counter() - start)
    raise HTTPException(status_code=500, detail="synthetic error for alerts demo")
