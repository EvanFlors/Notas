"""Exemplars: linking a histogram sample to the span that produced it.

Records a histogram value from inside an active span. The default
ExplicitBucketHistogramAggregation attaches an exemplar carrying `trace_id` and
`span_id`. We use ConsoleMetricExporter so the exemplar is visible in stdout.
"""

from __future__ import annotations

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
    resource = Resource.create({"service.name": "otel-05-ex03"})

    # Tracing setup — needed so a span is active when we record the histogram.
    trace.set_tracer_provider(TracerProvider(resource=resource))
    trace.get_tracer_provider().add_span_processor(
        BatchSpanProcessor(ConsoleSpanExporter())
    )
    tracer = trace.get_tracer("example.app")

    # Metrics setup.
    reader = PeriodicExportingMetricReader(
        ConsoleMetricExporter(),
        export_interval_millis=1000,
    )
    metrics.set_meter_provider(
        MeterProvider(metric_readers=[reader], resource=resource)
    )
    meter = metrics.get_meter("example.app")
    duration = meter.create_histogram(
        "work.duration",
        unit="s",
        description="Duration of a unit of work",
    )

    # Record inside a span — exemplar should carry its trace_id/span_id.
    for i in range(6):
        with tracer.start_as_current_span(f"handle-{i}") as span:
            span.set_attribute("iteration", i)
            start = time.monotonic()
            time.sleep(0.05)
            duration.record(time.monotonic() - start, {"endpoint": "/api"})
        time.sleep(0.1)

    time.sleep(1.2)  # let the reader flush at least once.
    metrics.get_meter_provider().shutdown()
    trace.get_tracer_provider().shutdown()


if __name__ == "__main__":
    main()
