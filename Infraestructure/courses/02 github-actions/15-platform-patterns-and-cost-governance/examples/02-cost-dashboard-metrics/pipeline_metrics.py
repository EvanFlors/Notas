#!/usr/bin/env python3
"""Compute basic pipeline metrics from a GitHub Actions runs JSON dump.

Input: JSON produced by `gh api /repos/{o}/{r}/actions/runs --paginate` (or a
fixture with the same shape: dict with 'workflow_runs' list, or a bare list).

Outputs: aggregate + per-workflow success rate, p50/p95 duration, approx
runner-minutes cobrables (ubuntu x1, windows x2, macos x10).

Design notes:
- Stdlib only; no dependencies.
- For precise billing use /actions/runs/{id}/timing (see README).
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path

MULTIPLIER = {"ubuntu": 1, "linux": 1, "windows": 2, "macos": 10, "mac": 10}


def _parse_iso(ts: str) -> datetime:
    # GitHub returns Zulu format: 2024-01-02T03:04:05Z
    return datetime.strptime(ts, "%Y-%m-%dT%H:%M:%SZ")


def _duration_minutes(run: dict) -> float:
    started = run.get("run_started_at") or run.get("created_at")
    ended = run.get("updated_at")
    if not started or not ended:
        return 0.0
    dt = (_parse_iso(ended) - _parse_iso(started)).total_seconds() / 60.0
    return max(dt, 0.0)


def _multiplier_from_run(run: dict) -> int:
    # Heuristic: not all run payloads carry the runner OS; default to ubuntu.
    # If the fixture annotates "runner_os" we use it.
    os_hint = (run.get("runner_os") or "ubuntu").lower()
    for key, mult in MULTIPLIER.items():
        if key in os_hint:
            return mult
    return 1


def _percentile(sorted_vals: list[float], p: float) -> float:
    if not sorted_vals:
        return 0.0
    k = (len(sorted_vals) - 1) * p
    f = math.floor(k)
    c = math.ceil(k)
    if f == c:
        return sorted_vals[int(k)]
    return sorted_vals[f] + (sorted_vals[c] - sorted_vals[f]) * (k - f)


def analyze(runs: list[dict]) -> dict:
    per_wf: dict[str, list[dict]] = defaultdict(list)
    for r in runs:
        wf = r.get("path", "").split("/")[-1] or r.get("name") or "unknown"
        per_wf[wf].append(r)

    def summarize(subset: list[dict]) -> dict:
        durations = sorted(_duration_minutes(r) for r in subset)
        n = len(subset)
        n_ok = sum(1 for r in subset if r.get("conclusion") == "success")
        minutes = 0
        for r in subset:
            d = math.ceil(_duration_minutes(r))
            minutes += d * _multiplier_from_run(r)
        return {
            "runs": n,
            "success_rate": (n_ok / n * 100.0) if n else 0.0,
            "p50": round(_percentile(durations, 0.5), 1),
            "p95": round(_percentile(durations, 0.95), 1),
            "minutes": minutes,
        }

    return {
        "overall": summarize(runs),
        "per_workflow": {wf: summarize(items) for wf, items in sorted(per_wf.items())},
    }


def load_runs(path: Path) -> list[dict]:
    data = json.loads(path.read_text())
    if isinstance(data, dict) and "workflow_runs" in data:
        return list(data["workflow_runs"])
    if isinstance(data, list):
        return data
    raise SystemExit(f"Unexpected JSON shape in {path}: expected list or {{workflow_runs:[...]}}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--runs", required=True, type=Path, help="Path to runs JSON")
    ap.add_argument("--json", action="store_true", help="Emit JSON instead of text")
    args = ap.parse_args()

    runs = load_runs(args.runs)
    report = analyze(runs)

    if args.json:
        print(json.dumps(report, indent=2))
        return 0

    o = report["overall"]
    print("== Pipeline metrics ==")
    print(f"runs analyzed:    {o['runs']}")
    print(f"success rate:     {o['success_rate']:.2f}%")
    print(f"duration p50:     {o['p50']} min")
    print(f"duration p95:     {o['p95']} min")
    print(f"runner-minutes:   {o['minutes']}   (approx)")
    print()
    print("== Per workflow ==")
    for wf, s in report["per_workflow"].items():
        print(
            f"{wf:<24} runs={s['runs']} success={s['success_rate']:.0f}% "
            f"p50={s['p50']} p95={s['p95']} minutes={s['minutes']}"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
