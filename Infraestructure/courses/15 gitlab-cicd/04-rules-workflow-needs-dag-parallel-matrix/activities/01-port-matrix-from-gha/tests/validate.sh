#!/usr/bin/env bash
# Structural validation for gl-04-01-port-matrix-from-gha.
# Checks that .gitlab-ci.yml exists, parses as YAML, declares workflow:,
# has a test job with parallel.matrix expanding to exactly 6 combinations,
# and uses rules: with both `if:` and `changes:`.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness in a real GitLab runner — compare
# manually with solution/.gitlab-ci.yml.

set -eu

BASE="${1:-/tmp/gl-04-01}"
YML="$BASE/.gitlab-ci.yml"
fail=0

echo "== Structural validation for $BASE =="

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: 'python3' is required but not installed."
  exit 2
fi

if [ ! -f "$YML" ]; then
  echo "FAIL: $YML does not exist. Student must produce it."
  exit 1
fi

# --- 1) YAML parses ------------------------------------------------------
if python3 -c "import yaml,sys; yaml.safe_load(open('$YML'))" 2>/dev/null; then
  echo "  OK   $YML parses as YAML"
else
  echo "  FAIL $YML is not valid YAML"
  exit 1
fi

# --- 2) workflow: present with at least 3 rules -------------------------
wf_rules=$(python3 - "$YML" <<'PY' 2>/dev/null || echo "0"
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
wf = (d or {}).get("workflow") or {}
rules = wf.get("rules") or []
print(len(rules))
PY
)
if [ "$wf_rules" -ge 3 ]; then
  echo "  OK   workflow: present with $wf_rules rules (>=3)"
else
  echo "  FAIL workflow: must have at least 3 rules (found $wf_rules)"
  fail=$((fail+1))
fi

# --- 3) workflow has rule for MR event ----------------------------------
has_mr=$(python3 - "$YML" <<'PY' 2>/dev/null || echo "no"
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
rules = ((d or {}).get("workflow") or {}).get("rules") or []
for r in rules:
    if isinstance(r, dict):
        cond = str(r.get("if", ""))
        if "merge_request_event" in cond:
            print("yes"); break
else:
    print("no")
PY
)
if [ "$has_mr" = "yes" ]; then
  echo "  OK   workflow: has rule for merge_request_event"
else
  echo "  FAIL workflow: missing rule for merge_request_event"
  fail=$((fail+1))
fi

# --- 4) workflow has 'when: never' rule to avoid duplicate pipelines ---
has_never=$(python3 - "$YML" <<'PY' 2>/dev/null || echo "no"
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
rules = ((d or {}).get("workflow") or {}).get("rules") or []
for r in rules:
    if isinstance(r, dict) and r.get("when") == "never":
        print("yes"); break
else:
    print("no")
PY
)
if [ "$has_never" = "yes" ]; then
  echo "  OK   workflow: has at least one 'when: never' rule (duplicate guard)"
else
  echo "  FAIL workflow: no 'when: never' rule — duplicate pipelines not prevented"
  fail=$((fail+1))
fi

