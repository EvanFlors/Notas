"""Starter: Flask service instrumented with prometheus_client.

Your task: replace the metrics block below with the OpenTelemetry Metrics API,
keeping /metrics scrape-able with Prometheus-compatible names.
See activity README for details.
"""

from __future__ import annotations

import os
import time

from flask import Flask, jsonify, request
from prometheus_client import Counter, Histogram, start_http_server

app = Flask(__name__)

# --- Replace this block with OTel Metrics API ---------------------------------
REQUESTS = Counter(
    "http_requests_total",
    "Count of HTTP requests served",
    labelnames=["method", "route", "status"],
)
DURATION = Histogram(
    "http_request_duration_seconds",
    "HTTP request duration (seconds)",
    labelnames=["method", "route"],
)
# ------------------------------------------------------------------------------


@app.before_request
def _start_timer() -> None:
    request._start = time.monotonic()  # type: ignore[attr-defined]


@app.after_request
def _record(response):
    elapsed = time.monotonic() - getattr(request, "_start", time.monotonic())
    route = (request.url_rule.rule if request.url_rule else request.path)
    REQUESTS.labels(request.method, route, str(response.status_code)).inc()
    DURATION.labels(request.method, route).observe(elapsed)
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
    start_http_server(port_metrics)  # exposes /metrics on 0.0.0.0:9464/metrics
    app.run(host="127.0.0.1", port=port_app, debug=False, use_reloader=False)


if __name__ == "__main__":
    main()
