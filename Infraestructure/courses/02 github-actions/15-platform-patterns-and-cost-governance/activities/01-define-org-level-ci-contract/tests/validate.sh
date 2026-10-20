#!/usr/bin/env bash
# Validate structure + presence of the three artifacts of the platform contract.
# Mixed validation: semantic correctness is graded manually against solution/.
#
# No `set -o pipefail`: many checks use `grep -c` / `grep -q` after producers,
# and pipefail would spuriously mark success-on-early-exit as failure (SIGPIPE
# on long producers; and `grep -c` of 0 lines returns 1 under pipefail chains).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ACT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

ADR="${1:-$ACT_DIR/starter/ADR-001-ci-contract.md}"
REUSABLE="${2:-$ACT_DIR/starter/reusable/org-ci-golden-path.yml}"
RULESET="${3:-$ACT_DIR/starter/ruleset.json}"

fail=0

echo "== Validating platform contract artifacts =="
echo "   ADR:      $ADR"
echo "   reusable: $REUSABLE"
echo "   ruleset:  $RULESET"
echo

# ---------------------------------------------------------------------------
# 1) ADR structural checks
# ---------------------------------------------------------------------------
echo "-- ADR --"
if [ ! -f "$ADR" ]; then
  echo "  FAIL ADR file not found at '$ADR'"
  exit 1
fi

required_sections=(
  "# ADR-001: CI/CD Platform Contract"
  "## Status"
  "## Context"
  "## Decision"
  "## Alternatives Considered"
  "## Consequences"
  "## Metrics and SLOs"
  "## Risks and Mitigations"
  "## Review Triggers"
)
for h in "${required_sections[@]}"; do
  if grep -Fxq "$h" "$ADR"; then
    echo "  OK   section present: '$h'"
  else
    echo "  FAIL section missing: '$h'"
    fail=$((fail+1))
  fi
done

# No unresolved TODO markers
todo_count=$(grep -c '^TODO:\|^- TODO\|^[[:space:]]*TODO:' "$ADR" || true)
if [ "$todo_count" -eq 0 ]; then
  echo "  OK   no 'TODO:' markers left in ADR"
else
  echo "  FAIL $todo_count 'TODO:' marker(s) still present in ADR"
  fail=$((fail+1))
fi

# Decision statement
decision_ok=0
for term in \
    "required workflows" \
    "reusable workflows" \
    "golden path" \
    "platform contract"; do
  if grep -Eiq "(adopt|choose|select|decide to use|will use)[^\n]*${term}" "$ADR"; then
    decision_ok=1
    echo "  OK   explicit decision found mentioning: $term"
    break
  fi
done
if [ "$decision_ok" -ne 1 ]; then
  echo "  FAIL no explicit 'We will adopt <pattern>' statement with a valid pattern"
  echo "       (valid: required workflows | reusable workflows | golden path | platform contract)"
  fail=$((fail+1))
fi

