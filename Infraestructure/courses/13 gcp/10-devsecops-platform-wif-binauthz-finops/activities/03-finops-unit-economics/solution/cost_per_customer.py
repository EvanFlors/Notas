#!/usr/bin/env python3
"""Compute cost-per-MAC for the checkout workload (reference solution).

Usage: python3 cost_per_customer.py <billing_csv> <business_csv>
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


def active_customers(business_csv: Path, workload: str, month: str) -> int:
    with business_csv.open(newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            if row["workload"] == workload and row["month"] == month:
                return int(row["active_customers"])
    raise LookupError(f"No business metrics for {workload} / {month}")


def main() -> int:
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} <billing_csv> <business_csv>", file=sys.stderr)
        return 2
    billing = Path(sys.argv[1])
    business = Path(sys.argv[2])
    cost = net_cost(billing, WORKLOAD, MONTH)
    mac = active_customers(business, WORKLOAD, MONTH)
    if mac == 0:
        print(f"active_customers == 0 for {WORKLOAD}/{MONTH}", file=sys.stderr)
        return 1
    print(f"{cost / mac:.6f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
