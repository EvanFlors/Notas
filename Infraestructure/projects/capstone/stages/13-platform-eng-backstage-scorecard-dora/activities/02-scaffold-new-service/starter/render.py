#!/usr/bin/env python3
"""Minimal local renderer that mimics `fetch:template` from Backstage.

Walks a skeleton directory and copies files into a destination, substituting
`${{ values.<key> }}` placeholders. Lives alongside the activity so the
student can see how the scaffolder resolves variables.
"""
from __future__ import annotations

import argparse
import re
import shutil
import sys
from pathlib import Path


PLACEHOLDER = re.compile(r"\$\{\{\s*values\.([a-zA-Z_][a-zA-Z0-9_]*)\s*\}\}")


def render_text(text: str, values: dict[str, str]) -> str:
    def _sub(m: re.Match[str]) -> str:
        key = m.group(1)
        if key not in values:
            raise KeyError(f"missing value for '{key}'")
        return values[key]
    return PLACEHOLDER.sub(_sub, text)


def render_tree(src: Path, dst: Path, values: dict[str, str]) -> int:
    count = 0
    if dst.exists():
        shutil.rmtree(dst)
    dst.mkdir(parents=True)
    for path in src.rglob("*"):
        rel = path.relative_to(src)
        target = dst / rel
        if path.is_dir():
            target.mkdir(parents=True, exist_ok=True)
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        try:
            text = path.read_text()
        except UnicodeDecodeError:
            shutil.copy2(path, target)
            continue
        target.write_text(render_text(text, values))
        count += 1
    return count


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True, type=Path)
    ap.add_argument("--dst", required=True, type=Path)
    ap.add_argument("--name", required=True)
    ap.add_argument("--description", required=True)
    ap.add_argument("--owner", required=True)
    ap.add_argument("--tier", required=True, choices=["tier-1", "tier-2", "tier-3"])
    args = ap.parse_args()

    if not args.src.exists():
        print(f"ERROR: src {args.src} not found", file=sys.stderr)
        return 2
    values = {
        "name": args.name,
        "description": args.description,
        "owner": args.owner,
        "tier": args.tier,
    }
    n = render_tree(args.src, args.dst, values)
    print(f"Rendered {n} file(s) into {args.dst}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
