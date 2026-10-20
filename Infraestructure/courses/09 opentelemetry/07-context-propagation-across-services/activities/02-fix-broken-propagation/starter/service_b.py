"""Service B — stdlib HTTP server. Something about the way the trace continues
here is wrong. Spans will emit, but the parent will not be what you expect.
"""
import os
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

from opentelemetry import trace
from opentelemetry.propagate import extract
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import ConsoleSpanExporter, SimpleSpanProcessor
from opentelemetry.trace import SpanKind

provider = TracerProvider(resource=Resource.create({"service.name": "service-b"}))
provider.add_span_processor(SimpleSpanProcessor(ConsoleSpanExporter(out=sys.stdout)))
trace.set_tracer_provider(provider)
tracer = trace.get_tracer(__name__)


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        carrier = dict(self.headers.items())
        ctx = extract(carrier)
        with tracer.start_as_current_span("B.handle", context=ctx, kind=SpanKind.SERVER):
            self.send_response(200)
            self.send_header("content-type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"ok": true}')

    def log_message(self, *a, **kw):
        pass


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8820"))
    HTTPServer(("127.0.0.1", port), Handler).serve_forever()
