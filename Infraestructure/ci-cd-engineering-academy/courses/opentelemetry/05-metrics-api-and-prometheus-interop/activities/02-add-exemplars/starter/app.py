"""Starter: histogram without tracing (exemplars will be empty).

Your task: add TracerProvider setup and wrap `record()` inside an active span so
the exemplars attached to the histogram carry trace_id/span_id.
"""

from __future__ import annotations

import random
import time

from opentelemetry import metrics
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import (
    ConsoleMetricExporter,
    PeriodicExportingMetricReader,
)
from opentelemetry.sdk.resources import Resource

# TODO: configure a TracerProvider + ConsoleSpanExporter here.


def main() -> None:
    resource = Resource.create({"service.name": "otel-05-02-starter"})
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

    for _ in range(10):
        # TODO: wrap this block inside tracer.start_as_current_span(...)
        start = time.monotonic()
        time.sleep(random.uniform(0.01, 0.1))
        duration.record(time.monotonic() - start, {"endpoint": "/api"})

    time.sleep(1.0)
    metrics.get_meter_provider().shutdown()


if __name__ == "__main__":
    main()
