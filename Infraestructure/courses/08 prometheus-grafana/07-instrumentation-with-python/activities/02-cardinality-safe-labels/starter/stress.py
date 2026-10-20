"""Fire traffic from many fake users and item ids to inflate cardinality."""

from __future__ import annotations

import os
import sys

import httpx

BASE = os.environ.get("BASE", "http://127.0.0.1:8789")
N_USERS = 50
N_ITEMS = 50


def main() -> int:
    with httpx.Client(timeout=2.0) as client:
        for u in range(N_USERS):
            headers = {"x-user-id": f"user-{u}"}
            for i in range(N_ITEMS):
                client.get(f"{BASE}/items/{i}", headers=headers)
    print(f"sent {N_USERS * N_ITEMS} requests")
    return 0


if __name__ == "__main__":
    sys.exit(main())
