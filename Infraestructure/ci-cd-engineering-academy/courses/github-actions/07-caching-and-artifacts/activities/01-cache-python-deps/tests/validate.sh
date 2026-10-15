#!/usr/bin/env bash
# Validate: student's workflow at .github/workflows/ci.yml has a correct pip
# cache strategy (variant A: setup-python cache, or variant B: actions/cache@v4).
#
# Note: we deliberately do NOT enable `set -o pipefail`. Some checks use
# `grep -q` after producers that may close early (SIGPIPE / exit 141), which
# would spuriously mark those checks as failures.

DEST="${1:-${DEST_DIR:-/tmp/cache-python-deps}}"
fail=0

echo "== Validating $DEST =="

if [ ! -d "$DEST" ]; then
  echo "  FAIL $DEST does not exist. Build it with starter/build-starter.sh"
  exit 1
fi

WF="$DEST/.github/workflows/ci.yml"
if [ ! -f "$WF" ]; then
  echo "  FAIL workflow not found at $WF"
  exit 1
fi
echo "  OK   workflow present"

# Lockfile must exist for hashFiles to be meaningful
if [ -f "$DEST/requirements.txt" ]; then
  echo "  OK   requirements.txt present (hashFiles target exists)"
else
  echo "  FAIL requirements.txt missing — hashFiles would hash the empty set"
  fail=$((fail+1))
fi

# Run the YAML + content inspection in Python (PyYAML).
python3 - "$WF" <<'PY'
import sys, re
import yaml

path = sys.argv[1]
issues = []
oks = []

try:
    with open(path) as fp:
        wf = yaml.safe_load(fp)
except yaml.YAMLError as e:
    print(f"  FAIL YAML parse error: {e}")
    sys.exit(2)

if not isinstance(wf, dict) or "jobs" not in wf:
    print("  FAIL workflow has no 'jobs' key")
    sys.exit(2)
oks.append("YAML parses and has 'jobs'")

# Collect all steps across all jobs
all_steps = []
for job_name, job in (wf.get("jobs") or {}).items():
    for s in (job.get("steps") or []):
        all_steps.append((job_name, s))

# Check that pip install is still there (student didn't break the install)
install_present = any(
    isinstance(s.get("run"), str) and re.search(r"pip\s+install", s["run"])
    for _, s in all_steps
)
if install_present:
    oks.append("pip install step still present")
else:
    issues.append("pip install step was removed — the workflow no longer installs deps")

# --- Variant A: setup-python with cache: 'pip' ---
variant_a = False
for _, s in all_steps:
    uses = s.get("uses") or ""
    if uses.startswith("actions/setup-python@"):
        with_block = s.get("with") or {}
        cache = with_block.get("cache")
        cdp = with_block.get("cache-dependency-path")
        if cache == "pip" and cdp:
            variant_a = True
            oks.append(f"Variant A detected: setup-python with cache='pip' and cache-dependency-path='{cdp}'")

# --- Variant B: actions/cache@v4 with hashFiles key + restore-keys ---
variant_b = False
for _, s in all_steps:
    uses = s.get("uses") or ""
    if uses.startswith("actions/cache@v4"):
        with_block = s.get("with") or {}
        key = with_block.get("key") or ""
        restore_keys = with_block.get("restore-keys") or ""
        path_val = with_block.get("path") or ""
        has_hashfiles = "hashFiles(" in key
        has_restore = bool(str(restore_keys).strip())
        has_path = bool(str(path_val).strip())
        if has_hashfiles and has_restore and has_path:
            variant_b = True
            oks.append("Variant B detected: actions/cache@v4 with hashFiles(...) key, restore-keys, and path")
        else:
            # Partial — report precise issue to help the student
            if not has_hashfiles:
                issues.append("actions/cache@v4 present but 'key' does not include hashFiles(...) — the key must change with the lockfile")
            if not has_restore:
                issues.append("actions/cache@v4 present but 'restore-keys' is missing (needed as fallback)")
            if not has_path:
                issues.append("actions/cache@v4 present but 'path' is empty")
    elif uses.startswith("actions/cache@") and not uses.startswith("actions/cache@v4"):
        issues.append(f"found {uses} — pin to actions/cache@v4 (v3 and older are deprecated)")

# Must have at least one correct variant
if variant_a or variant_b:
    oks.append("At least one correct cache variant is wired up")
else:
    issues.append("Neither variant A (setup-python cache: 'pip' + cache-dependency-path) nor variant B (actions/cache@v4 with hashFiles + restore-keys) is present")

# Reject deprecated artifact actions just in case
for _, s in all_steps:
    uses = s.get("uses") or ""
    if re.match(r"actions/(upload|download)-artifact@v[123]\b", uses):
        issues.append(f"found deprecated {uses} — upgrade to @v4")

for o in oks:
    print(f"  OK   {o}")
for i in issues:
    print(f"  FAIL {i}")

sys.exit(1 if issues else 0)
PY
rc=$?

if [ "$rc" -ne 0 ]; then
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: actividad completada correctamente."
exit 0
