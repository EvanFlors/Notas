"""Service B — FastAPI server instrumented with OTel."""
from fastapi import FastAPI
from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import ConsoleSpanExporter, SimpleSpanProcessor
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

provider = TracerProvider(resource=Resource.create({"service.name": "service-b"}))
provider.add_span_processor(SimpleSpanProcessor(ConsoleSpanExporter()))
trace.set_tracer_provider(provider)

app = FastAPI()
FastAPIInstrumentor.instrument_app(app)
tracer = trace.get_tracer(__name__)


@app.get("/compute")
def compute(x: int = 1):
    with tracer.start_as_current_span("compute.square"):
        return {"result": x * x}
