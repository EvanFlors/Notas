#!/usr/bin/env bash
# Validador estructural para cap-12-02-kyverno-verify-signed-images.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks pipe
# into `grep -q`, which exits as soon as the match is found and causes
# SIGPIPE (exit 141) in the upstream command; pipefail would flag that
# as a spurious failure.
set -eu

BASE="${1:-/tmp/cap-12-02}"
POLICY="$BASE/verify-images.yaml"
NOTES="$BASE/NOTES.md"
fail=0

echo "== Validando cap-12-02 en $BASE =="

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE no existe. Copia starter/ ahi primero." >&2
  exit 1
fi
for f in "$POLICY" "$NOTES"; do
  [ -f "$f" ] || { echo "  FAIL $f no existe"; fail=$((fail+1)); }
done
[ "$fail" -gt 0 ] && { echo "RESULT: $fail falla(s)."; exit 1; }

# YAML parse.
if command -v python3 >/dev/null 2>&1; then
  if python3 -c "import yaml; yaml.safe_load(open('$POLICY'))" >/dev/null 2>&1; then
    echo "  OK   verify-images.yaml parsea"
  else
    echo "  FAIL verify-images.yaml no parsea"
    fail=$((fail+1))
  fi
fi

# Required keys / values.
grep -q 'kind:[[:space:]]*ClusterPolicy' "$POLICY" \
  && echo "  OK   kind=ClusterPolicy" \
  || { echo "  FAIL kind no es ClusterPolicy"; fail=$((fail+1)); }

grep -q 'validationFailureAction:[[:space:]]*Enforce' "$POLICY" \
  && echo "  OK   validationFailureAction=Enforce" \
  || { echo "  FAIL falta validationFailureAction: Enforce"; fail=$((fail+1)); }

grep -q 'verifyImages:' "$POLICY" \
  && echo "  OK   verifyImages presente" \
  || { echo "  FAIL verifyImages ausente"; fail=$((fail+1)); }

grep -q 'keyless:' "$POLICY" \
  && echo "  OK   keyless presente" \
  || { echo "  FAIL attestors.keyless ausente"; fail=$((fail+1)); }

grep -q 'token.actions.githubusercontent.com' "$POLICY" \
  && echo "  OK   issuer de GHA OIDC" \
  || { echo "  FAIL issuer no es el de GHA OIDC"; fail=$((fail+1)); }

grep -qE 'subject:.*\.github/workflows/.*\.yml' "$POLICY" \
  && echo "  OK   subject apunta a un workflow .yml" \
  || { echo "  FAIL subject no apunta a un workflow"; fail=$((fail+1)); }

grep -q 'mutateDigest:[[:space:]]*true' "$POLICY" \
  && echo "  OK   mutateDigest=true" \
  || { echo "  FAIL mutateDigest != true"; fail=$((fail+1)); }

if grep -q 'TODO' "$POLICY"; then
  echo "  FAIL verify-images.yaml aun tiene TODOs"
  fail=$((fail+1))
fi

# NOTES.md menciona Audit y Enforce.
grep -qi 'audit' "$NOTES" && grep -qi 'enforce' "$NOTES" \
  && echo "  OK   NOTES.md menciona Audit y Enforce" \
  || { echo "  FAIL NOTES.md no menciona Audit o Enforce"; fail=$((fail+1)); }

# Si kyverno CLI esta instalado, correrlo offline.
if command -v kyverno >/dev/null 2>&1; then
  if [ -f "$BASE/tests/kyverno-test.yaml" ]; then
    if kyverno test "$BASE/" >/dev/null 2>&1; then
      echo "  OK   kyverno test paso"
    else
      echo "  WARN kyverno test fallo (revisa tus casos)"
    fi
  else
    echo "  WARN no hay tests/kyverno-test.yaml; recomendado"
  fi
else
  echo "  INFO kyverno CLI no instalado; skip kyverno test"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) fallaron."
  exit 1
fi
echo "OK."
exit 0
