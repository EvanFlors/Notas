#!/usr/bin/env python3
"""Evaluate a Backstage-style scorecard against a catalog-info.yaml.

Reads a scorecard definition and a catalog file (multi-doc YAML), then
reports, per Component, the current maturity level (bronze / silver / gold /
unranked) and the list of pending checks.

Levels are treated as sets, not weighted sums: a component reaches "gold"
only when it passes every bronze + silver + gold check.

Usage:
    python3 evaluate.py --scorecard scorecard.yaml --catalog catalog.yaml
    python3 evaluate.py --scorecard scorecard.yaml --catalog catalog.yaml --json

Exit codes:
    0 - evaluation ran, report printed (even if some components are unranked).
    2 - invalid input (bad YAML, missing file, malformed check).
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML required (pip install pyyaml)", file=sys.stderr)
    sys.exit(2)


LEVELS = ("bronze", "silver", "gold")


def _dig(obj: Any, dotted: str) -> Any:
    cur: Any = obj
    for part in dotted.split("."):
        if isinstance(cur, dict) and part in cur:
            cur = cur[part]
        else:
            return None
    return cur


def _coerce_number(v: Any) -> float | None:
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def evaluate_check(check: dict, entity: dict) -> bool:
    op = check.get("operator")
    field = check.get("field")
    actual = _dig(entity, field) if field else None
    if op == "is_set":
        return actual not in (None, "", [], {})
    if op == "equals":
        expected = check.get("value")
        # Normalize to strings for annotation comparisons.
        return str(actual).lower() == str(expected).lower()
    if op == "less_than":
        a = _coerce_number(actual)
        b = _coerce_number(check.get("value"))
        if a is None or b is None:
            return False
        return a < b
    raise ValueError(f"unknown operator: {op!r} on check {check.get('id')!r}")


def rank(passing: dict[str, bool], checks_by_level: dict[str, list[dict]]) -> str:
    reached = "unranked"
    for lvl in LEVELS:
        if all(passing[c["id"]] for c in checks_by_level.get(lvl, [])):
            reached = lvl
        else:
            break
    return reached


def pending(level: str, passing: dict[str, bool],
            checks_by_level: dict[str, list[dict]]) -> list[str]:
    try:
        idx = LEVELS.index(level) + 1 if level in LEVELS else 0
    except ValueError:
        idx = 0
    out: list[str] = []
    for lvl in LEVELS[idx:]:
        for c in checks_by_level.get(lvl, []):
            if not passing[c["id"]]:
                out.append(f"[{lvl}] {c['id']}: {c.get('description', '')}")
    return out


def load_catalog(path: Path) -> list[dict]:
    docs = list(yaml.safe_load_all(path.read_text()))
    return [d for d in docs if isinstance(d, dict)]


def run(scorecard_path: Path, catalog_path: Path) -> dict:
    scorecard = yaml.safe_load(scorecard_path.read_text())
    if not isinstance(scorecard, dict):
        raise ValueError("scorecard root must be a mapping")
    checks = scorecard.get("checks") or []
    checks_by_level: dict[str, list[dict]] = {lvl: [] for lvl in LEVELS}
    for c in checks:
        lvl = c.get("weight")
        if lvl not in LEVELS:
            raise ValueError(f"check {c.get('id')} has invalid weight {lvl!r}")
        checks_by_level[lvl].append(c)

    components = [d for d in load_catalog(catalog_path)
                  if d.get("kind") == "Component"]

    results = []
    adoption = {lvl: 0 for lvl in LEVELS}
    adoption["unranked"] = 0
    for entity in components:
        passing = {c["id"]: evaluate_check(c, entity) for c in checks}
        level = rank(passing, checks_by_level)
        adoption[level] = adoption.get(level, 0) + 1
        results.append({
            "component": _dig(entity, "metadata.name"),
            "level": level,
            "passing": [cid for cid, ok in passing.items() if ok],
            "failing": [cid for cid, ok in passing.items() if not ok],
            "pending_to_next_level": pending(level, passing, checks_by_level),
        })

    return {
        "scorecard": scorecard.get("name"),
        "components_total": len(components),
        "adoption": adoption,
        "results": results,
    }


def render(report: dict) -> str:
    lines = [
        f"== Scorecard: {report['scorecard']} ==",
        f"Components: {report['components_total']}",
        "Adoption: " + ", ".join(
            f"{k}={v}" for k, v in report["adoption"].items() if v or k in LEVELS
        ),
        "",
    ]
    for r in report["results"]:
        lines.append(f"- {r['component']}: {r['level'].upper()}")
        if r["pending_to_next_level"]:
            for p in r["pending_to_next_level"]:
                lines.append(f"    pending: {p}")
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--scorecard", required=True, type=Path)
    ap.add_argument("--catalog", required=True, type=Path)
    ap.add_argument("--json", action="store_true", help="emit JSON instead of text")
    args = ap.parse_args()

    for p in (args.scorecard, args.catalog):
        if not p.exists():
            print(f"ERROR: {p} not found", file=sys.stderr)
            return 2

    try:
        report = run(args.scorecard, args.catalog)
    except (yaml.YAMLError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print(render(report))
    return 0


if __name__ == "__main__":
    sys.exit(main())
