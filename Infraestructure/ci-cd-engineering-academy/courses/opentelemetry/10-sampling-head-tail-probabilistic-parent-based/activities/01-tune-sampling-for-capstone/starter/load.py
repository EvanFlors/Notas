"""Synthetic load for the capstone sampling lab.
Same shape as examples/02: 150 fast ok + 100 slow ok + 50 errors.
"""
from __future__ import annotations

import os
import sys
import time

from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.trace.sampling import ALWAYS_ON
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.trace import Status, StatusCode

ENDPOINT = os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:14317")

FAST_OK = 150
SLOW_OK = 100
ERRORS = 50


def main() -> int:
    resource = Resource.create({"service.name": "capstone-sampling"})
    provider = TracerProvider(resource=resource, sampler=ALWAYS_ON)
    provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter(endpoint=ENDPOINT, insecure=True)))
    trace.set_tracer_provider(provider)
    tracer = trace.get_tracer("capstone")

    print(f"Emitting FAST_OK={FAST_OK} SLOW_OK={SLOW_OK} ERRORS={ERRORS} → {ENDPOINT}")
    for _ in range(FAST_OK):
        with tracer.start_as_current_span("fast-ok") as s:
            s.set_attribute("http.route", "/ping")
            time.sleep(0.001)
    for _ in range(SLOW_OK):
        with tracer.start_as_current_span("slow-ok") as s:
            s.set_attribute("http.route", "/report")
            time.sleep(0.6)
    for _ in range(ERRORS):
        with tracer.start_as_current_span("errored") as s:
            s.set_attribute("http.route", "/pay")
            time.sleep(0.01)
            s.set_status(Status(StatusCode.ERROR, "intentional"))

    provider.force_flush(timeout_millis=10_000)
    provider.shutdown()
    print("Flushed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
