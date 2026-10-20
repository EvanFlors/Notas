"""Minimal OTel metrics example: Counter + Histogram + ObservableGauge.

Runs for a few seconds, emits metrics, exports to stdout via ConsoleMetricExporter
and exits. No HTTP, no OTLP collector required — portable and offline.
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


def main() -> None:
    resource = Resource.create({"service.name": "otel-05-ex01"})
    reader = PeriodicExportingMetricReader(
        ConsoleMetricExporter(),
        export_interval_millis=1000,
    )
    provider = MeterProvider(metric_readers=[reader], resource=resource)
    metrics.set_meter_provider(provider)

    meter = metrics.get_meter("example.app", "1.0.0")

    requests = meter.create_counter(
        "http.server.requests",
        unit="1",
        description="Count of HTTP requests served",
    )
    duration = meter.create_histogram(
        "http.server.duration",
        unit="s",
        description="Duration of HTTP requests in seconds",
    )

    # Observable gauge — callback invoked on each export cycle.
    _state = {"depth": 0}

    def _cb_queue_depth(_options):
        yield metrics.Observation(_state["depth"], {"queue.name": "jobs"})

    meter.create_observable_gauge(
        "myapp.queue.depth",
        callbacks=[_cb_queue_depth],
        unit="1",
        description="Jobs pending in the local queue",
    )

    # Simulate traffic for ~3 seconds so we export at least twice.
    end = time.monotonic() + 3.0
    while time.monotonic() < end:
        method = random.choice(["GET", "POST"])
        status = random.choice([200, 200, 200, 404, 500])
        requests.add(1, {"http.request.method": method,
                         "http.response.status_code": status})
        duration.record(random.uniform(0.005, 0.5),
                        {"http.request.method": method})
        _state["depth"] = random.randint(0, 10)
        time.sleep(0.05)

    provider.shutdown()


if __name__ == "__main__":
    main()
