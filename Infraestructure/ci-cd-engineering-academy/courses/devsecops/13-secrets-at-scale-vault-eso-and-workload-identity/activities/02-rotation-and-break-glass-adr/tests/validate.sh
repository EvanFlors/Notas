#!/usr/bin/env bash
# Structural validation for sec-13-02-rotation-and-break-glass-adr.
# Checks that ADR.md exists and contains the required ADR sections,
# the rotation table with at least 5 rows, the 5 numbered break-glass
# steps, and the key vocabulary.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.
set -eu

BASE="${1:-/tmp/sec-13-rotation-adr}"
DOC="$BASE/ADR.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it (copy TEMPLATE.md)."
  exit 1
fi

# ----- Required ADR sections -----
for h in "Status" "Context" "Decision" "Consequences"; do
  if grep -qiE "^#+ *$h" "$DOC"; then
    echo "  OK   ADR.md has section '$h'"
  else
    echo "  FAIL ADR.md missing section '$h'"
    fail=$((fail+1))
  fi
done

# ----- Decision subsections A and B -----
if grep -qiE '^#+ *(A\.|Tabla|Rotaci[óo]n)' "$DOC"; then
  echo "  OK   Decision has subsection A (Tabla de rotación)"
else
  echo "  FAIL Decision missing subsection A (Tabla de rotación)"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *(B\.|Break-glass|Procedimiento)' "$DOC"; then
  echo "  OK   Decision has subsection B (Procedimiento break-glass)"
else
  echo "  FAIL Decision missing subsection B (Procedimiento break-glass)"
  fail=$((fail+1))
fi

# ----- Table: at least 5 rows (header + separator + 5 data rows = 7 lines) -----
rows=$(grep -cE '^\|' "$DOC")
if [ "$rows" -ge 7 ]; then
  echo "  OK   ADR.md has at least 5 table rows ($rows pipe-lines found)"
else
  echo "  FAIL ADR.md table has only $rows pipe-lines (expected >=7)"
  fail=$((fail+1))
fi

# ----- At least 3 distinct families must appear -----
families=0
for fam in "dynamic" "estatico-rotado-automatizado" "estatico-rotado-humano"; do
  if grep -qi "$fam" "$DOC"; then
    families=$((families+1))
  fi
done
if [ "$families" -ge 3 ]; then
  echo "  OK   ADR.md mentions $families distinct secret families (>=3)"
else
  echo "  FAIL ADR.md mentions only $families secret families (expected >=3)"
  fail=$((fail+1))
fi

# ----- Numbered break-glass steps: at least 5 -----
steps=0
for n in 1 2 3 4 5; do
  if grep -Eq "^[[:space:]]*${n}\\." "$DOC"; then
    steps=$((steps+1))
  fi
done
if [ "$steps" -ge 5 ]; then
  echo "  OK   ADR.md has at least 5 numbered break-glass steps"
else
  echo "  FAIL ADR.md has $steps numbered steps (expected >=5)"
  fail=$((fail+1))
fi

# ----- Break-glass must mention the 5 properties (vocabulary check) -----
props_hit=0
# Property 1: strong auth
if grep -qiE '2fa|mfa|yubikey|hardware[- ]?key|fido|sso' "$DOC"; then
  props_hit=$((props_hit+1))
  echo "  OK   mentions strong authentication (2FA/MFA/YubiKey/FIDO/SSO)"
else
  echo "  FAIL does not mention strong authentication"
  fail=$((fail+1))
fi
# Property 2: audit trail
if grep -qiE 'audit[- ]?log|audit[- ]?device|append[- ]?only|object[- ]?lock|rastro' "$DOC"; then
  props_hit=$((props_hit+1))
  echo "  OK   mentions audit trail"
else
  echo "  FAIL does not mention audit trail"
  fail=$((fail+1))
fi
# Property 3: minimal scope
if grep -qiE 'policy|scope|m[íi]nimo|least privilege|privilegio' "$DOC"; then
  props_hit=$((props_hit+1))
  echo "  OK   mentions minimal scope / policy"
else
  echo "  FAIL does not mention minimal scope"
  fail=$((fail+1))
fi
# Property 4: TTL
if grep -qiE 'ttl|min[uúo]tos?|expir|revoca' "$DOC"; then
  props_hit=$((props_hit+1))
  echo "  OK   mentions explicit TTL / expiration"
else
  echo "  FAIL does not mention TTL / expiration"
  fail=$((fail+1))
fi
# Property 5: post-mortem review
if grep -qiE 'post[- ]?mortem|review|revisi[óo]n|24 ?h|incident' "$DOC"; then
  props_hit=$((props_hit+1))
  echo "  OK   mentions post-mortem / review"
else
  echo "  FAIL does not mention post-mortem review"
  fail=$((fail+1))
fi

# ----- Must mention Vault -----
if grep -qi 'vault' "$DOC"; then
  echo "  OK   mentions Vault"
else
  echo "  FAIL does not mention Vault"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara ADR.md con solution/REFERENCE.md para autoevaluarte."
exit 0
