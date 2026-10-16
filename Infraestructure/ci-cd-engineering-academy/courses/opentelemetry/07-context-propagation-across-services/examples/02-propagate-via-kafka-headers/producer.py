"""Producer: inject current context into fake Kafka headers, write to a file queue."""
import json
import pathlib
import sys

from opentelemetry import trace
from opentelemetry.propagate import inject
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import ConsoleSpanExporter, SimpleSpanProcessor
from opentelemetry.trace import SpanKind

QUEUE_FILE = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/otel07-ex02-queue.jsonl")

provider = TracerProvider(resource=Resource.create({"service.name": "producer"}))
provider.add_span_processor(SimpleSpanProcessor(ConsoleSpanExporter()))
trace.set_tracer_provider(provider)
tracer = trace.get_tracer(__name__)

with tracer.start_as_current_span("publish order", kind=SpanKind.PRODUCER):
    headers: dict[str, str] = {}
    inject(headers)                           # serialize current context
    message = {"headers": headers, "value": {"order_id": "A-123"}}
    QUEUE_FILE.write_text(json.dumps(message) + "\n")
    print(f"published to {QUEUE_FILE}: headers={headers}")
