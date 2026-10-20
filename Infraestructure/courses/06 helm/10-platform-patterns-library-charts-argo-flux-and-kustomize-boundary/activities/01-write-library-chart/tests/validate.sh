#!/usr/bin/env bash
# Validate the library-chart activity. Default target is `starter/`; override
# with the first argument to point at `solution/` or any other working copy.
# We deliberately do NOT enable `set -o pipefail`: several checks use pipes
# with `grep -q`, which closes the pipe early on first match. pipefail would
# mark upstream producers as spuriously failed.
set -eu

here="$(cd "$(dirname "$0")" && pwd)"
target="${1:-$here/../starter}"
target="$(cd "$target" && pwd)"

echo "== Validating helm-10-01-write-library-chart at $target =="

fail=0

step() { echo "-- $*"; }
ok()   { echo "  OK   $*"; }
bad()  { echo "  FAIL $*"; fail=$((fail+1)); }

# 1. platform-lib/Chart.yaml declares type: library.
step "platform-lib Chart.yaml"
if [ -f "$target/platform-lib/Chart.yaml" ]; then
  if grep -Eq '^type:[[:space:]]*library[[:space:]]*$' "$target/platform-lib/Chart.yaml"; then
    ok "platform-lib declares type: library"
  else
    bad "platform-lib/Chart.yaml must set 'type: library'"
  fi
  if grep -Eq '^name:[[:space:]]*platform-lib[[:space:]]*$' "$target/platform-lib/Chart.yaml"; then
    ok "platform-lib name is 'platform-lib'"
  else
    bad "platform-lib/Chart.yaml must have 'name: platform-lib'"
  fi
else
  bad "missing $target/platform-lib/Chart.yaml"
fi

# 2. _helpers.tpl defines the four blocks.
step "_helpers.tpl define blocks"
helpers="$target/platform-lib/templates/_helpers.tpl"
if [ -f "$helpers" ]; then
  if grep -q 'TODO' "$helpers"; then
    bad "_helpers.tpl still contains 'TODO' markers"
  else
    ok "_helpers.tpl has no 'TODO' markers"
  fi
  for name in platform.name platform.fullname platform.labels platform.selectorLabels; do
    if grep -q "define \"$name\"" "$helpers"; then
      ok "define \"$name\" present"
    else
      bad "define \"$name\" missing"
    fi
  done
else
  bad "missing $helpers"
fi

# 3. demo-app/Chart.yaml depends on platform-lib via file://.
step "demo-app dependency declaration"
demo_chart="$target/demo-app/Chart.yaml"
if [ -f "$demo_chart" ]; then
  if grep -q 'name:[[:space:]]*platform-lib' "$demo_chart" \
     && grep -q 'repository:[[:space:]]*"file://\.\./platform-lib"' "$demo_chart"; then
    ok "demo-app depends on platform-lib via file://"
  else
    bad "demo-app/Chart.yaml must list platform-lib with repository \"file://../platform-lib\""
  fi
else
  bad "missing $demo_chart"
fi

# 4. demo-app/templates/deployment.yaml uses include + nindent.
step "demo-app deployment uses helpers"
dep="$target/demo-app/templates/deployment.yaml"
if [ -f "$dep" ]; then
  if grep -q 'TODO' "$dep"; then
    bad "demo-app/templates/deployment.yaml still contains 'TODO'"
  else
    ok "demo-app/templates/deployment.yaml has no 'TODO'"
  fi
  if grep -q 'include "platform.fullname"' "$dep"; then
    ok "deployment uses include \"platform.fullname\""
  else
    bad "deployment must use include \"platform.fullname\" for metadata.name"
  fi
  if grep -q 'include "platform.labels"' "$dep" && grep -q 'nindent' "$dep"; then
    ok "deployment uses include \"platform.labels\" piped to nindent"
  else
    bad "deployment must use include \"platform.labels\" piped to nindent"
  fi
else
  bad "missing $dep"
fi

# 5. helm dependency build must succeed.
step "helm dependency build"
if command -v helm >/dev/null 2>&1; then
  if (cd "$target" && helm dependency build ./demo-app >/dev/null 2>&1); then
    ok "helm dependency build demo-app"
  else
    bad "helm dependency build failed — see 'helm dependency build $target/demo-app'"
  fi
else
  bad "helm binary not found on PATH"
fi

# 6. library chart produces no manifests.
step "library chart renders nothing"
if command -v helm >/dev/null 2>&1; then
  rendered=$(helm template probe "$target/platform-lib" 2>/dev/null || true)
  if [ -z "$(printf '%s' "$rendered" | tr -d '[:space:]')" ]; then
    ok "platform-lib renders no manifests on its own"
  else
    bad "platform-lib produced manifests — not acting as a library chart"
  fi
fi

# 7. Consumer renders successfully with expected labels/name.
step "helm template consumer"
if command -v helm >/dev/null 2>&1; then
  if out=$(helm template demo "$target/demo-app" 2>&1); then
    ok "helm template demo demo-app succeeded"
    if printf '%s\n' "$out" | grep -q 'app.kubernetes.io/managed-by: Helm'; then
      ok "rendered output contains managed-by label"
    else
      bad "rendered output missing 'app.kubernetes.io/managed-by: Helm'"
    fi
    if printf '%s\n' "$out" | grep -q 'platform.example.com/owner:'; then
      ok "rendered output contains platform.example.com/owner label"
    else
      bad "rendered output missing 'platform.example.com/owner' label"
    fi
    if printf '%s\n' "$out" | grep -q 'name: demo-demo-app'; then
      ok "rendered name is 'demo-demo-app' (platform.fullname works)"
    else
      bad "rendered deployment name should be 'demo-demo-app' (release=demo + chart=demo-app)"
    fi
  else
    bad "helm template failed — output:\n$out"
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: library-chart activity validation passed."
