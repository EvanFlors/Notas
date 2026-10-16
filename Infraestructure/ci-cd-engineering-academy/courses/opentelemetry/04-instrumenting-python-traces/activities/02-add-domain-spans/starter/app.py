"""Starter — FastAPI checkout with HTTP spans only.

The TracerProvider is already configured. A middleware emits a span called
'http.server.request' per request with HTTP attributes. That's all.

TODO (student):
  Add three business-domain spans (names are a contract — do not change them):
    - "checkout.process"  wraps the handler body
        attrs: checkout.cart_id, checkout.total_cents, enduser.id
    - "inventory.reserve" wraps reserve_inventory
        attrs: inventory.cart_id, inventory.items.count
    - "payment.charge"    wraps charge_payment
        attrs: payment.user_id, payment.amount_cents, payment.method

  When charge_payment raises ValueError, call:
    span.record_exception(exc)
    span.set_status(Status(StatusCode.ERROR, description=str(exc)))

Run:
    python3 -m uvicorn app:app --port 8792
"""

from __future__ import annotations

import os
import time

from fastapi import FastAPI, HTTPException, Request
from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import (
    BatchSpanProcessor,
    ConsoleSpanExporter,
)
from opentelemetry.trace import SpanKind
from pydantic import BaseModel


def configure_tracing() -> TracerProvider:
    provider = TracerProvider(resource=Resource.create({
        "service.name": "capstone-checkout",
        "service.version": "0.1.0",
        "deployment.environment": os.getenv("DEPLOYMENT_ENV", "dev"),
    }))

    if os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT"):
        try:
            from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import (
                OTLPSpanExporter,
            )
            exporter = OTLPSpanExporter(insecure=True)
        except ImportError:
            exporter = ConsoleSpanExporter()
    else:
        exporter = ConsoleSpanExporter()

    provider.add_span_processor(BatchSpanProcessor(exporter))
    trace.set_tracer_provider(provider)
    return provider


_PROVIDER = configure_tracing()
tracer = trace.get_tracer(__name__)

app = FastAPI(title="capstone-checkout")


@app.on_event("shutdown")
def _flush() -> None:
    _PROVIDER.shutdown()


@app.middleware("http")
async def http_server_span(request: Request, call_next):
    """Pre-existing middleware — DO NOT MODIFY.

    Emits a SERVER span per request with HTTP attributes. Any span the student
    creates inside the handler will be a child of this via Context.
    """
    route = request.scope.get("route")
    route_path = getattr(route, "path", None) if route is not None else None
    with tracer.start_as_current_span(
        "http.server.request",
        kind=SpanKind.SERVER,
    ) as span:
        span.set_attribute("http.request.method", request.method)
        if route_path:
            span.set_attribute("http.route", route_path)
        start = time.perf_counter()
        response = await call_next(request)
        span.set_attribute("http.response.status_code", response.status_code)
        span.set_attribute("http.server.duration_ms",
                           int((time.perf_counter() - start) * 1000))
        return response


class CheckoutIn(BaseModel):
    cart_id: str
    user_id: str
    items_count: int
    total_cents: int


def reserve_inventory(cart_id: str, items_count: int) -> None:
    # TODO: wrap in "inventory.reserve" span with attributes.
    if items_count <= 0:
        raise HTTPException(status_code=400, detail="items_count must be > 0")


def charge_payment(user_id: str, amount_cents: int) -> str:
    # TODO: wrap in "payment.charge" span with attributes.
    # TODO: on ValueError, record_exception + set_status(ERROR) before raising.
    if amount_cents > 100_000:
        raise ValueError("amount above limit")
    return f"pay_{user_id}_{amount_cents}"


@app.get("/health")
def health():
    return {"ok": True}


@app.post("/checkout")
def checkout(req: CheckoutIn):
    # TODO: wrap this body in "checkout.process" span with domain attributes.
    try:
        reserve_inventory(req.cart_id, req.items_count)
        payment_id = charge_payment(req.user_id, req.total_cents)
        return {"ok": True, "payment_id": payment_id}
    except ValueError as exc:
        raise HTTPException(status_code=402, detail=str(exc))
