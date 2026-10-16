#!/usr/bin/env bash
# Structural validation for plat-06-01-build-microservice-template.
# Checks template.yaml + skeleton. Optionally renders a cookiecutter-skeleton/
# analog if the user provides one AND `cookiecutter` is installed; else SKIP.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks use
# `grep -q ... | ...` and short-circuiting on match can produce SIGPIPE (141)
# which would be misread as failure.

set -eu

BASE="${1:-/tmp/plat-06-build}"
TPL="$BASE/template.yaml"
SKEL="$BASE/skeleton"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE does not exist. Copy the starter first."
  exit 1
fi

# ---- template.yaml checks ----
if [ ! -f "$TPL" ]; then
  echo "  FAIL $TPL does not exist"
  fail=$((fail+1))
else
  echo "  OK   template.yaml exists"

  grep -qE '^apiVersion: *scaffolder\.backstage\.io/v1beta3' "$TPL" \
    && echo "  OK   apiVersion is v1beta3" \
    || { echo "  FAIL apiVersion must be scaffolder.backstage.io/v1beta3"; fail=$((fail+1)); }

  grep -qE '^kind: *Template' "$TPL" \
    && echo "  OK   kind: Template" \
    || { echo "  FAIL kind must be Template"; fail=$((fail+1)); }

  grep -qE '^[[:space:]]+name: *python-microservice' "$TPL" \
    && echo "  OK   metadata.name is python-microservice" \
    || { echo "  FAIL metadata.name must be 'python-microservice'"; fail=$((fail+1)); }

  # No TODO leftovers (common offenders — but allow bare 'TODO' word absent)
  if grep -qE 'TODO-rename-me|replace this placeholder step' "$TPL"; then
    echo "  FAIL template.yaml still contains starter placeholders"
    fail=$((fail+1))
  else
    echo "  OK   no obvious starter placeholders in template.yaml"
  fi

  # parameters checks
  grep -q 'pattern:' "$TPL" \
    && echo "  OK   at least one parameter has a 'pattern'" \
    || { echo "  FAIL no 'pattern:' found in parameters (name should have one)"; fail=$((fail+1)); }

  grep -q 'enum:' "$TPL" \
    && echo "  OK   at least one parameter has an 'enum' (environment)" \
    || { echo "  FAIL no 'enum:' found in parameters"; fail=$((fail+1)); }

  grep -qE 'minimum: *1' "$TPL" \
    && echo "  OK   replicas has 'minimum: 1'" \
    || { echo "  FAIL no 'minimum: 1' found (replicas should have one)"; fail=$((fail+1)); }

  grep -q 'OwnerPicker' "$TPL" \
    && echo "  OK   owner uses OwnerPicker widget" \
    || { echo "  FAIL owner should use ui:field: OwnerPicker"; fail=$((fail+1)); }

  # Canonical steps
  for action in 'fetch:template' 'publish:github' 'catalog:register'; do
    if grep -qF "action: $action" "$TPL"; then
      echo "  OK   step uses $action"
    else
      echo "  FAIL step with action '$action' missing"
      fail=$((fail+1))
    fi
  done

  # Conditional step (if:)
  grep -qE '^[[:space:]]+if:' "$TPL" \
    && echo "  OK   has at least one conditional step (if:)" \
    || { echo "  FAIL no conditional step (if:) found"; fail=$((fail+1)); }

  # output.links with at least 2 entries (count '- title:' under output)
  links=$(awk '/^[[:space:]]*output:/{flag=1} flag && /- title:/{c++} END{print c+0}' "$TPL")
  if [ "$links" -ge 2 ]; then
    echo "  OK   output.links has at least 2 entries ($links)"
  else
    echo "  FAIL output.links has only $links entries (expected >=2)"
    fail=$((fail+1))
  fi

  # YAML parse (python3)
  if python3 -c "import yaml,sys; yaml.safe_load(open('$TPL'))" 2>/dev/null; then
    echo "  OK   template.yaml parses as YAML"
  else
    echo "  FAIL template.yaml is not valid YAML"
    fail=$((fail+1))
  fi
fi

# ---- skeleton checks ----
if [ ! -d "$SKEL" ]; then
  echo "  FAIL $SKEL does not exist"
  fail=$((fail+1))
else
  echo "  OK   skeleton/ exists"

  expected=(
    "catalog-info.yaml"
    "README.md"
    "pyproject.toml"
    "chart/values.yaml"
    "docs/index.md"
    "mkdocs.yml"
  )
  for rel in "${expected[@]}"; do
    if [ -f "$SKEL/$rel" ]; then
      echo "  OK   skeleton/$rel exists"
    else
      echo "  FAIL skeleton/$rel missing"
      fail=$((fail+1))
    fi
  done

  # Dynamic-named package dir
  if find "$SKEL/src" -type d -name "{{ values.name*" 2>/dev/null | grep -q .; then
    echo "  OK   skeleton/src/{{ values.name ...}}/ exists (dynamic package dir)"
  else
    echo "  FAIL skeleton/src/{{ values.name | replace('-', '_') }}/ missing"
    fail=$((fail+1))
  fi

  # Placeholder usage
  phcount=$(grep -rhE '\$\{\{[[:space:]]*values\.' "$SKEL" 2>/dev/null | wc -l | tr -d ' ')
  if [ "${phcount:-0}" -ge 5 ]; then
    echo "  OK   skeleton uses \${{ values.* }} placeholders ($phcount occurrences)"
  else
    echo "  FAIL skeleton has only ${phcount:-0} nunjucks placeholders (expected >=5)"
    fail=$((fail+1))
  fi

  # No obvious starter leftovers (literal 'TODO' as a standalone marker on top of a file)
  if grep -rqE '^# TODO|^TODO ' "$SKEL" 2>/dev/null; then
    echo "  FAIL skeleton still has TODO markers"
    fail=$((fail+1))
  else
    echo "  OK   no TODO markers left in skeleton"
  fi
fi

# ---- Optional cookiecutter smoke test ----
CC_JSON="$BASE/cookiecutter.json"
CC_SKEL="$BASE/cookiecutter-skeleton"
if [ -f "$CC_JSON" ] && [ -d "$CC_SKEL" ]; then
  if command -v cookiecutter >/dev/null 2>&1; then
    OUT=$(mktemp -d)
    # cookiecutter expects the template dir to contain cookiecutter.json AND
    # a {{cookiecutter.*}} dir. We stage it:
    STAGE=$(mktemp -d)
    cp "$CC_JSON" "$STAGE/"
    cp -r "$CC_SKEL"/* "$STAGE/" 2>/dev/null || true
    if cookiecutter --no-input -o "$OUT" "$STAGE" >/dev/null 2>&1; then
      echo "  OK   cookiecutter render succeeded"
    else
      echo "  FAIL cookiecutter render failed (check cookiecutter-skeleton/ layout)"
      fail=$((fail+1))
    fi
    rm -rf "$OUT" "$STAGE"
  else
    echo "  SKIP cookiecutter not installed; skipping render smoke test"
  fi
else
  echo "  SKIP cookiecutter-skeleton/ or cookiecutter.json not provided (optional)"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Compare with solution/TEMPLATE.md for semantic review.)"
  exit 1
fi
echo "OK: estructura valida. Compara con solution/TEMPLATE.md para autoevaluarte."
exit 0
