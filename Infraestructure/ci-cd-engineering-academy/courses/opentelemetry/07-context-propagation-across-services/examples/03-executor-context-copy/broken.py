"""BROKEN: ThreadPoolExecutor does not copy the parent context by default."""
from concurrent.futures import ThreadPoolExecutor

from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import ConsoleSpanExporter, SimpleSpanProcessor

provider = TracerProvider(resource=Resource.create({"service.name": "broken-executor"}))
provider.add_span_processor(SimpleSpanProcessor(ConsoleSpanExporter()))
trace.set_tracer_provider(provider)
tracer = trace.get_tracer(__name__)


def do_work():
    with tracer.start_as_current_span("worker.step"):
        pass


with tracer.start_as_current_span("main.parent"):
    with ThreadPoolExecutor(max_workers=1) as ex:
        ex.submit(do_work).result()
