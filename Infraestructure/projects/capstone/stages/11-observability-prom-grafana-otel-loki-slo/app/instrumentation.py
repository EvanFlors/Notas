"""OpenTelemetry SDK bootstrap for the capstone FastAPI service.

Call ``init_telemetry("capstone-api")`` exactly once at import time from
``app/main.py``. Safe to call again: it checks whether a non-default
``TracerProvider`` is already registered and short-circuits in that case,
which prevents double-registration during Alembic autogeneration, pytest
collection, or uvicorn reloads.

Env vars honored (all with sane defaults so local dev needs no setup):

- ``OTEL_EXPORTER_OTLP_ENDPOINT``      default ``http://otel-agent.observability.svc:4317``
- ``OTEL_EXPORTER_OTLP_PROTOCOL``      default ``grpc`` (``http/protobuf`` also OK)
- ``OTEL_SERVICE_NAME``                overrides the arg to ``init_telemetry``
- ``OTEL_RESOURCE_ATTRIBUTES``         merged on top of the computed resource
- ``OTEL_TRACES_SAMPLER_ARG``          default ``0.1`` (10 % head sampling)
- ``DEPLOYMENT_ENVIRONMENT``           default ``capstone``
"""

from __future__ import annotations

import logging
import os
from typing import Optional

logger = logging.getLogger(__name__)

_INITIALIZED = False


def init_telemetry(service_name: str = "capstone-api", version: Optional[str] = None) -> None:
    """Initialize the OTel SDK: tracer provider + OTLP exporter + propagators.

    Idempotent. Never raises on missing optional deps — if the SDK is not
    installed, we log a warning and return, so the app still boots.
    """
    global _INITIALIZED
    if _INITIALIZED:
        return

    try:
        from opentelemetry import trace
        from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import (
            OTLPSpanExporter,
        )
        from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
        from opentelemetry.propagate import set_global_textmap
        from opentelemetry.propagators.b3 import B3MultiFormat
        from opentelemetry.propagators.composite import CompositePropagator
        from opentelemetry.sdk.resources import Resource
        from opentelemetry.sdk.trace import TracerProvider
        from opentelemetry.sdk.trace.export import BatchSpanProcessor
        from opentelemetry.sdk.trace.sampling import ParentBased, TraceIdRatioBased
        from opentelemetry.trace.propagation.tracecontext import (
            TraceContextTextMapPropagator,
        )
    except ImportError as exc:  # pragma: no cover - exercised only when deps are missing
        logger.warning("OpenTelemetry SDK not installed; skipping init (%s).", exc)
        return

    # If someone already configured a non-default provider (tests, container, etc.),
    # respect it. The default provider is a ProxyTracerProvider.
    current = trace.get_tracer_provider()
    if isinstance(current, TracerProvider):
        _INITIALIZED = True
        return

    endpoint = os.getenv(
        "OTEL_EXPORTER_OTLP_ENDPOINT",
        "http://otel-agent.observability.svc:4317",
    )
    env = os.getenv("DEPLOYMENT_ENVIRONMENT", "capstone")
    sampling_ratio = float(os.getenv("OTEL_TRACES_SAMPLER_ARG", "0.1"))
    svc = os.getenv("OTEL_SERVICE_NAME", service_name)

    resource = Resource.create(
        {
            "service.name": svc,
            "service.version": version or os.getenv("APP_VERSION", "0.0.0-dev"),
            "deployment.environment": env,
        }
    )

    provider = TracerProvider(
        resource=resource,
        sampler=ParentBased(root=TraceIdRatioBased(sampling_ratio)),
    )
    provider.add_span_processor(
        BatchSpanProcessor(
            OTLPSpanExporter(endpoint=endpoint, insecure=True),
            max_queue_size=2048,
            schedule_delay_millis=5000,
            max_export_batch_size=512,
        )
    )
    trace.set_tracer_provider(provider)

    # Interop with both W3C and B3 — common in polyglot stacks (Istio, Envoy, Zipkin peers).
    set_global_textmap(
        CompositePropagator(
            [TraceContextTextMapPropagator(), B3MultiFormat()],
        )
    )

    # The FastAPI instrumentation hooks into the ASGI middleware; it must run
    # before ``FastAPI()`` is called, so init_telemetry() has to live at the
    # TOP of app/main.py (before `app = FastAPI(...)`).
    FastAPIInstrumentor().instrument(
        excluded_urls="/healthz,/metrics",
        tracer_provider=provider,
    )

    _INITIALIZED = True
    logger.info(
        "OTel initialized: service=%s endpoint=%s ratio=%s env=%s",
        svc, endpoint, sampling_ratio, env,
    )


__all__ = ["init_telemetry"]