# --- 5) test job exists with parallel.matrix ----------------------------
check_test=$(python3 - "$YML" <<'PY' 2>/dev/null || echo "ERR"
import sys, yaml
d = yaml.safe_load(open(sys.argv[1])) or {}
job = d.get("test")
if not isinstance(job, dict):
    print("MISSING_JOB"); sys.exit(0)
par = job.get("parallel")
if not isinstance(par, dict) or "matrix" not in par:
    print("MISSING_MATRIX"); sys.exit(0)
mx = par["matrix"]
if not isinstance(mx, list):
    print("BAD_MATRIX"); sys.exit(0)
total = 0
for entry in mx:
    if not isinstance(entry, dict):
        print("BAD_ENTRY"); sys.exit(0)
    combo = 1
    for v in entry.values():
        if isinstance(v, list):
            combo *= len(v)
        else:
            combo *= 1
    total += combo
print(total)
PY
)
case "$check_test" in
  MISSING_JOB) echo "  FAIL job 'test:' not defined"; fail=$((fail+1));;
  MISSING_MATRIX) echo "  FAIL job 'test:' missing parallel.matrix"; fail=$((fail+1));;
  BAD_MATRIX|BAD_ENTRY) echo "  FAIL parallel.matrix malformed"; fail=$((fail+1));;
  ERR) echo "  FAIL could not evaluate parallel.matrix"; fail=$((fail+1));;
  *)
    if [ "$check_test" = "6" ]; then
      echo "  OK   test.parallel.matrix expands to exactly 6 combinations"
    else
      echo "  FAIL test.parallel.matrix expands to $check_test combinations (expected 6)"
      fail=$((fail+1))
    fi
    ;;
esac

# --- 6) test job uses rules: with both if: and changes: ----------------
rules_shape=$(python3 - "$YML" <<'PY' 2>/dev/null || echo "ERR"
import sys, yaml
d = yaml.safe_load(open(sys.argv[1])) or {}
job = d.get("test") or {}
rules = job.get("rules") or []
has_if = any(isinstance(r, dict) and r.get("if") for r in rules)
has_changes = any(isinstance(r, dict) and r.get("changes") for r in rules)
if has_if and has_changes:
    print("BOTH")
elif has_if:
    print("ONLY_IF")
elif has_changes:
    print("ONLY_CHANGES")
else:
    print("NONE")
PY
)
case "$rules_shape" in
  BOTH) echo "  OK   test.rules uses both 'if:' and 'changes:'";;
  ONLY_IF) echo "  FAIL test.rules has 'if:' but no 'changes:'"; fail=$((fail+1));;
  ONLY_CHANGES) echo "  FAIL test.rules has 'changes:' but no 'if:'"; fail=$((fail+1));;
  NONE|ERR) echo "  FAIL test.rules missing or without 'if:'/'changes:'"; fail=$((fail+1));;
esac

# --- 7) matrix uses PY_VERSION and OS_TAG style vars -------------------
vars_ok=$(python3 - "$YML" <<'PY' 2>/dev/null || echo "no"
import sys, yaml
d = yaml.safe_load(open(sys.argv[1])) or {}
job = d.get("test") or {}
mx = ((job.get("parallel") or {}).get("matrix") or [])
keys = set()
for e in mx:
    if isinstance(e, dict):
        keys.update(e.keys())
# at least 2 matrix dimensions
print("yes" if len(keys) >= 2 else "no")
PY
)
if [ "$vars_ok" = "yes" ]; then
  echo "  OK   matrix uses at least 2 dimensions (variables)"
else
  echo "  FAIL matrix should declare at least 2 variables (e.g. PY_VERSION and OS_TAG)"
  fail=$((fail+1))
fi

# --- 8) image: or tags: interpolate a matrix variable ------------------
interp=$(python3 - "$YML" <<'PY' 2>/dev/null || echo "no"
import sys, yaml
d = yaml.safe_load(open(sys.argv[1])) or {}
job = d.get("test") or {}
img = str(job.get("image", ""))
tags = job.get("tags") or []
tags_s = " ".join(str(t) for t in tags) if isinstance(tags, list) else str(tags)
print("yes" if ("$" in img or "$" in tags_s) else "no")
PY
)
if [ "$interp" = "yes" ]; then
  echo "  OK   image: or tags: interpolates a matrix variable (\$...)"
else
  echo "  FAIL image: and tags: do not interpolate matrix variables (\$PY_VERSION / \$OS_TAG)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Compare with solution/.gitlab-ci.yml for autoevaluation.)"
  exit 1
fi
echo "OK: estructura valida. Compara .gitlab-ci.yml con solution/.gitlab-ci.yml para autoevaluarte."
exit 0
