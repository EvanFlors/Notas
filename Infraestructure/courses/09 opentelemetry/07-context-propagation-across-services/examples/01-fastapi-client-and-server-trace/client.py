"""Service A — issues one HTTP call to Service B."""
import sys
import httpx
from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import ConsoleSpanExporter, SimpleSpanProcessor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor

provider = TracerProvider(resource=Resource.create({"service.name": "service-a"}))
provider.add_span_processor(SimpleSpanProcessor(ConsoleSpanExporter()))
trace.set_tracer_provider(provider)

HTTPXClientInstrumentor().instrument()
tracer = trace.get_tracer(__name__)

url = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8801/compute?x=7"

with tracer.start_as_current_span("A.handle_request"):
    with httpx.Client() as c:
        r = c.get(url)
    print("response:", r.json())
