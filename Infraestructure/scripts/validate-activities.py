#!/usr/bin/env python3
"""Validate structure and metadata of activities across all courses.

Checks, for every `activity.yaml` found under `courses/`:
  - required keys exist
  - referenced paths (instructions, starter, tests, solution) resolve
  - `id` is unique across the repo
  - `level` and `type` take allowed values

Exit code is non-zero if any issue is found.
"""

from __future__ import annotations

import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML required. Install with: pip install pyyaml", file=sys.stderr)
    sys.exit(2)

REPO_ROOT = Path(__file__).resolve().parent.parent
COURSES_DIR = REPO_ROOT / "courses"
PROJECTS_DIR = REPO_ROOT / "projects"

REQUIRED_KEYS = {"id", "title", "technology", "module", "level", "type",
                 "estimated_minutes", "objectives", "paths", "validation", "status"}
ALLOWED_LEVELS = {"beginner", "intermediate", "advanced"}
ALLOWED_TYPES = {"demo", "guided-lab", "independent", "debug", "challenge",
                 "mini-project", "scenario", "architecture"}
ALLOWED_STATUS = {"not-started", "in-progress", "completed"}


def validate(activity_file: Path, seen_ids: dict[str, Path]) -> list[str]:
    issues: list[str] = []
    try:
        data = yaml.safe_load(activity_file.read_text())
    except yaml.YAMLError as exc:
        return [f"{activity_file}: invalid YAML: {exc}"]

    if not isinstance(data, dict):
        return [f"{activity_file}: root is not a mapping"]

    missing = REQUIRED_KEYS - data.keys()
    if missing:
        issues.append(f"{activity_file}: missing keys: {sorted(missing)}")

    aid = data.get("id")
    if aid in seen_ids:
        issues.append(f"{activity_file}: duplicate id '{aid}' (also in {seen_ids[aid]})")
    elif aid:
        seen_ids[aid] = activity_file

    if data.get("level") not in ALLOWED_LEVELS:
        issues.append(f"{activity_file}: level must be one of {sorted(ALLOWED_LEVELS)}")
    if data.get("type") not in ALLOWED_TYPES:
        issues.append(f"{activity_file}: type must be one of {sorted(ALLOWED_TYPES)}")
    if data.get("status") not in ALLOWED_STATUS:
        issues.append(f"{activity_file}: status must be one of {sorted(ALLOWED_STATUS)}")

    paths = data.get("paths") or {}
    base = activity_file.parent
    for key in ("instructions", "starter", "tests", "solution"):
        rel = paths.get(key)
        if rel and not (base / rel).exists():
            issues.append(f"{activity_file}: paths.{key} '{rel}' does not exist")

    return issues


def main() -> int:
    if not COURSES_DIR.exists():
        print(f"No courses directory at {COURSES_DIR}")
        return 0

    seen_ids: dict[str, Path] = {}
    all_issues: list[str] = []
    count = 0
    search_roots = [COURSES_DIR]
    if PROJECTS_DIR.exists():
        search_roots.append(PROJECTS_DIR)
    for root in search_roots:
        for activity_file in root.rglob("activity.yaml"):
            count += 1
            all_issues.extend(validate(activity_file, seen_ids))

    for issue in all_issues:
        print(issue, file=sys.stderr)

    print(f"\nValidated {count} activity file(s); {len(all_issues)} issue(s).")
    return 1 if all_issues else 0


if __name__ == "__main__":
    sys.exit(main())
