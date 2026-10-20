"""Example 03 — record_exception + set_status on failing spans."""

from __future__ import annotations

from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor, ConsoleSpanExporter
from opentelemetry.trace import Status, StatusCode


def configure_tracing() -> TracerProvider:
    provider = TracerProvider(resource=Resource.create({
        "service.name": "example-03-errors",
    }))
    provider.add_span_processor(BatchSpanProcessor(ConsoleSpanExporter()))
    trace.set_tracer_provider(provider)
    return provider


tracer = trace.get_tracer("example-03")


def charge_manual() -> None:
    with tracer.start_as_current_span("payment.charge.manual-handling") as span:
        span.set_attribute("payment.method", "card")
        try:
            raise ValueError("card declined")
        except Exception as exc:
            span.record_exception(exc)
            span.set_status(Status(StatusCode.ERROR, description=str(exc)))
            # Not re-raising — demo-only.


def charge_auto() -> None:
    # record_exception=True AND set_status_on_exception=True do the two steps
    # automatically when an exception escapes the `with` block.
    try:
        with tracer.start_as_current_span(
            "payment.charge.auto-handling",
            record_exception=True,
            set_status_on_exception=True,
        ) as span:
            span.set_attribute("payment.method", "card")
            raise ValueError("card declined")
    except ValueError:
        pass


def main() -> None:
    provider = configure_tracing()
    try:
        charge_manual()
        charge_auto()
    finally:
        provider.shutdown()


if __name__ == "__main__":
    main()
