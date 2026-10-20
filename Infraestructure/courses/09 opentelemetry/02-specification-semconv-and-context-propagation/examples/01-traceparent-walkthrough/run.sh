#!/usr/bin/env bash
# Decode a W3C traceparent header using Python stdlib only.
# Usage: bash run.sh [TRACEPARENT]
# SKIP if python3 is missing.
set -eu

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3 not found in PATH" >&2
  exit 0
fi

HEADER="${1:-00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01}"

python3 - "$HEADER" <<'PY'
import re, sys

header = sys.argv[1]
print("== traceparent decoder ==")
print(f"header: {header}")
print(f"length: {len(header)} chars (expected 55)")

if len(header) != 55:
    print("ERROR: traceparent must be exactly 55 chars", file=sys.stderr)
    sys.exit(1)

parts = header.split("-")
if len(parts) != 4:
    print(f"ERROR: expected 4 dash-separated fields, got {len(parts)}", file=sys.stderr)
    sys.exit(1)

version, trace_id, span_id, flags = parts

def hex_of(label, value, nchars):
    if len(value) != nchars:
        print(f"ERROR: {label} must be {nchars} hex chars, got {len(value)}", file=sys.stderr)
        sys.exit(1)
    if not re.fullmatch(r"[0-9a-f]+", value):
        print(f"ERROR: {label} must be lowercase hex", file=sys.stderr)
        sys.exit(1)

hex_of("version", version, 2)
hex_of("trace_id", trace_id, 32)
hex_of("span_id", span_id, 16)
hex_of("flags", flags, 2)

if trace_id == "0" * 32:
    print("ERROR: trace_id must be non-zero", file=sys.stderr)
    sys.exit(1)
if span_id == "0" * 16:
    print("ERROR: span_id must be non-zero", file=sys.stderr)
    sys.exit(1)

flag_byte = int(flags, 16)
sampled = bool(flag_byte & 0x01)

print(f"version   : {version}  (W3C v1)")
print(f"trace_id  : {trace_id}  (128 bits)")
print(f"span_id   : {span_id}  (64 bits -- parent span of the next hop)")
print(f"flags     : {flags}  -> sampled={sampled}")

print()
print("Interpretation:")
print(f"  * The receiving service will create spans with trace_id={trace_id}.")
print(f"  * Those spans will have parent_span_id={span_id}.")
print(f"  * sampled={sampled}: the receiver should respect this decision.")
PY
