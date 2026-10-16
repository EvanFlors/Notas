#!/usr/bin/env python3
"""Compute the 4 DORA metrics from a synthetic CI/CD event stream.

Reads a JSON file whose top-level is a list of events. Three event types
are recognized:

    {"type": "commit_merged", "service": "...", "sha": "...",
     "merged_at": "<ISO8601 UTC>"}

    {"type": "deploy", "service": "...", "id": "...", "env": "prod",
     "commit_sha": "...", "started_at": "...", "finished_at": "...",
     "status": "success" | "failure"}

    {"type": "incident", "service": "...", "caused_by_deploy_id": "...",
     "started_at": "...", "resolved_at": "..."}

Usage:
    python3 compute_dora.py <events.json> [--service <name>] [--window-days <N>]

Pure stdlib. No external dependencies. Prints a human-readable report
and exits 0 on success.
"""
from __future__ import annotations

import argparse
import json
import statistics
import sys
from datetime import datetime, timezone
from pathlib import Path


def parse_iso(ts: str) -> datetime:
    # Accept trailing Z or explicit offset.
    if ts.endswith("Z"):
        ts = ts[:-1] + "+00:00"
    dt = datetime.fromisoformat(ts)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


def classify_bucket(df_per_day: float, lead_hours: float,
                    cfr: float, fdrt_hours: float) -> str:
    """Rough mapping to DORA buckets (recent report). Thresholds are illustrative."""
    if df_per_day >= 1 and lead_hours <= 24 and cfr <= 0.15 and fdrt_hours <= 1:
        return "ELITE"
    if df_per_day >= 1 / 7 and lead_hours <= 24 * 7 and cfr <= 0.15 and fdrt_hours <= 24:
        return "HIGH"
    if df_per_day >= 1 / 30 and lead_hours <= 24 * 30 and cfr <= 0.30 and fdrt_hours <= 24 * 7:
        return "MEDIUM"
    return "LOW"


def human_hours(hours: float) -> str:
    if hours < 1:
        return f"{int(round(hours * 60))} min"
    if hours < 24:
        return f"{hours:.1f} h"
    return f"{hours / 24:.1f} d"


def compute(events: list[dict], service: str | None, window_days: int) -> dict:
    # Filter by service if requested.
    if service:
        events = [e for e in events if e.get("service") == service]

    commits = {e["sha"]: parse_iso(e["merged_at"])
               for e in events if e["type"] == "commit_merged"}
    deploys = [e for e in events if e["type"] == "deploy"]
    incidents = [e for e in events if e["type"] == "incident"]

    successful = [d for d in deploys if d.get("status") == "success"
                  and d.get("env") == "prod"]
    n_success = len(successful)
    df = n_success / window_days if window_days else 0.0

    # Lead time: deploy.finished_at - commit.merged_at
    leads_sec: list[float] = []
    for d in successful:
        sha = d.get("commit_sha")
        if sha in commits:
            delta = (parse_iso(d["finished_at"]) - commits[sha]).total_seconds()
            if delta >= 0:
                leads_sec.append(delta)
    lead_hours = statistics.median(leads_sec) / 3600 if leads_sec else 0.0

    # CFR: fraction of successful deploys that caused an incident.
    failed_ids = {i["caused_by_deploy_id"] for i in incidents
                  if i.get("caused_by_deploy_id")}
    deploys_that_failed = sum(1 for d in successful if d["id"] in failed_ids)
    cfr = deploys_that_failed / n_success if n_success else 0.0

    # FDRT: median recovery time of incidents caused by a deploy.
    recoveries_sec: list[float] = []
    for i in incidents:
        if not i.get("caused_by_deploy_id"):
            continue
        delta = (parse_iso(i["resolved_at"]) - parse_iso(i["started_at"])).total_seconds()
        if delta >= 0:
            recoveries_sec.append(delta)
    fdrt_hours = statistics.median(recoveries_sec) / 3600 if recoveries_sec else 0.0

    bucket = classify_bucket(df, lead_hours, cfr, fdrt_hours)

    return {
        "service": service or "(all)",
        "window_days": window_days,
        "deployments_success": n_success,
        "deployments_total": len(deploys),
        "incidents_from_deploy": len(recoveries_sec),
        "deployment_frequency_per_day": round(df, 3),
        "lead_time_hours_median": round(lead_hours, 2),
        "change_failure_rate": round(cfr, 4),
        "failed_deploy_recovery_hours_median": round(fdrt_hours, 2),
        "bucket": bucket,
    }


def render(report: dict) -> str:
    lines = [
        f"== DORA (service={report['service']}, window={report['window_days']}d) ==",
        f"  Deployment Frequency      : ~{report['deployment_frequency_per_day']:.2f}"
        f" deploys/day  ({report['deployments_success']} successful deploys"
        f" in {report['window_days']} days)",
        f"  Lead Time for Changes     : {human_hours(report['lead_time_hours_median'])} (median)",
        f"  Change Failure Rate       : {report['change_failure_rate'] * 100:.2f} %"
        f"  ({report['incidents_from_deploy']} of {report['deployments_success']}"
        f" deploys caused incidents)",
        f"  Failed Deploy Recovery T. : "
        f"{human_hours(report['failed_deploy_recovery_hours_median'])} (median)",
        f"  --> Bucket (reporte reciente): {report['bucket']}",
    ]
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("events_file", help="path to events.json")
    ap.add_argument("--service", default=None, help="filter by service name")
    ap.add_argument("--window-days", type=int, default=28,
                    help="rolling window in days (default: 28)")
    ap.add_argument("--json", action="store_true", help="emit JSON instead of text")
    args = ap.parse_args()

    path = Path(args.events_file)
    if not path.exists():
        print(f"ERROR: {path} not found", file=sys.stderr)
        return 2

    try:
        events = json.loads(path.read_text())
    except json.JSONDecodeError as exc:
        print(f"ERROR: invalid JSON in {path}: {exc}", file=sys.stderr)
        return 2

    report = compute(events, args.service, args.window_days)

    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print(render(report))
    return 0


if __name__ == "__main__":
    sys.exit(main())
