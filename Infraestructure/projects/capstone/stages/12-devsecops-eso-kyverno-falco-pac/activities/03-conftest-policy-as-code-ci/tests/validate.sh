#!/usr/bin/env bash
# Validador para cap-12-03-conftest-policy-as-code-ci.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks pipe
# into `grep -q`, which exits as soon as it finds a match and emits SIGPIPE
# (exit 141) in the upstream command; pipefail would mark that as failure.
set -eu

BASE="${1:-/tmp/cap-12-03}"
REGO="$BASE/policies/no_privileged.rego"
BAD="$BASE/fixtures/bad.yaml"
GOOD="$BASE/fixtures/good.yaml"
fail=0

echo "== Validando cap-12-03 en $BASE =="

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE no existe. Copia starter/ ahi primero." >&2
  exit 1
fi
for f in "$REGO" "$BAD" "$GOOD"; do
  [ -f "$f" ] || { echo "  FAIL $f no existe"; fail=$((fail+1)); }
done
[ "$fail" -gt 0 ] && { echo "RESULT: $fail falla(s)."; exit 1; }

# package main en todas las policies.
for f in "$BASE"/policies/*.rego; do
  if grep -q '^package main' "$f"; then
    echo "  OK   $(basename "$f") declara package main"
  else
    echo "  FAIL $(basename "$f") no declara package main"
    fail=$((fail+1))
  fi
done

# Bug conocido: el starter tenia `pod_spec.volumes[0].hostPath`. Debe desaparecer.
if grep -q 'volumes\[0\]' "$REGO"; then
  echo "  FAIL no_privileged.rego aun indexa volumes[0] (bug no corregido)"
  fail=$((fail+1))
else
  echo "  OK   no_privileged.rego ya no indexa volumes[0]"
fi

# Debe iterar: `some v in pod_spec.volumes` (o `volumes[_]`).
if grep -Eq 'some[[:space:]]+[a-zA-Z_]+[[:space:]]+in[[:space:]]+pod_spec\.volumes|pod_spec\.volumes\[_\]' "$REGO"; then
  echo "  OK   no_privileged.rego itera sobre volumes"
else
  echo "  FAIL no_privileged.rego no itera sobre volumes correctamente"
  fail=$((fail+1))
fi

# opa test si esta.
if command -v opa >/dev/null 2>&1; then
  if opa test "$BASE/policies" -v >/dev/null 2>&1; then
    echo "  OK   opa test paso"
  else
    echo "  FAIL opa test fallo"
    fail=$((fail+1))
  fi
else
  echo "  INFO opa no instalado; skip opa test"
fi

# conftest si esta.
if command -v conftest >/dev/null 2>&1; then
  if conftest test "$GOOD" -p "$BASE/policies" >/dev/null 2>&1; then
    echo "  OK   conftest acepta good.yaml"
  else
    echo "  FAIL conftest rechaza good.yaml (falso positivo)"
    fail=$((fail+1))
  fi
  if conftest test "$BAD" -p "$BASE/policies" >/dev/null 2>&1; then
    echo "  FAIL conftest acepta bad.yaml (falso negativo)"
    fail=$((fail+1))
  else
    echo "  OK   conftest rechaza bad.yaml"
  fi
else
  echo "  INFO conftest no instalado; skip conftest test"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) fallaron."
  exit 1
fi
echo "OK."
exit 0
