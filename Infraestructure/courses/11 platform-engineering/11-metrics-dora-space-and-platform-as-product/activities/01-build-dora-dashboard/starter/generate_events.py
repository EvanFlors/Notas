#!/usr/bin/env python3
"""Generate a deterministic synthetic CI/CD event stream for 2 services.

The two services have very different performance profiles:

    checkout-api   : HIGH performer  (~24 deploys / 28 d, lead ~4 h, CFR ~12 %, FDRT ~40 min)
    legacy-billing : LOW  performer  (~3 deploys / 28 d, lead ~5 d, CFR ~33 %, FDRT ~6 h)

The output JSON is a flat list sorted by event time. See examples/01 for
the expected event schema. Pure stdlib.

Usage:
    python3 generate_events.py --out events.json [--window-days 28] [--seed 42]
"""
from __future__ import annotations

import argparse
import json
import random
from datetime import datetime, timedelta, timezone
from pathlib import Path


def gen_service(service: str, start: datetime, window_days: int,
                n_deploys: int, lead_hours_pool: list[float],
                incident_count: int, recovery_min_pool: list[int],
                rng: random.Random) -> list[dict]:
    """Generate commit_merged + deploy + incident events for one service."""
    events: list[dict] = []
    deploy_times: list[tuple[str, datetime]] = []

    # Spread deploys across the window.
    total_hours = window_days * 24
    offsets = sorted(rng.sample(range(total_hours), n_deploys))

    for i, hour_off in enumerate(offsets, start=1):
        sha = f"{service[:3]}{i:04x}"
        commit_time = start + timedelta(hours=hour_off, minutes=rng.randint(0, 59))
        lead_h = rng.choice(lead_hours_pool)
        deploy_start = commit_time + timedelta(hours=lead_h - 0.1)
        deploy_finish = commit_time + timedelta(hours=lead_h)
        did = f"{service}-d-{i:03d}"
        events.append({"type": "commit_merged", "service": service, "sha": sha,
                       "merged_at": commit_time.isoformat().replace("+00:00", "Z")})
        events.append({"type": "deploy", "service": service, "id": did, "env": "prod",
                       "commit_sha": sha,
                       "started_at": deploy_start.isoformat().replace("+00:00", "Z"),
                       "finished_at": deploy_finish.isoformat().replace("+00:00", "Z"),
                       "status": "success"})
        deploy_times.append((did, deploy_finish))

    # Pick which deploys caused an incident.
    k = min(incident_count, len(deploy_times))
    affected = rng.sample(range(len(deploy_times)), k)
    for idx, rm in zip(sorted(affected), recovery_min_pool[:k]):
        did, dfin = deploy_times[idx]
        inc_start = dfin + timedelta(minutes=rng.randint(3, 15))
        inc_end = inc_start + timedelta(minutes=rm)
        events.append({"type": "incident", "service": service,
                       "caused_by_deploy_id": did,
                       "started_at": inc_start.isoformat().replace("+00:00", "Z"),
                       "resolved_at": inc_end.isoformat().replace("+00:00", "Z")})

    return events


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="events.json", help="output path")
    ap.add_argument("--window-days", type=int, default=28)
    ap.add_argument("--seed", type=int, default=42)
    args = ap.parse_args()

    rng = random.Random(args.seed)
    start = datetime(2026, 9, 15, 9, 0, tzinfo=timezone.utc)

    events: list[dict] = []
    # HIGH performer.
    events += gen_service(
        service="checkout-api",
        start=start,
        window_days=args.window_days,
        n_deploys=24,
        lead_hours_pool=[2.0, 3.0, 3.5, 4.0, 4.5, 4.5, 5.0, 6.0, 7.5],
        incident_count=3,
        recovery_min_pool=[25, 42, 75],
        rng=rng,
    )
    # LOW performer.
    events += gen_service(
        service="legacy-billing",
        start=start,
        window_days=args.window_days,
        n_deploys=3,
        lead_hours_pool=[96.0, 120.0, 168.0],  # 4-7 days
        incident_count=1,
        recovery_min_pool=[360],  # 6 h
        rng=rng,
    )

    events.sort(key=lambda e: e.get("merged_at") or e.get("started_at"))

    out = Path(args.out)
    out.write_text(json.dumps(events, indent=2))
    print(f"wrote {len(events)} events to {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
