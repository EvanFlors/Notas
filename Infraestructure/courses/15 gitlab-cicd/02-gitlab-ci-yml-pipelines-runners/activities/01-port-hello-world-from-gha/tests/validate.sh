#!/usr/bin/env bash
# Structural validation for gl-02-01-port-hello-world-from-gha.
# Parses .gitlab-ci.yml with Python's yaml module and checks:
#   - YAML is valid
#   - stages: declares at least lint, test, build
#   - at least 3 non-reserved jobs, each with stage + script
#   - at least one job has an image: (Docker executor usage)
#   - no legacy only: / except: anywhere
#   - workflow: or any rules: mentions 'main' or 'merge_request'
#   - script: of every job is a list, not a scalar
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT run the pipeline on GitLab — compare manually with
# solution/REFERENCE.md and (optionally) run `gitlab-ci-lint` if installed.

set -eu

BASE="${1:-/tmp/gl-02-01}"
DOC="$BASE/.gitlab-ci.yml"
fail=0

echo "== Structural validation for $BASE =="

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: 'python3' is required but not installed."
  exit 2
fi

if ! python3 -c 'import yaml' >/dev/null 2>&1; then
  echo "FAIL: Python 'yaml' module missing. Install with: python3 -m pip install --user pyyaml"
  exit 2
fi

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Run the structural checks in a single Python process to keep the script short.
python3 - "$DOC" <<'PY' || fail=$((fail+1))
import sys, yaml

path = sys.argv[1]
try:
    with open(path) as f:
        data = yaml.safe_load(f)
except yaml.YAMLError as exc:
    print(f"  FAIL YAML parse error: {exc}")
    sys.exit(1)

if not isinstance(data, dict):
    print("  FAIL root of .gitlab-ci.yml is not a mapping")
    sys.exit(1)

print("  OK   .gitlab-ci.yml parses as YAML")

# ---- stages ----
stages = data.get("stages")
if not isinstance(stages, list):
    print("  FAIL 'stages:' missing or not a list")
    sys.exit(1)
required_stages = {"lint", "test", "build"}
missing = required_stages - set(stages)
if missing:
    print(f"  FAIL stages missing: {sorted(missing)} (got {stages})")
    sys.exit(1)
print(f"  OK   stages declared: {stages}")

# ---- jobs ----
RESERVED = {
    "stages", "variables", "default", "workflow", "include", "image",
    "services", "before_script", "after_script", "cache", "pages",
    "secrets", "id_tokens", "concurrency",
}
jobs = {k: v for k, v in data.items()
        if k not in RESERVED and isinstance(v, dict)}
if len(jobs) < 3:
    print(f"  FAIL expected >=3 jobs, got {len(jobs)}: {list(jobs)}")
    sys.exit(1)
print(f"  OK   {len(jobs)} job(s) defined: {list(jobs)}")

# Each job: stage in required_stages and script is a list.
with_image = 0
for name, job in jobs.items():
    stage = job.get("stage")
    if stage not in stages:
        print(f"  FAIL job '{name}' has stage '{stage}' not in stages {stages}")
        sys.exit(1)
    script = job.get("script")
    if not isinstance(script, list) or not script:
        print(f"  FAIL job '{name}' script must be a non-empty list")
        sys.exit(1)
    if "image" in job:
        with_image += 1

if with_image < 1:
    # Also allow a default: image:
    default = data.get("default") or {}
    if "image" not in default:
        print("  FAIL no job declares 'image:' and no 'default: image:' either")
        sys.exit(1)
print("  OK   every job has stage + script list; image: usage detected")

# ---- no legacy only/except anywhere ----
import json
blob = json.dumps(data)
if '"only"' in blob or '"except"' in blob:
    print("  FAIL legacy 'only:' or 'except:' found — use 'rules:' instead")
    sys.exit(1)
print("  OK   no legacy only:/except: used")

# ---- workflow: or rules: must mention main or merge_request ----
candidates = []
wf = data.get("workflow") or {}
if isinstance(wf, dict) and isinstance(wf.get("rules"), list):
    candidates.append(wf["rules"])
for name, job in jobs.items():
    rules = job.get("rules")
    if isinstance(rules, list):
        candidates.append(rules)

flat = json.dumps(candidates).lower()
if "main" in flat or "merge_request" in flat:
    print("  OK   workflow:/rules: mentions 'main' or 'merge_request'")
else:
    print("  FAIL no workflow:/rules: referencing 'main' or 'merge_request'")
    sys.exit(1)

print("  OK   all structural checks passed")
PY

# Optional: gitlab-ci-lint if available (SKIP if absent).
if command -v gitlab-ci-lint >/dev/null 2>&1; then
  if gitlab-ci-lint "$DOC" >/dev/null 2>&1; then
    echo "  OK   gitlab-ci-lint accepted the file"
  else
    echo "  FAIL gitlab-ci-lint rejected the file"
    fail=$((fail+1))
  fi
else
  echo "  SKIP gitlab-ci-lint not installed (optional)"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  echo "        (Semantic correctness on gitlab.com is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: .gitlab-ci.yml pasa validacion estructural."
echo "    Compara con solution/REFERENCE.md para autoevaluacion."
exit 0
