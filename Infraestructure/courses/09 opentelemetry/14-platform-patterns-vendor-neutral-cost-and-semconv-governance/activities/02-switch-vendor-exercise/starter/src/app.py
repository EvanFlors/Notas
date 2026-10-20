"""Capstone app (fictitious). Do NOT modify as part of this exercise.

The whole point: changing backends is a Collector-only change. If you touched
this file, your migration is not vendor-neutral.
"""
from __future__ import annotations

from opentelemetry import trace
from opentelemetry.trace import SpanKind

tracer = trace.get_tracer("nimbora.payments")


def charge(order_id: str, amount_cents: int) -> dict:
    """Process a payment. OTLP goes to the local Collector; app knows nothing
    about the backend behind it."""
    with tracer.start_as_current_span(
        "payments.charge", kind=SpanKind.SERVER
    ) as span:
        span.set_attribute("payments.amount_cents", amount_cents)
        # order_id intentionally not set as metric label — see contract 6.2.
        span.set_attribute("payments.order_id", order_id)
        # ... business logic ...
        return {"status": "ok", "order_id": order_id}
