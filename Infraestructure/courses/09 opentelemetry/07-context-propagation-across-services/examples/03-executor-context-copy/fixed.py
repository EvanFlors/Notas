"""FIXED: copy the caller's context into the worker with contextvars.copy_context()."""
import contextvars
from concurrent.futures import ThreadPoolExecutor

from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import ConsoleSpanExporter, SimpleSpanProcessor

provider = TracerProvider(resource=Resource.create({"service.name": "fixed-executor"}))
provider.add_span_processor(SimpleSpanProcessor(ConsoleSpanExporter()))
trace.set_tracer_provider(provider)
tracer = trace.get_tracer(__name__)


def do_work():
    with tracer.start_as_current_span("worker.step"):
        pass


with tracer.start_as_current_span("main.parent"):
    ctx = contextvars.copy_context()                 # snapshot current context
    with ThreadPoolExecutor(max_workers=1) as ex:
        ex.submit(ctx.run, do_work).result()         # run do_work inside that context
