#!/usr/bin/env bash
# Structural validation for plat-08-02-write-minimal-custom-plugin.
# Checks that the custom-plugin skeleton at $BASE has the expected files,
# package.json includes required markers, src/plugin.ts uses the Backstage
# plugin APIs, and the component imports from @backstage/core-components.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT run `yarn install`, `tsc` or `jest`. If node/yarn/backstage-cli
# are missing, tool-dependent checks are SKIPped gracefully.

set -eu

BASE="${1:-/tmp/plat-08-plugin}"
fail=0
skipped=0

echo "== Structural validation for $BASE =="

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE does not exist. Student must create the skeleton."
  exit 1
fi

# --- Required files -----------------------------------------------------
for f in \
  "package.json" \
  "TEMPLATE.md" \
  "src/index.ts" \
  "src/plugin.ts" \
  "src/routes.ts" \
  "src/components/ServiceHealthCard/ServiceHealthCard.tsx" \
  "src/components/ServiceHealthCard/index.ts" \
; do
  if [ -f "$BASE/$f" ]; then
    echo "  OK   $f exists"
  else
    echo "  FAIL $f missing"
    fail=$((fail+1))
  fi
done

# Guard against ANALYSIS.md naming (project convention: REFERENCE.md / TEMPLATE.md).
if [ -f "$BASE/ANALYSIS.md" ]; then
  echo "  FAIL $BASE/ANALYSIS.md present — rename to TEMPLATE.md (project convention)"
  fail=$((fail+1))
fi

# --- package.json content ----------------------------------------------
PKG="$BASE/package.json"
if [ -f "$PKG" ]; then
  # Validate JSON syntax if python3 is available (always true on macOS/Linux).
  if command -v python3 >/dev/null 2>&1; then
    if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$PKG" >/dev/null 2>&1; then
      echo "  OK   package.json is valid JSON"
    else
      echo "  FAIL package.json is not valid JSON"
      fail=$((fail+1))
    fi
  else
    echo "  SKIP python3 missing — cannot JSON-validate package.json"
    skipped=$((skipped+1))
  fi

  if grep -q '"role"[[:space:]]*:[[:space:]]*"frontend-plugin"' "$PKG"; then
    echo "  OK   package.json declares backstage.role=frontend-plugin"
  else
    echo "  FAIL package.json missing backstage.role=frontend-plugin"
    fail=$((fail+1))
  fi

  if grep -q '"peerDependencies"' "$PKG" && grep -q '"react"' "$PKG"; then
    echo "  OK   package.json has peerDependencies with react"
  else
    echo "  FAIL package.json missing peerDependencies / react"
    fail=$((fail+1))
  fi

  for s in '"start"' '"build"' '"test"'; do
    if grep -q "$s" "$PKG"; then
      echo "  OK   package.json has script $s"
    else
      echo "  FAIL package.json missing script $s"
      fail=$((fail+1))
    fi
  done
fi

# --- src/plugin.ts content ---------------------------------------------
PLG="$BASE/src/plugin.ts"
if [ -f "$PLG" ]; then
  if grep -q "@backstage/core-plugin-api" "$PLG"; then
    echo "  OK   src/plugin.ts imports from @backstage/core-plugin-api"
  else
    echo "  FAIL src/plugin.ts does not import @backstage/core-plugin-api"
    fail=$((fail+1))
  fi
  if grep -q "createPlugin" "$PLG"; then
    echo "  OK   src/plugin.ts uses createPlugin"
  else
    echo "  FAIL src/plugin.ts does not use createPlugin"
    fail=$((fail+1))
  fi
  if grep -q "createRoutableExtension" "$PLG"; then
    echo "  OK   src/plugin.ts uses createRoutableExtension"
  else
    echo "  FAIL src/plugin.ts does not use createRoutableExtension"
    fail=$((fail+1))
  fi
fi

# --- src/routes.ts content ---------------------------------------------
RTS="$BASE/src/routes.ts"
if [ -f "$RTS" ]; then
  if grep -q "createRouteRef" "$RTS"; then
    echo "  OK   src/routes.ts uses createRouteRef"
  else
    echo "  FAIL src/routes.ts does not use createRouteRef"
    fail=$((fail+1))
  fi
fi

# --- Component content -------------------------------------------------
CMP="$BASE/src/components/ServiceHealthCard/ServiceHealthCard.tsx"
if [ -f "$CMP" ]; then
  if grep -q "@backstage/core-components" "$CMP"; then
    echo "  OK   ServiceHealthCard.tsx imports from @backstage/core-components"
  else
    echo "  FAIL ServiceHealthCard.tsx does not import @backstage/core-components"
    fail=$((fail+1))
  fi
  if grep -qE "Page|Header|Content" "$CMP"; then
    echo "  OK   ServiceHealthCard.tsx uses Page/Header/Content"
  else
    echo "  FAIL ServiceHealthCard.tsx does not use Page/Header/Content"
    fail=$((fail+1))
  fi
  if grep -q "import React" "$CMP" || grep -q "from 'react'" "$CMP"; then
    echo "  OK   ServiceHealthCard.tsx imports React"
  else
    echo "  FAIL ServiceHealthCard.tsx does not import React"
    fail=$((fail+1))
  fi
fi

# --- TEMPLATE.md content ----------------------------------------------
TPL="$BASE/TEMPLATE.md"
if [ -f "$TPL" ]; then
  if grep -qE "App\.tsx|packages/app" "$TPL"; then
    echo "  OK   TEMPLATE.md mentions App.tsx / packages/app"
  else
    echo "  FAIL TEMPLATE.md does not mention App.tsx / packages/app"
    fail=$((fail+1))
  fi
  if grep -qiE "proxy|discoveryapi|discovery api" "$TPL"; then
    echo "  OK   TEMPLATE.md discusses proxy / discoveryApi"
  else
    echo "  FAIL TEMPLATE.md does not discuss proxy nor discoveryApi"
    fail=$((fail+1))
  fi
fi

# --- Tool-dependent checks (SKIP gracefully) --------------------------
if command -v node >/dev/null 2>&1; then
  node_ver="$(node --version 2>/dev/null || echo unknown)"
  echo "  OK   node present ($node_ver)"
else
  echo "  SKIP node missing — real plugin would need node >=18"
  skipped=$((skipped+1))
fi

if command -v yarn >/dev/null 2>&1; then
  echo "  OK   yarn present"
else
  echo "  SKIP yarn missing — install to run 'yarn new --select plugin'"
  skipped=$((skipped+1))
fi

if command -v backstage-cli >/dev/null 2>&1; then
  echo "  OK   backstage-cli present"
else
  echo "  SKIP backstage-cli missing — scaffolding walkthrough is documented only"
  skipped=$((skipped+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed, $skipped skipped."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/)."
  exit 1
fi
echo "OK: estructura valida ($skipped tool-dependent check(s) skipped). Compara con solution/."
exit 0
