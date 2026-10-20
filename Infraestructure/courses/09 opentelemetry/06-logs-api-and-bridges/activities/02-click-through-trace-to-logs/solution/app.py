"""Solution: 3 nested spans + 1 log per span, OTLP export to Collector."""

from __future__ import annotations

import logging
import os
import time
from pathlib import Path

from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor


ENDPOINT = os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4317")
OUT_DIR = Path(os.environ.get("WORK_DIR", "/tmp/otel-06-02"))


def setup(service_name: str) -> tuple[TracerProvider, LoggerProvider]:
    resource = Resource.create(
        {"service.name": service_name, "service.version": "0.1.0"}
    )
    tp = TracerProvider(resource=resource)
    tp.add_span_processor(
        BatchSpanProcessor(OTLPSpanExporter(endpoint=ENDPOINT, insecure=True))
    )
    trace.set_tracer_provider(tp)

    lp = LoggerProvider(resource=resource)
    lp.add_log_record_processor(
        BatchLogRecordProcessor(OTLPLogExporter(endpoint=ENDPOINT, insecure=True))
    )
    handler = LoggingHandler(level=logging.INFO, logger_provider=lp)
    root = logging.getLogger()
    root.setLevel(logging.INFO)
    root.addHandler(handler)
    root.addHandler(logging.StreamHandler())
    return tp, lp


def process_order(order_id: int) -> str:
    log = logging.getLogger(__name__)
    tracer = trace.get_tracer("orders")
    with tracer.start_as_current_span("receive") as receive_span:
        receive_span.set_attribute("order.id", order_id)
        log.info("orden recibida", extra={"order_id": order_id})
        trace_id_hex = f"{receive_span.get_span_context().trace_id:032x}"
        with tracer.start_as_current_span("validate"):
            log.info("validando orden", extra={"order_id": order_id})
            time.sleep(0.01)
        with tracer.start_as_current_span("charge"):
            log.info("cobrando", extra={"order_id": order_id, "amount": 42.0})
            time.sleep(0.02)
    return trace_id_hex


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    tp, lp = setup("otel-06-02-demo")
    last_tid = ""
    try:
        for i in range(10):
            last_tid = process_order(i)
            time.sleep(0.1)
    finally:
        (OUT_DIR / "trace-id.txt").write_text(last_tid + "\n")
        tp.shutdown()
        lp.shutdown()


if __name__ == "__main__":
    main()
