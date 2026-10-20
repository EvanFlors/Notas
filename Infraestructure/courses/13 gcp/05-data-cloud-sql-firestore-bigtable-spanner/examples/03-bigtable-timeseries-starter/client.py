"""Bigtable time-series starter against the official emulator.

Row key pattern: metric#device#<reverse_ts>
  - metric#device prefix spreads writes across tablets per device
  - reverse_ts turns 'last N points' into a cheap ascending prefix scan

Requires:
  BIGTABLE_EMULATOR_HOST=localhost:8086
  GOOGLE_CLOUD_PROJECT=example-project-id
"""
from __future__ import annotations

import os
import sys
import time

from google.cloud import bigtable
from google.cloud.bigtable import column_family


PROJECT = os.environ.get("GOOGLE_CLOUD_PROJECT", "example-project-id")
INSTANCE_ID = "metrics-instance"
TABLE_ID = "metrics"
CF = "v"
MAX_INT64 = (1 << 63) - 1


def reverse_ts(ts_micros: int) -> int:
    return MAX_INT64 - ts_micros


def make_key(metric: str, device: str, ts_micros: int) -> bytes:
    return f"{metric}#{device}#{reverse_ts(ts_micros):020d}".encode()


def main() -> int:
    client = bigtable.Client(project=PROJECT, admin=True)
    instance = client.instance(INSTANCE_ID)
    # Emulator does not require an instance to be created; still fine to call.
    table = instance.table(TABLE_ID)

    if not table.exists():
        table.create(column_families={CF: column_family.MaxVersionsGCRule(1)})

    now = int(time.time() * 1_000_000)
    rows = []
    for device in ("device-01", "device-02", "device-03"):
        for i in range(60):
            ts = now - i * 1_000_000  # one point per second
            row = table.direct_row(make_key("cpu", device, ts))
            row.set_cell(CF, b"val", f"{20 + (i % 10)}".encode())
            rows.append(row)
    table.mutate_rows(rows)
    print(f"wrote {len(rows)} points")

    # Read last 10 points for device-01: prefix scan, limit 10
    prefix = b"cpu#device-01#"
    partial = table.read_rows(start_key=prefix, end_key=prefix + b"\xff", limit=10)
    count = 0
    for r in partial:
        cell = r.cells[CF][b"val"][0]
        print(f"  {r.row_key.decode()} -> {cell.value.decode()}")
        count += 1
    print(f"read {count} rows for device-01")
    return 0


if __name__ == "__main__":
    sys.exit(main())
