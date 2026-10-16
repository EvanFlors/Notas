#!/usr/bin/env python3
"""Compute monthly observability bill from a profile + prices.

Usage:
    python3 bill.py profile.yaml prices.yaml

Prints a per-service table + totals + top-3 contributors.
Fails if required governance labels (team, env, tier) are missing on any service.
"""

from __future__ import annotations

import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML required. pip install pyyaml", file=sys.stderr)
    sys.exit(2)

REQUIRED_LABELS = ("team", "env", "tier")
ALLOWED_TIERS = {"gold", "silver", "bronze"}


def cost_for_service(svc: dict, prices: dict, month_days: int) -> dict:
    tier = svc["tier"]
    metrics = (svc.get("active_series", 0) / 1000.0) * prices[
        "metrics_price_per_1k_series_month"
    ][tier]
    logs = (
        svc.get("log_gb_day", 0.0)
        * month_days
        * prices["logs_price_per_gb_ingested"][tier]
    )
    spans_month = (
        svc.get("spans_per_sec", 0) * 86400 * month_days * svc.get("sampling", 1.0)
    )
    traces = (spans_month / 1_000_000.0) * prices["traces_price_per_1m_spans"]
    total = metrics + logs + traces
    return {
        "metrics": metrics,
        "logs": logs,
        "traces": traces,
        "total": total,
    }


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print("Usage: bill.py <profile.yaml> <prices.yaml>", file=sys.stderr)
        return 2
    profile = yaml.safe_load(Path(argv[1]).read_text())
    prices = yaml.safe_load(Path(argv[2]).read_text())

    month_days = profile.get("month_days", 30)
    services = profile.get("services", [])
    if not services:
        print("ERROR: profile has no services.", file=sys.stderr)
        return 2

    # Governance check.
    issues = []
    for svc in services:
        name = svc.get("name", "<unnamed>")
        for key in REQUIRED_LABELS:
            if not svc.get(key):
                issues.append(f"service '{name}' missing required label '{key}'")
        if svc.get("tier") not in ALLOWED_TIERS:
            issues.append(
                f"service '{name}' has invalid tier '{svc.get('tier')}' "
                f"(allowed: {sorted(ALLOWED_TIERS)})"
            )
    if issues:
        for issue in issues:
            print(f"GOVERNANCE: {issue}", file=sys.stderr)
        return 1

    totals = {"metrics": 0.0, "logs": 0.0, "traces": 0.0}
    rows = []
    for svc in services:
        c = cost_for_service(svc, prices, month_days)
        rows.append((svc["name"], svc["team"], svc["tier"], c))
        for k in totals:
            totals[k] += c[k]

    egress_cost = profile.get("egress_gb_month", 0) * prices["egress_price_per_gb"]
    grand_total = sum(totals.values()) + egress_cost

    print(f"{'service':<18} {'team':<10} {'tier':<8} "
          f"{'metrics':>10} {'logs':>10} {'traces':>10} {'total':>10}")
    print("-" * 80)
    for name, team, tier, c in rows:
        print(f"{name:<18} {team:<10} {tier:<8} "
              f"${c['metrics']:>9.2f} ${c['logs']:>9.2f} "
              f"${c['traces']:>9.2f} ${c['total']:>9.2f}")
    print("-" * 80)
    print(f"{'TOTAL':<18} {'':<10} {'':<8} "
          f"${totals['metrics']:>9.2f} ${totals['logs']:>9.2f} "
          f"${totals['traces']:>9.2f} ${sum(totals.values()):>9.2f}")
    print(f"Egress: ${egress_cost:.2f}")
    print(f"GRAND TOTAL (month): ${grand_total:.2f}")

    # Top-3 contributors.
    top = sorted(rows, key=lambda r: r[3]["total"], reverse=True)[:3]
    print("\nTop-3 by total cost:")
    for name, team, tier, c in top:
        print(f"  {name} ({team}/{tier}): ${c['total']:.2f} "
              f"[metrics ${c['metrics']:.2f}, logs ${c['logs']:.2f}, "
              f"traces ${c['traces']:.2f}]")

    print("\nOK — bill computed")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
