"""Cumulative vs Delta temporality side-by-side.

Two separate MeterProviders are configured, each with its own
ConsoleMetricExporter but different `preferred_temporality`. The same series of
Counter increments is sent to both. The output clearly shows that:

- Cumulative: each export reports the running total (ever-growing).
- Delta: each export reports only the increments since the previous export.
"""

from __future__ import annotations

import time

from opentelemetry.metrics import MeterProvider as _MP  # for type only
from opentelemetry.sdk.metrics import Counter, Histogram, MeterProvider
from opentelemetry.sdk.metrics.export import (
    AggregationTemporality,
    ConsoleMetricExporter,
    PeriodicExportingMetricReader,
)
from opentelemetry.sdk.resources import Resource


def _build_provider(name: str, temporality: AggregationTemporality) -> MeterProvider:
    reader = PeriodicExportingMetricReader(
        ConsoleMetricExporter(
            preferred_temporality={
                Counter: temporality,
                Histogram: temporality,
            }
        ),
        export_interval_millis=1000,
    )
    return MeterProvider(
        metric_readers=[reader],
        resource=Resource.create({"service.name": name}),
    )


def main() -> None:
    cum_provider = _build_provider("cumulative-demo", AggregationTemporality.CUMULATIVE)
    delta_provider = _build_provider("delta-demo", AggregationTemporality.DELTA)

    cum_counter = cum_provider.get_meter("demo").create_counter("demo.events")
    delta_counter = delta_provider.get_meter("demo").create_counter("demo.events")

    # Emit a steady stream for ~3 seconds so we export ~3 times.
    end = time.monotonic() + 3.0
    while time.monotonic() < end:
        cum_counter.add(1, {"kind": "tick"})
        delta_counter.add(1, {"kind": "tick"})
        time.sleep(0.1)

    cum_provider.shutdown()
    delta_provider.shutdown()


if __name__ == "__main__":
    main()
