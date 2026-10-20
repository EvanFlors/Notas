#!/usr/bin/env bash
# Structural validation for sec-09-02-verify-in-clean-env.
# Checks that VERIFY-POLICY.md exists and has the 4 required sections,
# the mandatory cosign flags, an anchored identity regex, and the
# verify-attestation --type.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness.
set -eu

BASE="${1:-/tmp/sec-09-02-verify}"
DOC="$BASE/VERIFY-POLICY.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# --- Secciones A/B/C/D ---
if grep -qiE '^#+ *(Secci[óo]n +A|Supuestos)' "$DOC"; then
  echo "  OK   VERIFY-POLICY.md has Section A (Supuestos)"
else
  echo "  FAIL VERIFY-POLICY.md missing Section A (Supuestos)"
  fail=$((fail+1))
fi
if grep -qiE '^#+ *(Secci[óo]n +B|Comando)' "$DOC"; then
  echo "  OK   VERIFY-POLICY.md has Section B (Comando canonico)"
else
  echo "  FAIL VERIFY-POLICY.md missing Section B (Comando canonico)"
  fail=$((fail+1))
fi
if grep -qiE '^#+ *(Secci[óo]n +C|Fallos|Casos)' "$DOC"; then
  echo "  OK   VERIFY-POLICY.md has Section C (Fallos/Casos)"
else
  echo "  FAIL VERIFY-POLICY.md missing Section C (Fallos/Casos)"
  fail=$((fail+1))
fi
if grep -qiE '^#+ *(Secci[óo]n +D|Checklist)' "$DOC"; then
  echo "  OK   VERIFY-POLICY.md has Section D (Checklist)"
else
  echo "  FAIL VERIFY-POLICY.md missing Section D (Checklist)"
  fail=$((fail+1))
fi

# --- cosign verify presente ---
if grep -q 'cosign verify' "$DOC"; then
  echo "  OK   mentions cosign verify"
else
  echo "  FAIL does not mention cosign verify"
  fail=$((fail+1))
fi

# --- flags obligatorios ---
if grep -q -- '--certificate-oidc-issuer' "$DOC"; then
  echo "  OK   uses --certificate-oidc-issuer"
else
  echo "  FAIL missing --certificate-oidc-issuer"
  fail=$((fail+1))
fi

if grep -qE -- '--certificate-identity(-regexp)?' "$DOC"; then
  echo "  OK   uses --certificate-identity[-regexp]"
else
  echo "  FAIL missing --certificate-identity[-regexp]"
  fail=$((fail+1))
fi

# --- regex anclado (si se usa regexp) ---
if grep -q -- '--certificate-identity-regexp' "$DOC"; then
  if grep -qE "'\^.*\\\$'|\"\^.*\\\$\"|=\^.*\\\$" "$DOC"; then
    echo "  OK   regex de identidad parece anclado (^...$)"
  else
    echo "  FAIL regex de identidad sin anclas ^ / $"
    fail=$((fail+1))
  fi
fi

# --- verify-attestation + --type ---
if grep -q 'cosign verify-attestation' "$DOC"; then
  echo "  OK   mentions cosign verify-attestation"
else
  echo "  FAIL does not mention cosign verify-attestation"
  fail=$((fail+1))
fi

if grep -qE -- '--type[= ]+(slsaprovenance1?|cyclonedx|spdxjson|custom)' "$DOC"; then
  echo "  OK   uses --type for attestations"
else
  echo "  FAIL missing --type for attestations"
  fail=$((fail+1))
fi

# --- Rekor / transparency log ---
if grep -qiE 'rekor|transparency' "$DOC"; then
  echo "  OK   mentions Rekor / transparency log"
else
  echo "  FAIL does not mention Rekor / transparency log"
  fail=$((fail+1))
fi

# --- Checklist: al menos 5 ítems numerados en Section D ---
items=0
for n in 1 2 3 4 5; do
  if grep -Eq "^[[:space:]]*${n}\\." "$DOC"; then
    items=$((items+1))
  fi
done
if [ "$items" -ge 5 ]; then
  echo "  OK   checklist tiene al menos 5 items numerados"
else
  echo "  FAIL checklist tiene $items items (expected >=5)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        Compara con solution/REFERENCE.md para autoevaluarte."
  exit 1
fi
echo "OK: estructura valida. Compara VERIFY-POLICY.md con solution/REFERENCE.md."
exit 0
