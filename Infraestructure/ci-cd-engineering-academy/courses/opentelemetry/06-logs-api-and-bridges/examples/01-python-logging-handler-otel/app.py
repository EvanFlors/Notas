"""Minimal OTel Logging Handler wiring with a stdout (console) exporter.

Shows how a stdlib `logging.Logger` record is converted into an OTel LogRecord
without any network dependency.
"""

from __future__ import annotations

import logging

from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import (
    BatchLogRecordProcessor,
    ConsoleLogRecordExporter,
)
from opentelemetry.sdk.resources import Resource


def setup_logging() -> LoggerProvider:
    resource = Resource.create(
        {"service.name": "example-01", "service.version": "0.1.0"}
    )
    provider = LoggerProvider(resource=resource)
    provider.add_log_record_processor(
        BatchLogRecordProcessor(ConsoleLogRecordExporter())
    )

    handler = LoggingHandler(level=logging.INFO, logger_provider=provider)
    root = logging.getLogger()
    root.setLevel(logging.INFO)
    root.addHandler(handler)
    return provider


def main() -> None:
    provider = setup_logging()
    log = logging.getLogger(__name__)
    try:
        log.info("servicio arrancado", extra={"component": "boot"})
        log.warning("configuracion por defecto", extra={"section": "cache"})
        log.error("fallo simulado", extra={"error_code": "E_DEMO"})
    finally:
        provider.shutdown()


if __name__ == "__main__":
    main()
