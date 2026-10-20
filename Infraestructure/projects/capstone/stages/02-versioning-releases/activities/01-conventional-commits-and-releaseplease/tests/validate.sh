#!/usr/bin/env bash
# Validate cap-02-01-conventional-commits-and-releaseplease.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks use
# patterns like `grep -q` on JSON/YAML dumps; if grep matches early, the
# upstream pipeline step may receive SIGPIPE (exit 141), and pipefail would
# turn that into a false negative.
set -eu

WORK="${1:-${WORK_DIR:-/tmp/cap-02-01}}"
HERE="$(cd "$(dirname "$0")" && pwd)"

passed=0
failed=0
report=""

ok()  { report="${report}  OK   $1"$'\n'; passed=$((passed+1)); }
bad() { report="${report}  FAIL $1"$'\n'; failed=$((failed+1)); }

echo "== Validando $WORK =="

if [ ! -d "$WORK" ]; then
  echo "FAIL: no existe $WORK. Copia starter/ a $WORK y completa la actividad."
  exit 1
fi

cd "$WORK"

# --- 1. Archivos esperados ---
for f in \
    release-please-config.json \
    .release-please-manifest.json \
    commitlint.config.js \
    .gitmessage \
    CHANGELOG.md \
    .github/workflows/release-please.yml \
    .husky/commit-msg
do
  if [ -e "$f" ]; then
    ok "existe $f"
  else
    bad "falta $f"
  fi
done

# --- 2. husky commit-msg ejecutable ---
if [ -x .husky/commit-msg ]; then
  ok ".husky/commit-msg es ejecutable"
else
  bad ".husky/commit-msg no es ejecutable (chmod +x .husky/commit-msg)"
fi

# --- 3. release-please-config.json parsea y tiene release-type ---
if python3 -c "import json; d=json.load(open('release-please-config.json')); assert d.get('release-type')" 2>/dev/null; then
  ok "release-please-config.json valido y con release-type"
else
  bad "release-please-config.json invalido o sin release-type"
fi

# --- 4. manifest parsea y tiene exactamente una entrada ---
if python3 -c "import json; d=json.load(open('.release-please-manifest.json')); assert len(d)==1" 2>/dev/null; then
  ok ".release-please-manifest.json tiene una entrada"
else
  bad ".release-please-manifest.json invalido o con != 1 entrada"
fi

# --- 5. commitlint.config.js extiende config-conventional ---
if grep -q "@commitlint/config-conventional" commitlint.config.js; then
  ok "commitlint extiende @commitlint/config-conventional"
else
  bad "commitlint.config.js no extiende @commitlint/config-conventional"
fi

# --- 6. workflow usa release-please-action ---
if grep -q "googleapis/release-please-action" .github/workflows/release-please.yml; then
  ok "workflow usa googleapis/release-please-action"
else
  bad "workflow no referencia googleapis/release-please-action"
fi

# --- 7. CHANGELOG tiene cabecera ---
if head -1 CHANGELOG.md | grep -qi "^# changelog"; then
  ok "CHANGELOG.md tiene cabecera '# Changelog'"
else
  bad "CHANGELOG.md sin cabecera '# Changelog'"
fi

# --- 8. .gitmessage menciona BREAKING CHANGE ---
if grep -q "BREAKING CHANGE" .gitmessage; then
  ok ".gitmessage documenta BREAKING CHANGE"
else
  bad ".gitmessage no menciona BREAKING CHANGE"
fi

# --- 9. notas-releases.md con contenido minimo ---
if [ -f notas-releases.md ] && [ "$(wc -c < notas-releases.md)" -gt 200 ]; then
  ok "notas-releases.md presente y con contenido"
else
  bad "falta notas-releases.md o esta vacio"
fi

# --- 10. Smoke test idempotente (dos corridas) ---
if bash "$HERE/smoke.sh" "$WORK" >/dev/null 2>&1; then
  ok "smoke #1 pasa"
else
  bad "smoke #1 falla"
fi
if bash "$HERE/smoke.sh" "$WORK" >/dev/null 2>&1; then
  ok "smoke #2 pasa (idempotente)"
else
  bad "smoke #2 falla (no idempotente)"
fi

printf '%s' "$report"
echo "----"
echo "PASS: $passed   FAIL: $failed"
if [ "$failed" -eq 0 ]; then
  echo "RESULT: PASS"
  exit 0
else
  echo "RESULT: FAIL"
  exit 1
fi
