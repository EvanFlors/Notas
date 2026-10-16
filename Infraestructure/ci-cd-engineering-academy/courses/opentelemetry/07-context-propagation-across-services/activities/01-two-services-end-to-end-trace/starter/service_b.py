"""Service B — stdlib HTTP server. Extracts incoming context and opens a child span.

Do NOT modify this file for the activity: the fix lives in service_a.py.
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
        # Headers are case-insensitive; the propagator looks up by lowercase keys.
        carrier = {k.lower(): v for k, v in self.headers.items()}
        ctx = extract(carrier)
        with tracer.start_as_current_span("B.handle", context=ctx, kind=SpanKind.SERVER):
            self.send_response(200)
            self.send_header("content-type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"ok": true}')

    def log_message(self, *a, **kw):  # silence default access log
        pass


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8810"))
    HTTPServer(("127.0.0.1", port), Handler).serve_forever()
