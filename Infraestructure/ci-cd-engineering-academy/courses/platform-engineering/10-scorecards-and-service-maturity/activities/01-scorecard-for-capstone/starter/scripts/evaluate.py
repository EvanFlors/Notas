#!/usr/bin/env python3
"""Evaluate a scorecard YAML against a synthetic catalog of service JSONs.

Produces:
  - results.json: list of per-service results (ref, level, failed_checks)
  - REPORT.md:    human-readable report with per-service table + adoption aggregate

Fact collectors in Backstage TechInsights would normally produce the per-service
JSONs. Here they are pre-rendered to let you iterate on scorecard design without
running Backstage.

Usage:
  python3 evaluate.py --scorecard scorecard.yaml --catalog catalog/ --out .
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML required. Install with: pip install pyyaml", file=sys.stderr)
    sys.exit(2)


ALLOWED_OPERATORS = {"is_set", "equals", "less_than", "greater_than", "in"}


def get_field(service: dict, dotted: str):
    """Resolve 'annotations.slo.url' against a nested dict. Returns None if missing."""
    cur = service
    for part in dotted.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return None
        cur = cur[part]
    return cur


def evaluate_check(service: dict, check: dict) -> bool:
    op = check["operator"]
    value = get_field(service, check["field"])
    expected = check.get("value")

    if op == "is_set":
        return value is not None and value != ""
    if op == "equals":
        return value == expected
    if op == "less_than":
        try:
            return value is not None and float(value) < float(expected)
        except (TypeError, ValueError):
            return False
    if op == "greater_than":
        try:
            return value is not None and float(value) > float(expected)
        except (TypeError, ValueError):
            return False
    if op == "in":
        return value in (expected or [])
    raise ValueError(f"Unknown operator: {op}")


def load_scorecard(path: Path) -> dict:
    data = yaml.safe_load(path.read_text())
    if not isinstance(data, dict):
        raise ValueError(f"{path}: root is not a mapping")
    levels = data.get("levels") or []
    checks = data.get("checks") or []
    if not levels:
        raise ValueError(f"{path}: 'levels' is empty")
    if not (5 <= len(checks) <= 8):
        raise ValueError(f"{path}: expected 5-8 checks, got {len(checks)}")
    for ch in checks:
        for key in ("id", "weight", "field", "operator"):
            if key not in ch:
                raise ValueError(f"{path}: check missing '{key}': {ch}")
        if ch["weight"] not in levels:
            raise ValueError(
                f"{path}: check '{ch['id']}' has weight '{ch['weight']}' not in levels"
            )
        if ch["operator"] not in ALLOWED_OPERATORS:
            raise ValueError(
                f"{path}: check '{ch['id']}' has unknown operator '{ch['operator']}'"
            )
    return data


def load_catalog(dir_: Path) -> list[dict]:
    services = []
    for p in sorted(dir_.glob("*.json")):
        services.append(json.loads(p.read_text()))
    if not services:
        raise ValueError(f"{dir_}: no service JSONs found")
    return services


def level_for(service: dict, scorecard: dict) -> tuple[str, list[str]]:
    """Return (level, failed_check_ids). Level is highest level whose checks all pass."""
    levels = scorecard["levels"]
    checks = scorecard["checks"]
    by_level: dict[str, list[dict]] = {lvl: [] for lvl in levels}
    for ch in checks:
        by_level[ch["weight"]].append(ch)

    failed_cumulative: list[str] = []
    attained = "unranked"
    for lvl in levels:
        failures_this_level = [
            ch["id"] for ch in by_level[lvl] if not evaluate_check(service, ch)
        ]
        if failures_this_level:
            # Stop here: cannot reach this level or beyond.
            failed_cumulative.extend(failures_this_level)
            return attained, failed_cumulative
        attained = lvl
    return attained, failed_cumulative


def render_report(results: list[dict], scorecard: dict) -> str:
    levels = scorecard["levels"]
    total = len(results)

    def pct(predicate) -> int:
        if total == 0:
            return 0
        return round(100 * sum(1 for r in results if predicate(r)) / total)

    # "At or above" adoption per level. A service "reached" level L if its level
    # index in `levels` is >= L's index.
    level_index = {name: i for i, name in enumerate(levels)}

    def reached(r, lvl):
        if r["level"] == "unranked":
            return False
        return level_index[r["level"]] >= level_index[lvl]

    lines = []
    lines.append(f"# Scorecard report — {scorecard.get('name', '(unnamed)')}")
    lines.append("")
    lines.append(f"- Catálogo evaluado: **{total} servicios**")
    lines.append(f"- Chequeos activos: **{len(scorecard['checks'])}**")
    lines.append(f"- Niveles: `{', '.join(levels)}`")
    lines.append("")
    lines.append("## Adopción agregada")
    lines.append("")
    lines.append("| Nivel | % servicios en ese nivel o superior |")
    lines.append("|---|---|")
    for lvl in levels:
        lines.append(f"| {lvl} | {pct(lambda r, l=lvl: reached(r, l))}% |")
    lines.append("")
    lines.append("## Resultado por servicio")
    lines.append("")
    lines.append("| Servicio | Nivel | Chequeos fallados |")
    lines.append("|---|---|---|")
    for r in results:
        failed = ", ".join(r["failed_checks"]) or "—"
        lines.append(f"| `{r['ref']}` | **{r['level']}** | {failed} |")
    lines.append("")
    lines.append("> Nota: este reporte **no publica rankings entre equipos**. ")
    lines.append("> La agregación por dominio/tier/antigüedad es un ejercicio aparte.")
    return "\n".join(lines) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--scorecard", required=True, type=Path)
    ap.add_argument("--catalog", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    args = ap.parse_args()

    scorecard = load_scorecard(args.scorecard)
    catalog = load_catalog(args.catalog)

    results = []
    for svc in catalog:
        level, failed = level_for(svc, scorecard)
        results.append({
            "ref": svc.get("ref", svc.get("name", "unknown")),
            "level": level,
            "failed_checks": failed,
        })

    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / "results.json").write_text(json.dumps(results, indent=2) + "\n")
    (args.out / "REPORT.md").write_text(render_report(results, scorecard))

    print(f"OK: evaluated {len(results)} services against {len(scorecard['checks'])} checks.")
    print(f"  wrote {args.out / 'results.json'}")
    print(f"  wrote {args.out / 'REPORT.md'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
