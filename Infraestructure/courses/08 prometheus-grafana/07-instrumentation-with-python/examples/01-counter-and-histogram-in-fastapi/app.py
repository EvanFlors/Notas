"""Minimal FastAPI app exposing a Counter and a Histogram at /metrics.

Run: uvicorn app:app --port 8000
Scrape: curl -s http://localhost:8000/metrics | grep -E '^(demo_|http_)'
"""

from __future__ import annotations

import random
import time

from fastapi import FastAPI
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest
from starlette.responses import Response

app = FastAPI(title="obs-07 example 01")


@app.get("/metrics")
def metrics():
    # Direct route (not mount) so Prometheus hits /metrics with no 307 redirect.
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

DEMO_REQUESTS = Counter(
    "demo_requests_total",
    "Total demo requests served",
    ["endpoint"],
)
DEMO_LATENCY = Histogram(
    "demo_request_duration_seconds",
    "Demo request latency in seconds",
    ["endpoint"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0),
)


@app.get("/health")
def health():
    DEMO_REQUESTS.labels(endpoint="/health").inc()
    with DEMO_LATENCY.labels(endpoint="/health").time():
        pass
    return {"ok": True}


@app.get("/work")
def work():
    DEMO_REQUESTS.labels(endpoint="/work").inc()
    start = time.perf_counter()
    time.sleep(random.uniform(0.01, 0.2))
    DEMO_LATENCY.labels(endpoint="/work").observe(time.perf_counter() - start)
    return {"ok": True}
