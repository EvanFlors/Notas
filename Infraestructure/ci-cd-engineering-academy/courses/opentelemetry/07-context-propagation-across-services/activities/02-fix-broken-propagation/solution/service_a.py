"""Service A (solution): inject AFTER opening the span so the carrier
contains that span as the current context (otherwise there is no traceparent
to serialize)."""
import os
import sys
import urllib.request

from opentelemetry import trace
from opentelemetry.propagate import inject
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import ConsoleSpanExporter, SimpleSpanProcessor
from opentelemetry.trace import SpanKind

provider = TracerProvider(resource=Resource.create({"service.name": "service-a"}))
provider.add_span_processor(SimpleSpanProcessor(ConsoleSpanExporter(out=sys.stdout)))
trace.set_tracer_provider(provider)
tracer = trace.get_tracer(__name__)

URL = os.environ.get("B_URL", "http://127.0.0.1:8820/")

with tracer.start_as_current_span("A.handle", kind=SpanKind.CLIENT):
    headers: dict[str, str] = {}
    inject(headers)                        # FIX: moved INSIDE the span
    req = urllib.request.Request(URL, headers=headers)
    with urllib.request.urlopen(req, timeout=5) as resp:
        print("status:", resp.status)
