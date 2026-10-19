#!/usr/bin/env bash
# Structural validation for gl-07-01-review-apps-end-to-end.
# Checks that .gitlab-ci.yml parses as valid YAML and contains the Review
# App canonical pattern (review + stop_review jobs with the right
# environment keys), and that ADR-REVIEW-APPS.md has the required sections
# and keywords.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness in a real GitLab project — compare
# manually with solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/gl-07-01-review-apps}"
CI="$BASE/.gitlab-ci.yml"
ADR="$BASE/ADR-REVIEW-APPS.md"
fail=0

echo "== Structural validation for $BASE =="

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: 'python3' is required but not installed."
  exit 2
fi

if ! python3 -c 'import yaml' >/dev/null 2>&1; then
  echo "FAIL: python3 'yaml' module (pyyaml) is required. Install with: pip install pyyaml"
  exit 2
fi

# --- .gitlab-ci.yml ------------------------------------------------------

if [ ! -f "$CI" ]; then
  echo "  FAIL $CI does not exist"
  fail=$((fail+1))
else
  echo "  OK   $CI exists"

  if python3 -c "import yaml,sys; yaml.safe_load(open('$CI'))" >/dev/null 2>&1; then
    echo "  OK   $CI parses as valid YAML"
  else
    echo "  FAIL $CI is not valid YAML"
    fail=$((fail+1))
  fi

  # Must have a 'review' job with environment.on_stop and name including
  # CI_MERGE_REQUEST_IID.
  review_ok=$(python3 - "$CI" <<'PY' 2>/dev/null || echo "FAIL"
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1]))
if not isinstance(doc, dict):
    print("FAIL"); sys.exit(0)
rev = doc.get("review")
if not isinstance(rev, dict):
    print("FAIL"); sys.exit(0)
env = rev.get("environment")
if not isinstance(env, dict):
    print("FAIL"); sys.exit(0)
name = str(env.get("name", ""))
on_stop = env.get("on_stop")
url = str(env.get("url", ""))
auto_stop = env.get("auto_stop_in")
if "CI_MERGE_REQUEST_IID" not in name:
    print("FAIL"); sys.exit(0)
if on_stop != "stop_review":
    print("FAIL"); sys.exit(0)
if "CI_MERGE_REQUEST_IID" not in url:
    print("FAIL"); sys.exit(0)
if not auto_stop:
    print("FAIL"); sys.exit(0)
print("OK")
PY
)
  if [ "$review_ok" = "OK" ]; then
    echo "  OK   review job: environment.name uses CI_MERGE_REQUEST_IID, on_stop=stop_review, url has IID, auto_stop_in set"
  else
    echo "  FAIL review job missing or misconfigured (needs environment.name with CI_MERGE_REQUEST_IID, on_stop: stop_review, url with CI_MERGE_REQUEST_IID, auto_stop_in)"
    fail=$((fail+1))
  fi

  # Must have a 'stop_review' job with environment.action == stop and the
  # same environment.name as 'review'.
  stop_ok=$(python3 - "$CI" <<'PY' 2>/dev/null || echo "FAIL"
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1]))
if not isinstance(doc, dict):
    print("FAIL"); sys.exit(0)
rev = doc.get("review") or {}
sr = doc.get("stop_review")
if not isinstance(sr, dict):
    print("FAIL"); sys.exit(0)
env = sr.get("environment")
if not isinstance(env, dict):
    print("FAIL"); sys.exit(0)
if env.get("action") != "stop":
    print("FAIL"); sys.exit(0)
rev_env = rev.get("environment") or {}
if env.get("name") != rev_env.get("name"):
    print("FAIL"); sys.exit(0)
print("OK")
PY
)
  if [ "$stop_ok" = "OK" ]; then
    echo "  OK   stop_review job: environment.action=stop and environment.name matches review"
  else
    echo "  FAIL stop_review job missing or misconfigured (needs environment.action: stop and same environment.name as review)"
    fail=$((fail+1))
  fi

  # Must filter review jobs to merge_request_event.
  if grep -q 'merge_request_event' "$CI"; then
    echo "  OK   .gitlab-ci.yml filters to merge_request_event"
  else
    echo "  FAIL .gitlab-ci.yml does not mention merge_request_event (rules should filter MR events)"
    fail=$((fail+1))
  fi
fi

# --- ADR-REVIEW-APPS.md --------------------------------------------------

if [ ! -f "$ADR" ]; then
  echo "  FAIL $ADR does not exist"
  fail=$((fail+1))
else
  echo "  OK   $ADR exists"

  if grep -qiE '^#+ *ADR' "$ADR"; then
    echo "  OK   ADR heading present"
  else
    echo "  FAIL ADR heading missing (expected '# ADR ...')"
    fail=$((fail+1))
  fi

  for section in "Estado|Status" "Contexto|Context" "Decisi[oó]n|Decision" \
                 "Consecuencias|Consequences" "Alternativas|Alternatives"; do
    label="${section%%|*}"
    if grep -qiE "^#+ *(${section})\\b" "$ADR"; then
      echo "  OK   ADR has '${label}' section"
    else
      echo "  FAIL ADR missing '${label}' section"
      fail=$((fail+1))
    fi
  done

  # At least one fenced code block.
  fences=$(grep -cE '^```' "$ADR")
  if [ "$fences" -ge 2 ]; then
    echo "  OK   ADR has at least one fenced code block (${fences} fence lines)"
  else
    echo "  FAIL ADR has only ${fences} fence lines (expected >=2)"
    fail=$((fail+1))
  fi

  # Required keywords in the prose.
  for kw in "Review App" "on_stop" "auto_stop_in" "CI_MERGE_REQUEST_IID"; do
    if grep -q "$kw" "$ADR"; then
      echo "  OK   ADR mentions '${kw}'"
    else
      echo "  FAIL ADR does not mention '${kw}'"
      fail=$((fail+1))
    fi
  done

  # Must compare against GHA / GitHub Actions.
  if grep -qiE 'GitHub +Actions|GHA\b' "$ADR"; then
    echo "  OK   ADR compares against GitHub Actions / GHA"
  else
    echo "  FAIL ADR does not reference GitHub Actions / GHA as alternative"
    fail=$((fail+1))
  fi

  # Alternatives: at least 2 sub-headings or numbered items.
  alt_items=$(grep -cEi '^#+ +(Alt|Opci[oó]n|Alternativa)' "$ADR" || true)
  alt_num=$(grep -cE '^[[:space:]]*[12]\. ' "$ADR" || true)
  if [ "$alt_items" -ge 2 ] || [ "$alt_num" -ge 2 ]; then
    echo "  OK   ADR has at least 2 alternatives listed"
  else
    echo "  FAIL ADR has fewer than 2 alternatives (expected >=2 sub-headings or numbered items)"
    fail=$((fail+1))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail issue(s) found."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: 0 issue(s). Compara con solution/REFERENCE.md para autoevaluarte."
exit 0
