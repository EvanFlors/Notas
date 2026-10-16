"""Solution: histogram recorded inside an active span → exemplars populated."""

from __future__ import annotations

import random
import time

from opentelemetry import metrics, trace
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import (
    ConsoleMetricExporter,
    PeriodicExportingMetricReader,
)
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor, ConsoleSpanExporter


def main() -> None:
    resource = Resource.create({"service.name": "otel-05-02-solution"})

    tp = TracerProvider(resource=resource)
    tp.add_span_processor(BatchSpanProcessor(ConsoleSpanExporter()))
    trace.set_tracer_provider(tp)
    tracer = trace.get_tracer("example.app")

    reader = PeriodicExportingMetricReader(
        ConsoleMetricExporter(),
        export_interval_millis=500,
    )
    metrics.set_meter_provider(
        MeterProvider(metric_readers=[reader], resource=resource)
    )
    meter = metrics.get_meter("example.app")
    duration = meter.create_histogram(
        "work.duration", unit="s",
        description="Duration of a unit of work",
    )

    for i in range(10):
        with tracer.start_as_current_span(f"handle-{i}") as span:
            span.set_attribute("iteration", i)
            start = time.monotonic()
            time.sleep(random.uniform(0.01, 0.1))
            duration.record(time.monotonic() - start, {"endpoint": "/api"})

    time.sleep(1.0)
    metrics.get_meter_provider().shutdown()
    trace.get_tracer_provider().shutdown()


if __name__ == "__main__":
    main()
