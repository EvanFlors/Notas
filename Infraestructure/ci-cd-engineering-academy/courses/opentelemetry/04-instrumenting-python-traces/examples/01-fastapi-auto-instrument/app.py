"""Example 01 — FastAPI app WITHOUT any OTel setup code.

The `opentelemetry-instrument` CLI wrapper will:
  - Install the SDK TracerProvider.
  - Load every opentelemetry-instrumentation-* package present (fastapi, httpx, ...).
  - Export spans to the configured exporter (we set console in run.sh).

Run via: bash run.sh
"""

from __future__ import annotations

import httpx
from fastapi import FastAPI

app = FastAPI(title="example-01-auto")


@app.get("/health")
def health():
    return {"ok": True}


@app.get("/work")
def work():
    # Outbound HTTP: httpx auto-instrumentation emits a CLIENT span.
    with httpx.Client(timeout=2.0) as client:
        try:
            resp = client.get("http://127.0.0.1/__ping__")
            status = resp.status_code
        except Exception:
            status = 0
    return {"downstream_status": status}
