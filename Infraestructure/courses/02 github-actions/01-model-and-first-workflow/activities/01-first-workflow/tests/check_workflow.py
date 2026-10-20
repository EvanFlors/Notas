#!/usr/bin/env python3
"""Structural checks for the gha-01-01-first-workflow YAML.

Reads a workflow file and prints lines of the form:
  STRUCT_OK
or one or more:
  STRUCT_ISSUE: <description>
  YAML_ERROR: <description>
  STRUCT_ERROR: <description>

Exits 0 on OK, 1 on structural issues, 2 on YAML/schema errors.
"""
from __future__ import annotations

import sys

try:
    import yaml
except ImportError:
    print("STRUCT_ERROR: PyYAML not installed (pip install pyyaml)")
    sys.exit(2)


def main() -> int:
    if len(sys.argv) < 2:
        print("STRUCT_ERROR: usage: check_workflow.py <workflow.yml>")
        return 2
    path = sys.argv[1]
    try:
        with open(path) as f:
            data = yaml.safe_load(f)
    except (OSError, yaml.YAMLError) as exc:
        print(f"YAML_ERROR: {exc}")
        return 2

    if not isinstance(data, dict):
        print("STRUCT_ERROR: root is not a mapping")
        return 2

    issues: list[str] = []

    # `on:` key — PyYAML parses bare `on` as Python True unless quoted.
    on_val = data.get("on", data.get(True))
    if on_val is None:
        issues.append("missing on: key")
    else:
        def has_trigger(trig: str) -> bool:
            if isinstance(on_val, str):
                return on_val == trig
            if isinstance(on_val, list):
                return trig in on_val
            if isinstance(on_val, dict):
                return trig in on_val
            return False
        if not has_trigger("push"):
            issues.append("on: missing trigger push")
        if not has_trigger("pull_request"):
            issues.append("on: missing trigger pull_request")

    jobs = data.get("jobs")
    if not isinstance(jobs, dict) or not jobs:
        issues.append("missing or empty jobs: mapping")
    else:
        job_names = list(jobs.keys())
        if job_names == ["noop"] and data.get("name") == "placeholder":
            issues.append("workflow is still the PLACEHOLDER — replace it")

        first_job_name = job_names[0]
        first_job = jobs[first_job_name]
        if not isinstance(first_job, dict):
            issues.append(f"job {first_job_name} is not a mapping")
        else:
            runs_on = first_job.get("runs-on")
            if not isinstance(runs_on, str) or not runs_on.startswith("ubuntu-"):
                issues.append(
                    f"job {first_job_name}.runs-on must start with ubuntu- (got: {runs_on!r})"
                )

            steps = first_job.get("steps")
            if not isinstance(steps, list) or not steps:
                issues.append(f"job {first_job_name} has no steps:")
            else:
                first = steps[0]
                if not isinstance(first, dict) or "uses" not in first:
                    issues.append("first step must be a uses: actions/checkout@v<N>")
                else:
                    uses = first["uses"]
                    if not isinstance(uses, str) or not uses.startswith("actions/checkout@"):
                        issues.append(
                            f"first step uses must be actions/checkout@v<N> (got {uses!r})"
                        )
                    else:
                        tag = uses.split("@", 1)[1]
                        if tag not in ("v3", "v4"):
                            issues.append(
                                f"first step uses tag should be v3 or v4 (got {tag!r})"
                            )

                found_run_with_github = False
                for st in steps:
                    if isinstance(st, dict) and isinstance(st.get("run"), str):
                        run_src = st["run"]
                        if "$GITHUB_" in run_src or "${{ github" in run_src:
                            found_run_with_github = True
                            break
                if not found_run_with_github:
                    issues.append("no run: step references a $GITHUB_* variable")

    if issues:
        for i in issues:
            print(f"STRUCT_ISSUE: {i}")
        return 1

    print("STRUCT_OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
