"""Capstone starter — a tiny items service without metrics.

TODO (student):
  1. Expose /metrics (prefer `@app.get("/metrics")` returning
     Response(generate_latest(), media_type=CONTENT_TYPE_LATEST) because
     app.mount("/metrics", ...) causes a 307 redirect that Prometheus
     will NOT follow).
  2. Declare:
       - Counter: http_requests_total{method, path, status_class}
       - Histogram: http_request_duration_seconds{method, path}
  3. Add an ASGI middleware that:
       - measures elapsed time
       - uses the templated path (request.scope['route'].path, else 'unmatched')
       - uses status_class ("2xx"/"4xx"/"5xx")
"""

from __future__ import annotations

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="capstone-items")

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
