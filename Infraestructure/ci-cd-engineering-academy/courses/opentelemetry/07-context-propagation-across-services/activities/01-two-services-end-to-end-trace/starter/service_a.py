"""Service A — issues an HTTP call to Service B.

TODO: inject the current OTel context into the headers dict so that
      service B can extract it and continue the same trace.
"""
import os
import sys
import urllib.request

from opentelemetry import trace
from opentelemetry.propagate import inject  # noqa: F401  (use me!)
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import ConsoleSpanExporter, SimpleSpanProcessor
from opentelemetry.trace import SpanKind

provider = TracerProvider(resource=Resource.create({"service.name": "service-a"}))
provider.add_span_processor(SimpleSpanProcessor(ConsoleSpanExporter(out=sys.stdout)))
trace.set_tracer_provider(provider)
tracer = trace.get_tracer(__name__)

URL = os.environ.get("B_URL", "http://127.0.0.1:8810/")

with tracer.start_as_current_span("A.handle", kind=SpanKind.CLIENT):
    headers: dict[str, str] = {}
    # TODO: inject(headers)   <-- uncomment / add this line
    req = urllib.request.Request(URL, headers=headers)
    with urllib.request.urlopen(req, timeout=5) as resp:
        print("status:", resp.status)
