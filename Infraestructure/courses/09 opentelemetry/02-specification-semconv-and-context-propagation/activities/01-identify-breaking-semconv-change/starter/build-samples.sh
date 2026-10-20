#!/usr/bin/env bash
# Generate three sample spans (service-a, service-b, service-c) emitted by
# three different OTel SDK versions with mixed HTTP semconv.
# Output: /tmp/otel-02-01-samples/
set -eu

OUT="${OUT_DIR:-/tmp/otel-02-01-samples}"
rm -rf "$OUT"
mkdir -p "$OUT"

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3 not found in PATH" >&2
  exit 0
fi

python3 - "$OUT" <<'PY'
import json, sys, pathlib

out = pathlib.Path(sys.argv[1])

# Service A: OLD semconv (pre v1.23). SDK too old.
service_a = {
    "service_sdk_version": "1.15.0 (old)",
    "span": {
        "name": "GET /users",
        "attributes": {
            "http.method": "GET",
            "http.status_code": 200,
            "http.url": "https://api.acme.com/users/42",
            "http.target": "/users/42",
            "http.host": "api.acme.com",
            "http.flavor": "1.1",
        },
    },
}

# Service B: NEW semconv (v1.23+). SDK upgraded, all stable.
service_b = {
    "service_sdk_version": "1.26.0 (new)",
    "span": {
        "name": "GET /orders",
        "attributes": {
            "http.request.method": "GET",
            "http.response.status_code": 200,
            "url.full": "https://api.acme.com/orders/7",
            "url.path": "/orders/7",
            "url.scheme": "https",
            "server.address": "api.acme.com",
            "server.port": 443,
            "network.protocol.version": "1.1",
        },
    },
}

# Service C: MIXED (dual-emit flag active or partial upgrade). Both old and new.
service_c = {
    "service_sdk_version": "1.21.0 (transitional, OTEL_SEMCONV_STABILITY_OPT_IN=http/dup)",
    "span": {
        "name": "POST /payments",
        "attributes": {
            # Old names still present
            "http.method": "POST",
            "http.status_code": 201,
            "http.url": "https://api.acme.com/payments",
            # New names also present
            "http.request.method": "POST",
            "http.response.status_code": 201,
            "url.full": "https://api.acme.com/payments",
            "url.path": "/payments",
            "server.address": "api.acme.com",
        },
    },
}

(out / "service-a.json").write_text(json.dumps(service_a, indent=2) + "\n")
(out / "service-b.json").write_text(json.dumps(service_b, indent=2) + "\n")
(out / "service-c.json").write_text(json.dumps(service_c, indent=2) + "\n")

answer = out / "answer.md"
if not answer.exists():
    answer.write_text(
        "# My answer\n\n"
        "## A) Classification per service\n\n"
        "- service-a: ...\n"
        "- service-b: ...\n"
        "- service-c: ...\n\n"
        "## B) Which is old / new / mixed\n\n"
        "...\n\n"
        "## C) Deprecated -> current renames detected\n\n"
        "- http.method -> http.request.method\n"
        "- ...\n\n"
        "## D) Migration plan (4 steps, include dual-emit and cutoff)\n\n"
        "1. ...\n2. ...\n3. ...\n4. ...\n"
    )

print(f"Samples written under {out}")
print("Files:")
for p in sorted(out.iterdir()):
    print(f"  {p.name}")
PY
