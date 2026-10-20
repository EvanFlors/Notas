"""Minimal batch job suitable for Cloud Run jobs.

Reads env vars (BATCH_SIZE) and simulates processing. Exits 0 on success.
"""
from __future__ import annotations

import os
import time


def process_item(index: int) -> None:
    # Placeholder for real work (DB migration, reencoding, etc.).
    time.sleep(0.01)
    _ = index


def main() -> int:
    size = int(os.environ.get("BATCH_SIZE", "10"))
    start = time.perf_counter()
    for i in range(size):
        process_item(i)
    elapsed = time.perf_counter() - start
    print(f"[job] processed {size} items in {elapsed:.2f}s")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
