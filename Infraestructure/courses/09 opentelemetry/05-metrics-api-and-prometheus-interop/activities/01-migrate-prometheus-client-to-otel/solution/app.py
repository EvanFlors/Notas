"""Solution: same Flask service, migrated to OpenTelemetry Metrics API.

Keeps /metrics scrape-able via PrometheusMetricReader. Temporality is CUMULATIVE
by default (what Prometheus expects). Attribute names follow HTTP semconv.
"""

from __future__ import annotations

import os
import time

from flask import Flask, jsonify, request
from opentelemetry import metrics
from opentelemetry.exporter.prometheus import PrometheusMetricReader
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.resources import Resource
from prometheus_client import start_http_server

app = Flask(__name__)

# --- OTel metrics setup -------------------------------------------------------
reader = PrometheusMetricReader()
provider = MeterProvider(
    metric_readers=[reader],
    resource=Resource.create({"service.name": "flask-otel-demo"}),
)
metrics.set_meter_provider(provider)

meter = metrics.get_meter("flask.app", "1.0.0")

REQUESTS = meter.create_counter(
    "http.server.requests",
    unit="1",
    description="Count of HTTP requests served",
)
DURATION = meter.create_histogram(
    "http.server.request.duration",
    unit="s",
    description="HTTP request duration (seconds)",
)
# -----------------------------------------------------------------------------


@app.before_request
def _start_timer() -> None:
    request._start = time.monotonic()  # type: ignore[attr-defined]


@app.after_request
def _record(response):
    elapsed = time.monotonic() - getattr(request, "_start", time.monotonic())
    route = (request.url_rule.rule if request.url_rule else request.path)
    attrs = {
        "http.request.method": request.method,
        "http.route": route,
        "http.response.status_code": response.status_code,
    }
    REQUESTS.add(1, attrs)
    DURATION.record(elapsed, {"http.request.method": request.method,
                              "http.route": route})
    return response


@app.route("/hello")
def hello():
    return jsonify(ok=True)


@app.route("/slow")
def slow():
    time.sleep(0.05)
    return jsonify(ok=True)


def main() -> None:
    port_metrics = int(os.environ.get("METRICS_PORT", "9464"))
    port_app = int(os.environ.get("APP_PORT", "8080"))
    # PrometheusMetricReader writes to prometheus_client's global REGISTRY,
    # so start_http_server() exposes /metrics with the OTel metrics inside.
    start_http_server(port_metrics)
    app.run(host="127.0.0.1", port=port_app, debug=False, use_reloader=False)


if __name__ == "__main__":
    main()
