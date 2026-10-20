#!/usr/bin/env bash
# Validate: student's workflow at .github/workflows/pipeline.yml has
# build/test/deploy jobs chained by needs, sharing an artifact via v4.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Some checks use
# `grep -q` after producers that may close early (SIGPIPE / exit 141), which
# would spuriously mark those checks as failures.

DEST="${1:-${DEST_DIR:-/tmp/share-build-artifact}}"
fail=0

echo "== Validating $DEST =="

if [ ! -d "$DEST" ]; then
  echo "  FAIL $DEST does not exist. Build it with starter/build-starter.sh"
  exit 1
fi

WF="$DEST/.github/workflows/pipeline.yml"
if [ ! -f "$WF" ]; then
  echo "  FAIL workflow not found at $WF"
  exit 1
fi
echo "  OK   workflow present"

python3 - "$WF" <<'PY'
import sys, re
import yaml

path = sys.argv[1]
issues = []
oks = []

try:
    wf = yaml.safe_load(open(path))
except yaml.YAMLError as e:
    print(f"  FAIL YAML parse error: {e}")
    sys.exit(2)

if not isinstance(wf, dict) or "jobs" not in wf:
    print("  FAIL workflow has no 'jobs' key")
    sys.exit(2)
oks.append("YAML parses and has 'jobs'")

jobs = wf.get("jobs") or {}
required = {"build", "test", "deploy"}
missing = required - set(jobs)
if missing:
    issues.append(f"missing jobs: {sorted(missing)} (required: build, test, deploy)")
else:
    oks.append("jobs 'build', 'test', 'deploy' all present")

def norm_needs(x):
    if x is None:
        return []
    if isinstance(x, str):
        return [x]
    if isinstance(x, list):
        return list(x)
    return []

# Compute transitive needs closure for a job
def transitive_needs(job_name, memo=None):
    if memo is None:
        memo = {}
    if job_name in memo:
        return memo[job_name]
    direct = norm_needs(jobs.get(job_name, {}).get("needs"))
    seen = set(direct)
    for d in direct:
        seen |= transitive_needs(d, memo)
    memo[job_name] = seen
    return seen

if not missing:
    test_needs = transitive_needs("test")
    deploy_needs = transitive_needs("deploy")
    if "build" in test_needs:
        oks.append("test depends on build (directly or transitively)")
    else:
        issues.append("test does not depend on build via `needs:`")
    if "build" in deploy_needs:
        oks.append("deploy depends on build (directly or transitively)")
    else:
        issues.append("deploy does not depend on build via `needs:`")

# Collect steps per job
def steps_of(job_name):
    return (jobs.get(job_name, {}).get("steps") or [])

# Reject deprecated artifact action versions anywhere
for jn, job in jobs.items():
    for s in (job.get("steps") or []):
        uses = s.get("uses") or ""
        m = re.match(r"actions/(upload|download)-artifact@v([0-9]+)", uses)
        if m and int(m.group(2)) < 4:
            issues.append(f"job '{jn}' uses deprecated {uses} — upgrade to @v4")

# Build must upload one artifact
upload_name = None
upload_count = 0
for s in steps_of("build"):
    uses = s.get("uses") or ""
    if uses.startswith("actions/upload-artifact@v4"):
        with_block = s.get("with") or {}
        name = with_block.get("name")
        if name:
            upload_count += 1
            upload_name = name
            # Nice-to-have checks (warnings only)
            if with_block.get("if-no-files-found") == "error":
                oks.append("upload-artifact has if-no-files-found: error (good)")
            if with_block.get("retention-days"):
                oks.append(f"upload-artifact has retention-days: {with_block.get('retention-days')}")

if upload_count == 1:
    oks.append(f"build uploads exactly one artifact (name='{upload_name}') with actions/upload-artifact@v4")
elif upload_count == 0:
    issues.append("build has no actions/upload-artifact@v4 step with a 'name'")
else:
    issues.append(f"build has {upload_count} upload-artifact@v4 steps; expected exactly 1")

# Test and deploy must download the same artifact
def find_download_name(job_name):
    names = []
    for s in steps_of(job_name):
        uses = s.get("uses") or ""
        if uses.startswith("actions/download-artifact@v4"):
            with_block = s.get("with") or {}
            if with_block.get("name"):
                names.append(with_block["name"])
    return names

test_dls = find_download_name("test")
deploy_dls = find_download_name("deploy")

if len(test_dls) >= 1:
    oks.append(f"test downloads artifact(s) via @v4: {test_dls}")
else:
    issues.append("test has no actions/download-artifact@v4 step with a 'name'")

if len(deploy_dls) >= 1:
    oks.append(f"deploy downloads artifact(s) via @v4: {deploy_dls}")
else:
    issues.append("deploy has no actions/download-artifact@v4 step with a 'name'")

if upload_name:
    if upload_name not in test_dls:
        issues.append(f"test does not download the artifact uploaded by build (expected name '{upload_name}', saw {test_dls})")
    else:
        oks.append("test downloads the same artifact name as build uploaded")
    if upload_name not in deploy_dls:
        issues.append(f"deploy does not download the artifact uploaded by build (expected name '{upload_name}', saw {deploy_dls})")
    else:
        oks.append("deploy downloads the same artifact name as build uploaded")

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
