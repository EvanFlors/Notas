"""Structured logs with auto-correlated trace_id/span_id.

Setup: TracerProvider + LoggerProvider sharing the same Resource. A manual
span wraps a block; the OTel LoggingHandler reads the current span context
and attaches trace_id/span_id to each LogRecord emitted inside.
"""

from __future__ import annotations

import logging

from opentelemetry import trace
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import (
    BatchLogRecordProcessor,
    ConsoleLogRecordExporter,
)
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import (
    BatchSpanProcessor,
    ConsoleSpanExporter,
)


def setup(service_name: str) -> tuple[TracerProvider, LoggerProvider]:
    resource = Resource.create(
        {"service.name": service_name, "service.version": "0.1.0"}
    )

    tp = TracerProvider(resource=resource)
    tp.add_span_processor(BatchSpanProcessor(ConsoleSpanExporter()))
    trace.set_tracer_provider(tp)

    lp = LoggerProvider(resource=resource)
    lp.add_log_record_processor(BatchLogRecordProcessor(ConsoleLogRecordExporter()))

    handler = LoggingHandler(level=logging.INFO, logger_provider=lp)
    root = logging.getLogger()
    root.setLevel(logging.INFO)
    root.addHandler(handler)

    return tp, lp


def charge_customer(user_id: int, amount: float) -> str:
    log = logging.getLogger(__name__)
    tracer = trace.get_tracer("payments")
    with tracer.start_as_current_span("charge_customer") as span:
        span.set_attribute("user.id", user_id)
        span.set_attribute("payment.amount", amount)
        log.info(
            "cobro iniciado",
            extra={"user_id": user_id, "amount": amount, "currency": "USD"},
        )
        # ... logica de pago simulada ...
        log.info("cobro ok", extra={"user_id": user_id, "status": "accepted"})
        return "ok"


def main() -> None:
    tp, lp = setup("example-02")
    log = logging.getLogger(__name__)
    try:
        log.info("fuera-de-span: no deberia tener trace_id real")
        charge_customer(user_id=42, amount=19.95)
        log.info("de-nuevo-fuera-de-span")
    finally:
        tp.shutdown()
        lp.shutdown()


if __name__ == "__main__":
    main()
