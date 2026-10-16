"""Consumer: extract context from fake Kafka headers and continue the trace."""
import json
import pathlib
import sys

from opentelemetry import trace
from opentelemetry.propagate import extract
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import ConsoleSpanExporter, SimpleSpanProcessor
from opentelemetry.trace import SpanKind

QUEUE_FILE = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/otel07-ex02-queue.jsonl")

provider = TracerProvider(resource=Resource.create({"service.name": "consumer"}))
provider.add_span_processor(SimpleSpanProcessor(ConsoleSpanExporter()))
trace.set_tracer_provider(provider)
tracer = trace.get_tracer(__name__)

data = json.loads(QUEUE_FILE.read_text().splitlines()[0])
carrier = data["headers"]
ctx = extract(carrier)                        # reconstruct remote context

with tracer.start_as_current_span("process order", context=ctx, kind=SpanKind.CONSUMER) as span:
    span.set_attribute("order.id", data["value"]["order_id"])
    print("processed:", data["value"])
