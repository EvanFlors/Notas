"""Python app emitting correlated traces + logs via OTLP to a local Collector,
which forwards logs to Loki.
"""

from __future__ import annotations

import logging
import os
import random
import time

from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor


ENDPOINT = os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4317")


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
    root.addHandler(logging.StreamHandler())  # dual-sink: stdout + OTLP

    return tp, lp


def do_work(req_id: int) -> None:
    log = logging.getLogger(__name__)
    tracer = trace.get_tracer("example-03")

    with tracer.start_as_current_span("handle_request") as outer:
        outer.set_attribute("req.id", req_id)
        log.info("request recibido", extra={"req_id": req_id})

        with tracer.start_as_current_span("db_query"):
            time.sleep(random.uniform(0.01, 0.05))
            log.info("db ok", extra={"req_id": req_id, "rows": 7})

        if random.random() < 0.2:
            log.error("fallo transitorio", extra={"req_id": req_id})
            outer.set_status(trace.Status(trace.StatusCode.ERROR))


def main() -> None:
    tp, lp = setup("example-03")
    try:
        for i in range(10):
            do_work(i)
            time.sleep(0.1)
    finally:
        tp.shutdown()
        lp.shutdown()


if __name__ == "__main__":
    main()
