"""Generate a mixed workload: fast ok, slow ok, errors.

Exports via OTLP gRPC to localhost:4317 (the Collector).
"""
from __future__ import annotations

import time
import os
import sys

from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.trace.sampling import ALWAYS_ON
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.trace import Status, StatusCode

ENDPOINT = os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4317")

FAST_OK = 150
SLOW_OK = 100
ERRORS = 50


def build_tracer():
    resource = Resource.create({"service.name": "tail-sampling-demo"})
    provider = TracerProvider(resource=resource, sampler=ALWAYS_ON)
    exporter = OTLPSpanExporter(endpoint=ENDPOINT, insecure=True)
    provider.add_span_processor(BatchSpanProcessor(exporter))
    trace.set_tracer_provider(provider)
    return trace.get_tracer("load"), provider


def emit_fast_ok(tracer):
    with tracer.start_as_current_span("fast-ok") as span:
        span.set_attribute("http.route", "/ping")
        time.sleep(0.001)


def emit_slow_ok(tracer):
    with tracer.start_as_current_span("slow-ok") as span:
        span.set_attribute("http.route", "/report")
        # 600ms > 500ms threshold
        time.sleep(0.6)


def emit_error(tracer):
    with tracer.start_as_current_span("errored") as span:
        span.set_attribute("http.route", "/pay")
        time.sleep(0.01)
        span.set_status(Status(StatusCode.ERROR, "intentional"))


def main() -> int:
    tracer, provider = build_tracer()
    print(f"Emitting FAST_OK={FAST_OK} SLOW_OK={SLOW_OK} ERRORS={ERRORS} to {ENDPOINT}")

    for _ in range(FAST_OK):
        emit_fast_ok(tracer)
    for _ in range(SLOW_OK):
        emit_slow_ok(tracer)
    for _ in range(ERRORS):
        emit_error(tracer)

    provider.force_flush(timeout_millis=10_000)
    provider.shutdown()
    print("Flushed. Exiting.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
