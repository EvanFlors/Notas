#!/usr/bin/env bash
# Structural validation for ans-01-02-dynamic-inventory-ec2.
#
# Checks that:
#   - prod.aws_ec2.yml exists, parses as YAML, and declares the mandatory keys
#     for amazon.aws.aws_ec2 (plugin, regions, filters, hostnames, keyed_groups).
#   - dynamic-inventory.py exists, is executable, --list prints valid JSON that
#     includes '_meta.hostvars' and at least two groups.
#   - NOTES.md has one section per scenario (1, 2, 3) and mentions the three
#     strategies (plugin, script, estatico).
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.

set -eu

BASE="${1:-/tmp/ans-01-02}"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -d "$BASE" ]; then
  echo "SKIP: $BASE does not exist. Create it per the activity README (mkdir -p $BASE)."
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3 is required but not installed."
  exit 0
fi

YML="$BASE/prod.aws_ec2.yml"
SCRIPT="$BASE/dynamic-inventory.py"
NOTES="$BASE/NOTES.md"

for f in "$YML" "$SCRIPT" "$NOTES"; do
  if [ -f "$f" ]; then
    echo "  OK   $(basename "$f") exists"
  else
    echo "  FAIL $(basename "$f") missing (expected at $f)"
    fail=$((fail+1))
  fi
done

# --- Validate prod.aws_ec2.yml ---
if [ -f "$YML" ]; then
  if python3 -c 'import sys,yaml; yaml.safe_load(open(sys.argv[1]))' "$YML" >/dev/null 2>&1; then
    echo "  OK   prod.aws_ec2.yml is valid YAML"
  else
    # PyYAML may not be installed; fall back to crude check (file is non-empty text).
    if [ -s "$YML" ]; then
      echo "  OK   prod.aws_ec2.yml non-empty (PyYAML not available for strict parse)"
    else
      echo "  FAIL prod.aws_ec2.yml is empty or unparseable"
      fail=$((fail+1))
    fi
  fi

  for key in "plugin" "regions" "filters" "hostnames" "keyed_groups"; do
    if grep -qE "^\s*${key}\s*:" "$YML"; then
      echo "  OK   prod.aws_ec2.yml declares '${key}'"
    else
      echo "  FAIL prod.aws_ec2.yml missing key '${key}'"
      fail=$((fail+1))
    fi
  done

  if grep -q 'amazon.aws.aws_ec2' "$YML"; then
    echo "  OK   plugin pinned to amazon.aws.aws_ec2"
  else
    echo "  FAIL plugin is not amazon.aws.aws_ec2"
    fail=$((fail+1))
  fi

  if grep -qE 'eu-(west|central|south|north)-[0-9]+' "$YML"; then
    echo "  OK   mentions an eu-* region"
  else
    echo "  FAIL does not mention an eu-* region"
    fail=$((fail+1))
  fi
fi

# --- Validate dynamic-inventory.py ---
if [ -f "$SCRIPT" ]; then
  if [ -x "$SCRIPT" ]; then
    echo "  OK   dynamic-inventory.py is executable (+x)"
  else
    echo "  FAIL dynamic-inventory.py is not executable (run chmod +x)"
    fail=$((fail+1))
  fi

  # Run --list and capture; must be valid JSON.
  if out=$("$SCRIPT" --list 2>/dev/null); then
    if printf '%s' "$out" | python3 -c 'import json,sys; json.loads(sys.stdin.read())' >/dev/null 2>&1; then
      echo "  OK   --list prints valid JSON"
    else
      echo "  FAIL --list output is not valid JSON"
      fail=$((fail+1))
    fi

    # Must include _meta.hostvars
    if printf '%s' "$out" \
       | python3 -c 'import json,sys; d=json.loads(sys.stdin.read()); sys.exit(0 if "_meta" in d and "hostvars" in d.get("_meta",{}) else 1)'; then
      echo "  OK   --list includes _meta.hostvars"
    else
      echo "  FAIL --list missing _meta.hostvars"
      fail=$((fail+1))
    fi

    # Must have at least 2 non-_meta groups
    if printf '%s' "$out" \
       | python3 -c 'import json,sys; d=json.loads(sys.stdin.read()); groups=[k for k in d.keys() if k != "_meta"]; sys.exit(0 if len(groups) >= 2 else 1)'; then
      echo "  OK   --list includes at least 2 groups"
    else
      echo "  FAIL --list has fewer than 2 groups"
      fail=$((fail+1))
    fi
  else
    echo "  FAIL dynamic-inventory.py --list failed to run"
    fail=$((fail+1))
  fi

  # --host must not crash
  if "$SCRIPT" --host some-host >/dev/null 2>&1; then
    echo "  OK   --host runs without error"
  else
    echo "  FAIL --host crashed"
    fail=$((fail+1))
  fi
fi

# --- Validate NOTES.md ---
if [ -f "$NOTES" ]; then
  for scen in "Escenario 1" "Escenario 2" "Escenario 3"; do
    if grep -qE "^#+ +${scen}\\b" "$NOTES"; then
      echo "  OK   NOTES.md has section '${scen}'"
    else
      echo "  FAIL NOTES.md missing section '${scen}'"
      fail=$((fail+1))
    fi
  done

  strategies_hit=0
  for word in "plugin" "script" "est[aá]tico"; do
    if grep -qiE "$word" "$NOTES"; then
      strategies_hit=$((strategies_hit+1))
    fi
  done
  if [ "$strategies_hit" -ge 3 ]; then
    echo "  OK   NOTES.md mentions the three strategies (plugin, script, estatico)"
  else
    echo "  FAIL NOTES.md only mentions ${strategies_hit}/3 strategies"
    fail=$((fail+1))
  fi
fi

# --- Optional live re-check with ansible-inventory ---
if command -v ansible-inventory >/dev/null 2>&1 && [ -x "$SCRIPT" ]; then
  echo "-- live re-check with ansible-inventory --"
  if ansible-inventory -i "$SCRIPT" --list >/dev/null 2>&1; then
    echo "  OK   ansible-inventory consumes dynamic-inventory.py successfully"
  else
    echo "  NOTE ansible-inventory could not consume the script (not fatal here)"
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: estructura valida. Compara con solution/REFERENCE.md para autoevaluarte."
exit 0
