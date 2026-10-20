"""Minimal demo app: logs one JSON line every 2 seconds.

One in ten lines is logged at ERROR level so LogQL filtering is interesting.
"""
import json
import random
import sys
import time
import uuid

LEVELS_WEIGHTED = ["info"] * 7 + ["warn"] * 2 + ["error"] * 1


def emit(level: str) -> None:
    record = {
        "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "level": level,
        "msg": {
            "info": "request handled",
            "warn": "slow request",
            "error": "db timeout",
        }[level],
        "request_id": str(uuid.uuid4()),
        "duration_ms": random.randint(5, 1500),
    }
    print(json.dumps(record), flush=True)


def main() -> None:
    while True:
        level = random.choice(LEVELS_WEIGHTED)
        emit(level)
        time.sleep(2)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
