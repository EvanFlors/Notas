"""Starter stub. Complete el wiring OTel (traces + logs) y la funcion
process_order() con 3 spans anidados y logs por span.

Al final, escriba el trace_id del ultimo run en /tmp/otel-06-02/trace-id.txt.
"""

from __future__ import annotations

# TODO: imports de opentelemetry (api, sdk, exporter OTLP), logging

ENDPOINT = "http://localhost:4317"


def setup(service_name: str):
    """TODO: TracerProvider + LoggerProvider con el mismo Resource."""
    raise NotImplementedError


def process_order(order_id: int) -> str:
    """TODO: 3 spans anidados 'receive' > 'validate' > 'charge', 1 log por span.

    Devuelve el trace_id (hex, 32 chars) del root span.
    """
    raise NotImplementedError


def main() -> None:
    # TODO: setup, loop N=10, dump de ultimo trace_id a trace-id.txt
    raise NotImplementedError


if __name__ == "__main__":
    main()