# Alternatives >= 2 bullets
alt_section=$(awk '
  /^## Alternatives Considered/ {flag=1; next}
  /^## / && flag {flag=0}
  flag {print}
' "$ADR")
alt_bullets=$(printf "%s\n" "$alt_section" | grep -cE '^-[[:space:]]+' || true)
if [ "$alt_bullets" -ge 2 ]; then
  echo "  OK   Alternatives Considered has $alt_bullets bullets (>=2)"
else
  echo "  FAIL Alternatives Considered needs >=2 bullets, found $alt_bullets"
  fail=$((fail+1))
fi

# Consequences >= 3 bullets
cons_section=$(awk '
  /^## Consequences/ {flag=1; next}
  /^## / && flag {flag=0}
  flag {print}
' "$ADR")
cons_bullets=$(printf "%s\n" "$cons_section" | grep -cE '^-[[:space:]]+' || true)
if [ "$cons_bullets" -ge 3 ]; then
  echo "  OK   Consequences has $cons_bullets bullets (>=3)"
else
  echo "  FAIL Consequences needs >=3 bullets, found $cons_bullets"
  fail=$((fail+1))
fi

# Metrics and SLOs: >=2 bullets AND >=2 numeric thresholds in that section
metrics_section=$(awk '
  /^## Metrics and SLOs/ {flag=1; next}
  /^## / && flag {flag=0}
  flag {print}
' "$ADR")
metrics_bullets=$(printf "%s\n" "$metrics_section" | grep -cE '^-[[:space:]]+' || true)
metrics_numbers=$(printf "%s\n" "$metrics_section" | grep -cE '[0-9]+' || true)
if [ "$metrics_bullets" -ge 2 ] && [ "$metrics_numbers" -ge 2 ]; then
  echo "  OK   Metrics and SLOs has $metrics_bullets bullets + $metrics_numbers numeric lines (>=2 each)"
else
  echo "  FAIL Metrics and SLOs needs >=2 bullets AND >=2 numeric thresholds"
  echo "       (got bullets=$metrics_bullets numeric=$metrics_numbers)"
  fail=$((fail+1))
fi

# Risks >= 2 bullets AND "Mitigation" mentioned >= 2 times
risks_section=$(awk '
  /^## Risks and Mitigations/ {flag=1; next}
  /^## / && flag {flag=0}
  flag {print}
' "$ADR")
risk_bullets=$(printf "%s\n" "$risks_section" | grep -cE '^-[[:space:]]+' || true)
mitig=$(printf "%s\n" "$risks_section" | grep -ciE 'mitigation' || true)
if [ "$risk_bullets" -ge 2 ] && [ "$mitig" -ge 2 ]; then
  echo "  OK   Risks has $risk_bullets risks and $mitig mitigation mentions (>=2 each)"
else
  echo "  FAIL Risks needs >=2 bullets AND >=2 'Mitigation' mentions (got risks=$risk_bullets mitig=$mitig)"
  fail=$((fail+1))
fi

# Review Triggers >= 1 bullet
rev_section=$(awk '
  /^## Review Triggers/ {flag=1; next}
  /^## / && flag {flag=0}
  flag {print}
' "$ADR")
rev_bullets=$(printf "%s\n" "$rev_section" | grep -cE '^-[[:space:]]+' || true)
if [ "$rev_bullets" -ge 1 ]; then
  echo "  OK   Review Triggers has $rev_bullets bullet(s) (>=1)"
else
  echo "  FAIL Review Triggers needs >=1 bullet, found $rev_bullets"
  fail=$((fail+1))
fi

# Word count >= 500
word_count=$(wc -w < "$ADR" | tr -d ' ')
if [ "$word_count" -ge 500 ]; then
  echo "  OK   word count: $word_count (>=500)"
else
  echo "  FAIL word count: $word_count (<500) — develop the ADR further"
  fail=$((fail+1))
fi

# ---------------------------------------------------------------------------
# 2) Reusable workflow checks
# ---------------------------------------------------------------------------
echo
echo "-- Reusable workflow --"
if [ ! -f "$REUSABLE" ]; then
  echo "  FAIL reusable workflow file not found at '$REUSABLE'"
  fail=$((fail+1))
else
  # Parse YAML with python so we validate semantics, not grep patterns.
  python3 - "$REUSABLE" <<'PY'
import sys, re
try:
    import yaml
except ImportError:
    print("  FAIL PyYAML not installed. Run: pip install pyyaml")
    sys.exit(1)

path = sys.argv[1]
raw = open(path).read()
try:
    doc = yaml.safe_load(raw)
except yaml.YAMLError as e:
    print(f"  FAIL reusable YAML invalid: {e}")
    sys.exit(1)

issues = 0

on = doc.get("on") if isinstance(doc, dict) else None
# yaml.safe_load turns `on:` key into Python True in some loader modes; handle both.
if on is None and isinstance(doc, dict):
    on = doc.get(True)
if isinstance(on, dict) and "workflow_call" in on:
    print("  OK   on.workflow_call present")
else:
    print("  FAIL on.workflow_call missing (reusable workflows must declare it)")
    issues += 1

perms = doc.get("permissions") if isinstance(doc, dict) else None
has_perm_job = False
if isinstance(doc.get("jobs"), dict):
    for j in doc["jobs"].values():
        if isinstance(j, dict) and "permissions" in j:
            has_perm_job = True
            break
if perms or has_perm_job:
    print("  OK   permissions declared (workflow or job level)")
else:
    print("  FAIL no 'permissions:' at workflow or job level")
    issues += 1

conc = doc.get("concurrency") if isinstance(doc, dict) else None
if isinstance(conc, dict) and conc.get("group"):
    print("  OK   concurrency with group present")
elif isinstance(conc, str) and conc.strip():
    print("  OK   concurrency (string) present")
else:
    print("  FAIL no 'concurrency.group' at workflow level")
    issues += 1

has_timeout = False
for j in (doc.get("jobs") or {}).values():
    if isinstance(j, dict) and j.get("timeout-minutes") is not None:
        has_timeout = True
        break
if has_timeout:
    print("  OK   at least one job has timeout-minutes")
else:
    print("  FAIL no job declares 'timeout-minutes:'")
    issues += 1

sha_re = re.compile(r"uses:\s*[\w.-]+/[\w./-]+@[0-9a-f]{40}\b")
if sha_re.search(raw):
    print("  OK   at least one action pinned to 40-char SHA")
else:
    print("  FAIL no action pinned to 40-char SHA (uses: owner/repo@<sha40>)")
    issues += 1

sys.exit(1 if issues else 0)
PY
  rc=$?
  if [ "$rc" -ne 0 ]; then
    fail=$((fail+rc))
  fi
fi

# ---------------------------------------------------------------------------
# 3) Ruleset JSON checks
# ---------------------------------------------------------------------------
echo
echo "-- Ruleset JSON --"
if [ ! -f "$RULESET" ]; then
  echo "  FAIL ruleset file not found at '$RULESET'"
  fail=$((fail+1))
else
  python3 - "$RULESET" <<'PY'
import sys, json

path = sys.argv[1]
try:
    data = json.loads(open(path).read())
except json.JSONDecodeError as e:
    print(f"  FAIL ruleset JSON invalid: {e}")
    sys.exit(1)

issues = 0

name = data.get("name") or ""
if isinstance(name, str) and name.strip() and "TODO" not in name:
    print(f"  OK   name present: '{name}'")
else:
    print("  FAIL name missing, empty or still a TODO")
    issues += 1

enf = data.get("enforcement")
if enf in ("active", "evaluate", "disabled"):
    print(f"  OK   enforcement: {enf}")
else:
    print("  FAIL enforcement must be one of: active | evaluate | disabled")
    issues += 1

if data.get("target") == "branch":
    print("  OK   target: branch")
else:
    print("  FAIL target must be 'branch'")
    issues += 1

ref_include = (((data.get("conditions") or {}).get("ref_name") or {}).get("include")) or []
ok_ref = any(
    isinstance(r, str) and (r == "refs/heads/main" or r == "~DEFAULT_BRANCH")
    for r in ref_include
)
if ok_ref:
    print("  OK   conditions.ref_name.include covers main (or ~DEFAULT_BRANCH)")
else:
    print(f"  FAIL conditions.ref_name.include must contain 'refs/heads/main' or '~DEFAULT_BRANCH' (got {ref_include})")
    issues += 1

rules = data.get("rules") or []
wf_rule = next((r for r in rules if r.get("type") == "workflows"), None)
if not wf_rule:
    print("  FAIL rules must contain at least one rule of type 'workflows'")
    issues += 1
else:
    wfs = ((wf_rule.get("parameters") or {}).get("workflows")) or []
    valid = [w for w in wfs
             if isinstance(w, dict)
             and isinstance(w.get("path"), str) and w["path"].endswith(".yml") and "TODO" not in w["path"]
             and isinstance(w.get("ref"), str) and w["ref"].strip() and "TODO" not in w["ref"]]
    if valid:
        print(f"  OK   workflows rule references {len(valid)} valid workflow(s)")
    else:
        print("  FAIL workflows rule needs at least one workflow with non-TODO path (.yml) and ref")
        issues += 1

sys.exit(1 if issues else 0)
PY
  rc=$?
  if [ "$rc" -ne 0 ]; then
    fail=$((fail+rc))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: platform contract (ADR + reusable + ruleset) estructura y presencia verificados."
echo "   Nota: la corrección semántica (defensa oral) se evalúa contra solution/ADR-reference.md."
exit 0
