"""Solution to otel-06-01: LoggerProvider wired alongside the TracerProvider."""

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
from opentelemetry.sdk.trace.export import BatchSpanProcessor, ConsoleSpanExporter


RESOURCE = Resource.create(
    {"service.name": "otel-06-01-capstone", "service.version": "0.1.0"}
)

_TRACER_PROVIDER = TracerProvider(resource=RESOURCE)
_TRACER_PROVIDER.add_span_processor(BatchSpanProcessor(ConsoleSpanExporter()))
trace.set_tracer_provider(_TRACER_PROVIDER)

_LOGGER_PROVIDER = LoggerProvider(resource=RESOURCE)
_LOGGER_PROVIDER.add_log_record_processor(
    BatchLogRecordProcessor(ConsoleLogRecordExporter())
)
_HANDLER = LoggingHandler(level=logging.INFO, logger_provider=_LOGGER_PROVIDER)
logging.getLogger().addHandler(_HANDLER)


def handle_order(order_id: int) -> None:
    log = logging.getLogger(__name__)
    tracer = trace.get_tracer("orders")
    with tracer.start_as_current_span("handle_order") as span:
        span.set_attribute("order.id", order_id)
        log.info("procesando orden", extra={"order_id": order_id})
        log.info("validando inventario", extra={"order_id": order_id, "sku": "ABC-1"})
        log.info("orden completada", extra={"order_id": order_id, "status": "ok"})


def main() -> None:
    logging.getLogger().setLevel(logging.INFO)
    try:
        for i in range(3):
            handle_order(i)
    finally:
        _TRACER_PROVIDER.shutdown()
        _LOGGER_PROVIDER.shutdown()


if __name__ == "__main__":
    main()
