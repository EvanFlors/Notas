#!/usr/bin/env bash
# Print two span-shaped JSON documents, one with current semconv HTTP v1 and
# one with the deprecated (pre-v1.23) names.
# SKIP if python3 is missing.
set -eu

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3 not found in PATH" >&2
  exit 0
fi

python3 - <<'PY'
import json

resource = {
    "service.name": "orders-api",
    "service.version": "1.4.2",
    "service.instance.id": "orders-api-abc123",
    "deployment.environment": "production",
    "host.name": "node-7",
    "host.arch": "amd64",
    "os.type": "linux",
    "k8s.pod.name": "orders-api-abc123",
    "k8s.namespace.name": "checkout",
    "k8s.deployment.name": "orders-api",
    "telemetry.sdk.name": "opentelemetry",
    "telemetry.sdk.language": "python",
    "telemetry.sdk.version": "1.26.0",
}

span_current = {
    "name": "POST /orders",
    "kind": "SERVER",
    "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
    "span_id": "00f067aa0ba902b7",
    "attributes": {
        "http.request.method": "POST",
        "http.response.status_code": 201,
        "url.full": "https://api.acme.com/orders",
        "url.path": "/orders",
        "url.scheme": "https",
        "server.address": "api.acme.com",
        "server.port": 443,
        "network.protocol.name": "http",
        "network.protocol.version": "1.1",
    },
}

span_deprecated = {
    "name": "POST /orders",
    "kind": "SERVER",
    "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
    "span_id": "00f067aa0ba902b7",
    "attributes": {
        "http.method": "POST",                 # DEPRECATED -> http.request.method
        "http.status_code": 201,               # DEPRECATED -> http.response.status_code
        "http.url": "https://api.acme.com/orders",  # DEPRECATED -> url.full
        "http.target": "/orders",              # DEPRECATED -> url.path
        "http.scheme": "https",                # DEPRECATED -> url.scheme
        "http.host": "api.acme.com",           # DEPRECATED -> server.address
        "http.flavor": "1.1",                  # DEPRECATED -> network.protocol.version
    },
}

DEPRECATED = {
    "http.method", "http.status_code", "http.url", "http.target",
    "http.scheme", "http.host", "http.flavor",
}

print("== Resource (one per process) ==")
print(json.dumps(resource, indent=2))

print()
print("== Span (CURRENT HTTP semconv v1) ==")
print(json.dumps(span_current, indent=2))

print()
print("== Span (DEPRECATED HTTP semconv, pre v1.23) ==")
print(json.dumps(span_deprecated, indent=2))

print()
print("== Deprecated attributes present in the second span ==")
for k in span_deprecated["attributes"]:
    if k in DEPRECATED:
        print(f"  - {k}  <-- rename on migration")
PY
