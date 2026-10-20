"""FastAPI app wired for prometheus_client multiprocess mode.

Expects PROMETHEUS_MULTIPROC_DIR to be set and the directory to exist.
When several workers run (gunicorn --workers N), they persist each metric
in files under $PROMETHEUS_MULTIPROC_DIR, and the /metrics handler uses
MultiProcessCollector on a dedicated registry to aggregate.
"""

from __future__ import annotations

import os

from fastapi import FastAPI
from prometheus_client import (
    CONTENT_TYPE_LATEST,
    CollectorRegistry,
    Counter,
    Gauge,
    generate_latest,
    multiprocess,
)
from starlette.responses import Response

if "PROMETHEUS_MULTIPROC_DIR" not in os.environ:
    raise RuntimeError(
        "PROMETHEUS_MULTIPROC_DIR must be set for multiprocess mode (see run.sh)"
    )

app = FastAPI(title="obs-07 example 03 (multiproc)")


@app.get("/metrics")
def metrics_handler():
    # A fresh registry that only knows the MultiProcessCollector; this is the
    # aggregated view across all workers' .db files. Built per-request so we
    # avoid leaking workers' partial state at import time.
    registry = CollectorRegistry()
    multiprocess.MultiProcessCollector(registry)
    return Response(generate_latest(registry), media_type=CONTENT_TYPE_LATEST)

REQUESTS = Counter(
    "mp_requests_total",
    "Total requests served (multiprocess example)",
    ["endpoint"],
)
# Gauges require a multiprocess_mode. 'livesum' = sum across live workers.
WORKERS_SEEN = Gauge(
    "mp_worker_pid_info",
    "1 per observed worker pid (demo of multiprocess_mode)",
    ["pid"],
    multiprocess_mode="livesum",
)


@app.get("/hit")
def hit():
    REQUESTS.labels(endpoint="/hit").inc()
    WORKERS_SEEN.labels(pid=str(os.getpid())).set(1)
    return {"pid": os.getpid()}


@app.get("/health")
def health():
    return {"ok": True}
