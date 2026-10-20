"""Example 02 — Nested business spans with attributes and events.

Programmatic SDK setup + ConsoleSpanExporter so no Collector is needed.
"""

from __future__ import annotations

import time

from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor, ConsoleSpanExporter


def configure_tracing() -> TracerProvider:
    resource = Resource.create({
        "service.name": "example-02-business-spans",
        "service.version": "0.1.0",
        "deployment.environment": "dev",
    })
    provider = TracerProvider(resource=resource)
    provider.add_span_processor(BatchSpanProcessor(ConsoleSpanExporter()))
    trace.set_tracer_provider(provider)
    return provider


tracer = trace.get_tracer("example-02")


def reserve_inventory(cart_id: str, items_count: int) -> None:
    with tracer.start_as_current_span("inventory.reserve") as span:
        span.set_attribute("inventory.cart_id", cart_id)
        span.set_attribute("inventory.items.count", items_count)
        time.sleep(0.01)


def charge_payment(user_id: str, amount_cents: int) -> str:
    with tracer.start_as_current_span("payment.charge") as span:
        span.set_attribute("payment.user_id", user_id)
        span.set_attribute("payment.amount_cents", amount_cents)
        span.set_attribute("payment.method", "card")
        time.sleep(0.02)
        return "pay_abc123"


def process_checkout(cart_id: str, user_id: str, items_count: int, total_cents: int) -> str:
    with tracer.start_as_current_span("checkout.process") as span:
        span.set_attribute("checkout.cart_id", cart_id)
        span.set_attribute("checkout.total_cents", total_cents)
        span.set_attribute("enduser.id", user_id)
        reserve_inventory(cart_id, items_count)
        span.add_event("fraud.check.passed", {"risk.score": 0.12})
        payment_id = charge_payment(user_id, total_cents)
        span.set_attribute("checkout.payment_id", payment_id)
        return payment_id


def main() -> None:
    provider = configure_tracing()
    try:
        pid = process_checkout(cart_id="cart_42", user_id="u_7", items_count=3, total_cents=4999)
        print(f"checkout OK, payment_id={pid}")
    finally:
        provider.shutdown()  # flush pending batch


if __name__ == "__main__":
    main()
