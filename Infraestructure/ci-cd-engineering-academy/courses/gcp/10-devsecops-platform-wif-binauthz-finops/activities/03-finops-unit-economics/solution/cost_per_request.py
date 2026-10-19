#!/usr/bin/env python3
"""Compute cost-per-request for the checkout workload (reference solution).

Usage: python3 cost_per_request.py <billing_csv> <business_csv>

Reads a flattened Billing export (synthetic CSV) and a business metrics CSV.
Sums net cost (cost + credits) for all rows where label_workload == 'checkout'
and invoice_month == '202610', then divides by requests_served for the same
workload+month. Prints a single float with 6 decimals.
"""

from __future__ import annotations

import csv
import sys
from pathlib import Path

MONTH = "202610"
WORKLOAD = "checkout"


def net_cost(billing_csv: Path, workload: str, month: str) -> float:
    total = 0.0
    with billing_csv.open(newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            if row["label_workload"] != workload:
                continue
            if row["invoice_month"] != month:
                continue
            total += float(row["cost"]) + float(row["credits"])
    return total


def requests_served(business_csv: Path, workload: str, month: str) -> int:
    with business_csv.open(newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            if row["workload"] == workload and row["month"] == month:
                return int(row["requests_served"])
    raise LookupError(f"No business metrics for {workload} / {month}")


def main() -> int:
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} <billing_csv> <business_csv>", file=sys.stderr)
        return 2
    billing = Path(sys.argv[1])
    business = Path(sys.argv[2])
    cost = net_cost(billing, WORKLOAD, MONTH)
    reqs = requests_served(business, WORKLOAD, MONTH)
    if reqs == 0:
        print(f"requests_served == 0 for {WORKLOAD}/{MONTH}", file=sys.stderr)
        return 1
    print(f"{cost / reqs:.6f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
