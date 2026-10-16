#!/usr/bin/env bash
# Encode/decode W3C Baggage with stdlib and measure per-hop overhead.
# SKIP if python3 is missing.
set -eu

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3 not found in PATH" >&2
  exit 0
fi

python3 - <<'PY'
from urllib.parse import quote, unquote

def encode(d: dict) -> str:
    return ",".join(f"{quote(k, safe='')}={quote(v, safe='')}" for k, v in d.items())

def decode(header: str) -> dict:
    out = {}
    for pair in header.split(","):
        pair = pair.strip()
        if not pair:
            continue
        # Allow optional ";metadata" tail per W3C; keep value only.
        kv, _, _meta = pair.partition(";")
        k, _, v = kv.partition("=")
        out[unquote(k.strip())] = unquote(v.strip())
    return out

print("== encode ==")
sample = {"userId": "u-123", "tenant": "acme", "experiment": "checkout-v2"}
header = encode(sample)
print(sample)
print(f"baggage: {header}")
print(f"bytes: {len(header)}")

print()
print("== decode ==")
h = "userId=u-123,tenant=acme,experiment=checkout-v2"
print(f"header: {h}")
print(f"dict: {decode(h)}")

print()
print("== overhead per hop ==")
for n in (1, 5, 20):
    d = {f"k{i}": f"v{i:04d}" for i in range(n)}
    hdr = encode(d)
    hops = 10
    print(f"{n:2d} keys -> {len(hdr):4d} bytes/header -> {hops} hops = {len(hdr)*hops:5d} bytes/request")

print()
print("== DO NOT put in Baggage ==")
for item in [
    "email, ssn, token (PII / secrets)",
    "request_id (high cardinality, use trace_id instead)",
    "timestamps (change every hop)",
    "stack traces or any payload (headers have hard limits)",
]:
    print(f"  - {item}")
PY
