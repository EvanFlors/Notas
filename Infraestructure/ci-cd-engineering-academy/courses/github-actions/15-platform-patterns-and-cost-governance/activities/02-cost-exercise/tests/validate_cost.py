#!/usr/bin/env python3
"""Validate the student's cost-estimate.yaml for module gha-15 activity 02.

Checks:
  - YAML parseable + required keys present.
  - For each SKU, minutes_month and cost_usd match the formula (within tolerance).
  - total_usd matches the official total within +/- 5%.

Exit code 0 on PASS, non-zero on FAIL.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML required. Install with: pip install pyyaml", file=sys.stderr)
    sys.exit(2)

TOLERANCE = 0.05  # +/- 5%

# Official reference total (ACME-mini scenario, 30 days):
#   ubuntu:  400*4*30 * 0.008  = 384.00
#   windows:  50*6*30 * 0.016  = 144.00
#   macos:    10*8*30 * 0.080  = 192.00
#   large16:  20*5*30 * 0.064  = 192.00
#   artifacts: 50 * 0.25       =  12.50
#   ghcr:     200 * 0.25       =  50.00
# Total                        = 974.50
OFFICIAL_TOTAL = 974.50

REQUIRED_MIN_SKUS = {
    "ubuntu-latest",
    "windows-latest",
    "macos-latest",
    "ubuntu-latest-16-core",
}
REQUIRED_STORAGE = {"artifacts", "ghcr"}


def _as_float(x, where: str, issues: list[str]) -> float | None:
    if isinstance(x, (int, float)):
        return float(x)
    issues.append(f"FAIL {where}: value is not numeric (got {x!r})")
    return None


def _check_close(actual: float, expected: float, label: str, issues: list[str],
                 tol: float = 0.01) -> None:
    if expected == 0:
        if abs(actual) < tol:
            return
    if math.isclose(actual, expected, rel_tol=tol, abs_tol=tol):
        return
    issues.append(f"FAIL {label}: got {actual:.4f}, expected ~{expected:.4f}")


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: validate_cost.py <path-to-cost-estimate.yaml>", file=sys.stderr)
        return 2

    path = Path(sys.argv[1])
    if not path.exists():
        print(f"FAIL file not found: {path}")
        return 1

    try:
        data = yaml.safe_load(path.read_text())
    except yaml.YAMLError as e:
        print(f"FAIL YAML invalid: {e}")
        return 1

    if not isinstance(data, dict):
        print("FAIL root is not a mapping")
        return 1

    issues: list[str] = []

    # Section: minutes
    mins = data.get("minutes") or {}
    if not isinstance(mins, dict):
        issues.append("FAIL 'minutes' must be a mapping")
    else:
        missing = REQUIRED_MIN_SKUS - set(mins.keys())
        if missing:
            issues.append(f"FAIL missing minute SKU(s): {sorted(missing)}")

        for sku, cfg in mins.items():
            if not isinstance(cfg, dict):
                issues.append(f"FAIL minutes.{sku} must be a mapping")
                continue
            rpd = _as_float(cfg.get("runs_per_day"), f"minutes.{sku}.runs_per_day", issues)
            dur = _as_float(cfg.get("avg_duration_min"), f"minutes.{sku}.avg_duration_min", issues)
            price = _as_float(cfg.get("price_per_min"), f"minutes.{sku}.price_per_min", issues)
            mm = _as_float(cfg.get("minutes_month"), f"minutes.{sku}.minutes_month", issues)
            cu = _as_float(cfg.get("cost_usd"), f"minutes.{sku}.cost_usd", issues)
            if None in (rpd, dur, price, mm, cu):
                continue
            expected_mm = rpd * dur * 30
            expected_cu = expected_mm * price
            _check_close(mm, expected_mm, f"minutes.{sku}.minutes_month", issues)
            _check_close(cu, expected_cu, f"minutes.{sku}.cost_usd", issues)

    # Section: storage
    stor = data.get("storage") or {}
    if not isinstance(stor, dict):
        issues.append("FAIL 'storage' must be a mapping")
    else:
        missing_s = REQUIRED_STORAGE - set(stor.keys())
        if missing_s:
            issues.append(f"FAIL missing storage bucket(s): {sorted(missing_s)}")
        for bucket, cfg in stor.items():
            if not isinstance(cfg, dict):
                issues.append(f"FAIL storage.{bucket} must be a mapping")
                continue
            gb = _as_float(cfg.get("gb_month"), f"storage.{bucket}.gb_month", issues)
            price = _as_float(cfg.get("price_per_gb"), f"storage.{bucket}.price_per_gb", issues)
            cu = _as_float(cfg.get("cost_usd"), f"storage.{bucket}.cost_usd", issues)
            if None in (gb, price, cu):
                continue
            expected_cu = gb * price
            _check_close(cu, expected_cu, f"storage.{bucket}.cost_usd", issues)

    # Total
    total = _as_float(data.get("total_usd"), "total_usd", issues)
    if total is not None:
        lo = OFFICIAL_TOTAL * (1 - TOLERANCE)
        hi = OFFICIAL_TOTAL * (1 + TOLERANCE)
        if lo <= total <= hi:
            print(f"  OK   total_usd={total:.2f} within ±{TOLERANCE*100:.0f}% of "
                  f"official {OFFICIAL_TOTAL:.2f} (range {lo:.2f}..{hi:.2f})")
        else:
            delta_pct = (total - OFFICIAL_TOTAL) / OFFICIAL_TOTAL * 100
            issues.append(
                f"FAIL total_usd={total:.2f} is OUTSIDE ±{TOLERANCE*100:.0f}% of "
                f"official {OFFICIAL_TOTAL:.2f} (delta {delta_pct:+.2f}%)"
            )

    if issues:
        for i in issues:
            print(i)
        print(f"\nRESULT: {len(issues)} check(s) failed.")
        return 1

    print("OK: cost estimate verified (structure + formulas + total within ±5%).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
