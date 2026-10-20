#!/usr/bin/env bash
# Structural validation for sec-02-02-rotation-policy-adr.
# Checks that ADR-rotation.md exists and contains the canonical ADR sections
# (Status, Context, Decision, Consequences, Alternatives considered, References),
# a TTL-by-family table, break-glass + SoD language, and >=3 alternatives.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/sec-02-adr}"
DOC="$BASE/ADR-rotation.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Required ADR sections.
for section in "Status" "Context" "Decision" "Consequences" "Alternatives" "References"; do
  if grep -qiE "^#+ *${section}" "$DOC"; then
    echo "  OK   has section '${section}'"
  else
    echo "  FAIL missing section '${section}'"
    fail=$((fail+1))
  fi
done

# Table must have at least 5 TTL rows: look for pipes '|' at least 7 times
# (header + separator + 5 rows = 7 lines starting with '|').
rows=$(grep -cE '^\|' "$DOC")
if [ "$rows" -ge 7 ]; then
  echo "  OK   TTL table has at least 5 rows ($rows pipe-lines found)"
else
  echo "  FAIL TTL table has only $rows pipe-lines (expected >=7)"
  fail=$((fail+1))
fi

# TTL column must exist.
if grep -qiE 'ttl' "$DOC"; then
  echo "  OK   mentions TTL"
else
  echo "  FAIL does not mention TTL"
  fail=$((fail+1))
fi

# Mechanism of rotation must be present (TTL expiration, dual-write, atomic, blue-green, ACME, keyless).
if grep -qiE 'expiration|dual[- ]?write|atomic|blue[- ]?green|acme|keyless'  "$DOC"; then
  echo "  OK   mentions a rotation mechanism"
else
  echo "  FAIL does not mention a rotation mechanism (expiration/dual-write/atomic/blue-green/ACME/keyless)"
  fail=$((fail+1))
fi

# Must mention at least 3 families.
families=0
for f in "api-key" "db-cred" "oauth" "cert" "ssh" "signing" "encryption"; do
  if grep -qi "$f" "$DOC"; then
    families=$((families+1))
  fi
done
if [ "$families" -ge 3 ]; then
  echo "  OK   mentions at least 3 secret families ($families found)"
else
  echo "  FAIL mentions only $families secret families (expected >=3)"
  fail=$((fail+1))
fi

# Break-glass language required.
if grep -qiE 'break[- ]?glass' "$DOC"; then
  echo "  OK   mentions break-glass procedure"
else
  echo "  FAIL does not mention break-glass"
  fail=$((fail+1))
fi

# Separation of duties required.
if grep -qiE 'separation of duties|sod' "$DOC"; then
  echo "  OK   mentions separation of duties / SoD"
else
  echo "  FAIL does not mention separation of duties / SoD"
  fail=$((fail+1))
fi

# Audit language required.
if grep -qi 'audit' "$DOC"; then
  echo "  OK   mentions audit"
else
  echo "  FAIL does not mention audit"
  fail=$((fail+1))
fi

# At least 3 alternatives considered (numbered or bullet list).
alts=0
for n in 1 2 3; do
  if grep -Eq "^[[:space:]]*${n}\\." "$DOC"; then
    alts=$((alts+1))
  fi
done
if [ "$alts" -ge 3 ]; then
  echo "  OK   has at least 3 numbered alternatives"
else
  # Fallback: count 'Alternativa' or 'Alternative' entries.
  alt_entries=$(grep -cEi 'alternativa|alternative:' "$DOC" || true)
  if [ "$alt_entries" -ge 3 ]; then
    echo "  OK   has at least 3 alternative entries ($alt_entries found)"
  else
    echo "  FAIL has fewer than 3 alternatives considered (numbered or named)"
    fail=$((fail+1))
  fi
fi

# Short-lived mechanism language should be present.
if grep -qiE 'short[- ]?lived|oidc|workload identity|sts|dynamic|keyless' "$DOC"; then
  echo "  OK   mentions a short-lived mechanism"
else
  echo "  FAIL does not mention a short-lived mechanism"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara ADR-rotation.md con solution/REFERENCE.md para autoevaluarte."
exit 0
