#!/usr/bin/env python3
"""compute_unit_economics.py — FinOps unit economics from synthetic CSVs.

Reads an AWS-cost-style CSV (month,service,cost_usd) and a usage CSV
(month,service,mau,requests), joins them on (month, service), writes
per-row unit economics (cost_per_mau, cost_per_req) to stdout as CSV,
and prints detected anomalies to stderr.

Anomaly rule (per service, over the series of cost_per_req):
    flag any month whose cost_per_req is >= 1.5x the median of that service's
    cost_per_req series. The threshold is intentionally simple and
    documented — this is a teaching script, not a production detector.

Usage:
    python3 compute_unit_economics.py costs.csv usage.csv > unit_economics.csv

No third-party dependencies. Python stdlib only.
"""

from __future__ import annotations

import csv
import statistics
import sys
from collections import defaultdict

ANOMALY_RATIO = 1.5


def load_costs(path: str) -> dict[tuple[str, str], float]:
    out: dict[tuple[str, str], float] = {}
    with open(path, newline="") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            out[(row["month"], row["service"])] = float(row["cost_usd"])
    return out


def load_usage(path: str) -> dict[tuple[str, str], tuple[int, int]]:
    out: dict[tuple[str, str], tuple[int, int]] = {}
    with open(path, newline="") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            out[(row["month"], row["service"])] = (
                int(row["mau"]),
                int(row["requests"]),
            )
    return out


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(
            "usage: compute_unit_economics.py <costs.csv> <usage.csv>",
            file=sys.stderr,
        )
        return 2

    costs = load_costs(argv[1])
    usage = load_usage(argv[2])

    writer = csv.writer(sys.stdout)
    writer.writerow(
        [
            "month",
            "service",
            "cost_usd",
            "mau",
            "requests",
            "cost_per_mau",
            "cost_per_req",
        ]
    )

    # Collect per-service series for anomaly detection.
    per_req_by_service: dict[str, list[tuple[str, float]]] = defaultdict(list)

    for key in sorted(costs.keys()):
        if key not in usage:
            print(
                f"WARN: no usage for month={key[0]} service={key[1]}; skipping",
                file=sys.stderr,
            )
            continue
        month, service = key
        cost = costs[key]
        mau, reqs = usage[key]
        cpm = cost / mau if mau else 0.0
        cpr = cost / reqs if reqs else 0.0
        writer.writerow(
            [
                month,
                service,
                f"{cost:.2f}",
                mau,
                reqs,
                f"{cpm:.6f}",
                f"{cpr:.6f}",
            ]
        )
        per_req_by_service[service].append((month, cpr))

    # Anomaly detection: ratio to median per service.
    any_anomaly = False
    for service, series in per_req_by_service.items():
        values = [v for _, v in series]
        if len(values) < 3:
            continue
        median = statistics.median(values)
        for month, v in series:
            ratio = v / median if median else 0.0
            if ratio >= ANOMALY_RATIO:
                any_anomaly = True
                print(
                    f"ANOMALY: service={service} month={month} "
                    f"cost_per_req={v:.6f} (median={median:.6f}, "
                    f"ratio={ratio:.2f}x)",
                    file=sys.stderr,
                )

    if not any_anomaly:
        print("INFO: no anomalies detected under current threshold.", file=sys.stderr)

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
